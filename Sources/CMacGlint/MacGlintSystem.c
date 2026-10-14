#include "MacGlintSystem.h"
#include <mach/mach.h>
#include <mach/mach_time.h>
#include <mach/host_info.h>
#include <sys/sysctl.h>
#include <sys/mount.h>
#include <sys/resource.h>
#include <sys/proc_info.h>
#include <libproc.h>
#include <net/route.h>
#include <net/if.h>
#include <net/if_dl.h>
#include <IOKit/ps/IOPowerSources.h>
#include <IOKit/ps/IOPSKeys.h>
#include <CoreFoundation/CoreFoundation.h>
#include <signal.h>
#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int mg_system(MGSystem *out) {
    memset(out, 0, sizeof(*out)); out->pressure = -1; out->battery = -1;
    mach_port_t host = mach_host_self();
    host_cpu_load_info_data_t cpu;
    mach_msg_type_number_t count = HOST_CPU_LOAD_INFO_COUNT;
    if (host_statistics(host, HOST_CPU_LOAD_INFO, (host_info_t)&cpu, &count) == KERN_SUCCESS) {
        out->ticks_busy = (uint64_t)cpu.cpu_ticks[CPU_STATE_USER] + cpu.cpu_ticks[CPU_STATE_SYSTEM] + cpu.cpu_ticks[CPU_STATE_NICE];
        out->ticks_total = out->ticks_busy + cpu.cpu_ticks[CPU_STATE_IDLE]; out->cpu_valid = 1;
    }
    size_t len = sizeof(out->memory_total);
    sysctlbyname("hw.memsize", &out->memory_total, &len, NULL, 0);
    vm_statistics64_data_t vm; count = HOST_VM_INFO64_COUNT;
    vm_size_t page = 0; host_page_size(host, &page);
    if (host_statistics64(host, HOST_VM_INFO64, (host_info64_t)&vm, &count) == KERN_SUCCESS) {
        uint64_t internal = vm.internal_page_count > vm.purgeable_count ? vm.internal_page_count - vm.purgeable_count : 0;
        out->memory_used = (internal + vm.wire_count + vm.compressor_page_count) * page;
        if (out->memory_used > out->memory_total) out->memory_used = out->memory_total;
        out->memory_valid = 1;
    }
    mach_port_deallocate(mach_task_self(), host);
    int pressure = 0; len = sizeof(pressure);
    if (sysctlbyname("kern.memorystatus_vm_pressure_level", &pressure, &len, NULL, 0) == 0) {
        out->pressure = pressure == 4 ? 2 : pressure == 2 ? 1 : pressure == 1 ? 0 : -1;
    }
    struct statfs disk;
    if (statfs("/System/Volumes/Data", &disk) == 0) {
        out->disk_free = (uint64_t)disk.f_bavail * disk.f_bsize; out->disk_valid = 1;
    }
    CFTypeRef info = IOPSCopyPowerSourcesInfo();
    if (info) {
        CFArrayRef sources = IOPSCopyPowerSourcesList(info);
        if (sources) {
            for (CFIndex i = 0; i < CFArrayGetCount(sources); i++) {
                CFDictionaryRef d = IOPSGetPowerSourceDescription(info, CFArrayGetValueAtIndex(sources, i));
                if (!d) continue;
                CFStringRef type = CFDictionaryGetValue(d, CFSTR(kIOPSTypeKey));
                if (!type || !CFEqual(type, CFSTR(kIOPSInternalBatteryType))) continue;
                int current = 0, max = 0;
                CFNumberRef c = CFDictionaryGetValue(d, CFSTR(kIOPSCurrentCapacityKey));
                CFNumberRef m = CFDictionaryGetValue(d, CFSTR(kIOPSMaxCapacityKey));
                if (c && m && CFNumberGetValue(c, kCFNumberIntType, &current) && CFNumberGetValue(m, kCFNumberIntType, &max) && max > 0) out->battery = (double)current / max * 100;
                CFStringRef state = CFDictionaryGetValue(d, CFSTR(kIOPSPowerSourceStateKey));
                out->charging = state && CFEqual(state, CFSTR(kIOPSACPowerValue));
                break;
            }
            CFRelease(sources);
        }
        CFRelease(info);
    }
    return 1;
}
int mg_process(int32_t pid, MGProcess *out) {
    memset(out, 0, sizeof(*out));
    struct proc_bsdinfo bsd;
    if (proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsd, sizeof(bsd)) != sizeof(bsd)) return 0;
    out->pid = pid; out->uid = bsd.pbi_uid;
    out->start_us = bsd.pbi_start_tvsec * 1000000 + bsd.pbi_start_tvusec;
    strlcpy(out->name, bsd.pbi_name[0] ? bsd.pbi_name : bsd.pbi_comm, sizeof(out->name));
    proc_pidpath(pid, out->path, sizeof(out->path));
    struct rusage_info_v2 usage;
    if (proc_pid_rusage(pid, RUSAGE_INFO_V2, (rusage_info_t *)&usage) == 0) {
        // proc_pid_rusage reports Mach absolute time units, not nanoseconds on Apple Silicon.
        mach_timebase_info_data_t timebase;
        mach_timebase_info(&timebase);
        __uint128_t ticks = (__uint128_t)usage.ri_user_time + usage.ri_system_time;
        out->cpu_ns = (uint64_t)(ticks * timebase.numer / timebase.denom);
        out->memory = usage.ri_phys_footprint; out->usage_valid = 1;
    }
    return 1;
}
int mg_processes(MGProcess *out, int capacity) {
    int total = proc_listallpids(NULL, 0);
    if (total <= 0) return 0;
    int allocated = total + 256;
    pid_t *pids = calloc((size_t)allocated, sizeof(pid_t));
    if (!pids) return 0;
    total = proc_listallpids(pids, allocated * (int)sizeof(pid_t));
    int count = 0;
    for (int i = 0; i < total && i < allocated && count < capacity; i++) {
        if (pids[i] > 0 && mg_process(pids[i], &out[count])) count++;
    }
    free(pids); return count;
}
int mg_terminate(int32_t pid, uint64_t start_us, uint32_t uid, int force) {
    if (pid <= 1 || pid == getpid() || uid != geteuid()) return EPERM;
    MGProcess now;
    if (!mg_process(pid, &now)) return ESRCH;
    if (now.start_us != start_us || now.uid != uid) return ESTALE;
    if (kill(pid, force ? SIGKILL : SIGTERM) != 0) return errno;
    return 0;
}

int mg_network(MGNetwork *out, int capacity) {
    int mib[] = { CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0 };
    size_t length = 0;
    if (sysctl(mib, 6, NULL, &length, NULL, 0) != 0) return -1;
    char *data = malloc(length);
    if (!data) return -1;
    if (sysctl(mib, 6, data, &length, NULL, 0) != 0) { free(data); return -1; }
    int count = 0;
    // All routing records share only this prefix; address records can be shorter than if_msghdr.
    struct message_prefix { uint16_t length; uint8_t version; uint8_t type; };
    for (char *cursor = data; (size_t)(data + length - cursor) >= sizeof(struct message_prefix);) {
        struct message_prefix header;
        memcpy(&header, cursor, sizeof(header));
        if (header.length < sizeof(header) || header.length > (size_t)(data + length - cursor)) { free(data); return -1; }
        if (header.type == RTM_IFINFO2 && header.length >= sizeof(struct if_msghdr2)) {
            struct if_msghdr2 *info = (struct if_msghdr2 *)cursor;
            char name[IF_NAMESIZE] = {0};
            if (if_indextoname(info->ifm_index, name) && strncmp(name, "en", 2) == 0) {
                if (count == capacity) { free(data); return -1; }
                MGNetwork *item = &out[count++];
                item->index = info->ifm_index; strlcpy(item->name, name, sizeof(item->name));
                item->received = info->ifm_data.ifi_ibytes; item->sent = info->ifm_data.ifi_obytes;
            }
        }
        cursor += header.length;
    }
    free(data); return count;
}
