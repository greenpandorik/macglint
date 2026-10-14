#ifndef MACGLINT_SYSTEM_H
#define MACGLINT_SYSTEM_H
#include <stdint.h>
#include <stddef.h>
typedef struct {
    uint64_t ticks_busy, ticks_total, memory_used, memory_total, disk_free;
    int cpu_valid, memory_valid, disk_valid, pressure, charging;
    double battery;
} MGSystem;
typedef struct {
    int32_t pid;
    uint32_t uid;
    uint64_t start_us, cpu_ns, memory;
    int usage_valid;
    char name[256];
    char path[4096];
} MGProcess;
typedef struct { uint32_t index; char name[32]; uint64_t received, sent; } MGNetwork;
int mg_network(MGNetwork *out, int capacity);
int mg_system(MGSystem *out);
int mg_process(int32_t pid, MGProcess *out);
int mg_processes(MGProcess *out, int capacity);
int mg_terminate(int32_t pid, uint64_t start_us, uint32_t uid, int force);
#endif
