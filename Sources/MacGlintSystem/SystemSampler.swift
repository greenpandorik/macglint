import Foundation
import Darwin
import CMacGlint
import MacGlintCore

public struct SystemReading: Sendable {
    public var snapshot: MetricSnapshot
    public var processes: [ProcessSample]
}
/// Use on one serial queue; all rate baselines belong to that sampler.
public final class SystemSampler {
    private var previousSystem: MGSystem?
    private var previousProcesses: [ProcessIdentity: UInt64] = [:]
    private var previousTime: Double?
    private var previousNetwork: [String: NetworkCounter] = [:]
    public init() {}
    public func reset() { previousSystem = nil; previousProcesses = [:]; previousTime = nil; previousNetwork = [:] }
    public func sample() -> SystemReading {
        let uptime = ProcessInfo.processInfo.systemUptime
        let elapsed = previousTime.map { uptime - $0 } ?? 0
        var raw = MGSystem(); mg_system(&raw)
        var snapshot = MetricSnapshot(memoryUsed: raw.memory_valid != 0 ? raw.memory_used : nil,
            memoryTotal: raw.memory_total, pressure: raw.pressure >= 0 ? Int(raw.pressure) : nil,
            battery: raw.battery >= 0 ? raw.battery : nil, charging: raw.charging != 0,
            diskFree: raw.disk_valid != 0 ? raw.disk_free : nil)
        if let old = previousSystem, elapsed > 0, elapsed <= 30 {
            if old.cpu_valid != 0 && raw.cpu_valid != 0 && raw.ticks_total > old.ticks_total && raw.ticks_busy >= old.ticks_busy {
                snapshot.cpu = min(100, Double(raw.ticks_busy - old.ticks_busy) / Double(raw.ticks_total - old.ticks_total) * 100)
            }
        }
        let networkBuffer = UnsafeMutablePointer<MGNetwork>.allocate(capacity: 128)
        defer { networkBuffer.deallocate() }
        let networkCount = Int(mg_network(networkBuffer, 128))
        var network: [String: NetworkCounter] = [:]
        if networkCount >= 0 {
            for i in 0..<networkCount {
                var item = networkBuffer[i]
                let name = withUnsafePointer(to: &item.name) { $0.withMemoryRebound(to: CChar.self, capacity: 32) { String(cString: $0) } }
                network["\(item.index):\(name)"] = NetworkCounter(received: item.received, sent: item.sent)
            }
            let rates = NetworkRates.measure(previous: previousNetwork, current: network, elapsed: elapsed)
            snapshot.download = rates.download; snapshot.upload = rates.upload
        }
        previousNetwork = network
        let capacity = 8192
        let buffer = UnsafeMutablePointer<MGProcess>.allocate(capacity: capacity)
        defer { buffer.deallocate() }
        let count = Int(mg_processes(buffer, Int32(capacity)))
        var current: [ProcessIdentity: UInt64] = [:]
        var processes: [ProcessSample] = []; processes.reserveCapacity(count)
        for i in 0..<count {
            var p = buffer[i]
            let identity = ProcessIdentity(pid: p.pid, startMicroseconds: p.start_us, uid: p.uid)
            let name = withUnsafePointer(to: &p.name) { $0.withMemoryRebound(to: CChar.self, capacity: 256) { String(cString: $0) } }
            let path = withUnsafePointer(to: &p.path) { $0.withMemoryRebound(to: CChar.self, capacity: 4096) { String(cString: $0) } }
            var cpu: Double?
            if p.usage_valid != 0 {
                current[identity] = p.cpu_ns
                if let old = previousProcesses[identity], p.cpu_ns >= old {
                    cpu = MetricMath.cpu(deltaNanoseconds: p.cpu_ns - old, elapsed: elapsed, cores: ProcessInfo.processInfo.activeProcessorCount)
                }
            }
            // Only executable containment is evidence of app membership. Generic WebKit XPCs remain separate.
            let appPath = path.range(of: ".app/").map { String(path[..<$0.lowerBound]) + ".app" }
            let appName = appPath.map { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent } ?? name
            let key = appPath ?? "process:\(path.isEmpty ? name : path)"
            processes.append(ProcessSample(identity: identity, name: name, path: path, appKey: key,
                appName: appName, cpu: cpu, memoryBytes: p.usage_valid != 0 ? p.memory : nil))
        }
        previousSystem = raw; previousProcesses = current; previousTime = uptime
        return SystemReading(snapshot: snapshot, processes: processes)
    }
}
public enum ProcessControlError: LocalizedError {
    case unavailable, refused(Int32)
    public var errorDescription: String? {
        switch self {
        case .unavailable: return "Процесс уже завершился или недоступен."
        case .refused(let code):
            if code == ESTALE { return "Процесс изменился. Обновите список и выберите его снова." }
            if code == EPERM { return "Недостаточно прав или процесс защищён."
            }
            return "Не удалось завершить процесс: \(String(cString: strerror(code)))"
        }
    }
}
public enum ProcessController {
    public static func identity(for pid: Int32) -> ProcessIdentity? {
        var p = MGProcess()
        guard mg_process(pid, &p) != 0 else { return nil }
        return .init(pid: p.pid, startMicroseconds: p.start_us, uid: p.uid)
    }
    public static func terminate(identity: ProcessIdentity, force: Bool) throws {
        let result = mg_terminate(identity.pid, identity.startMicroseconds, identity.uid, force ? 1 : 0)
        if result != 0 { throw ProcessControlError.refused(result) }
    }
}

/// Serializes sampling off the UI actor while keeping counter baselines private.
public actor SamplingService {
    private let sampler = SystemSampler()
    public init() {}
    public func reset() { sampler.reset() }
    public func sample() -> SystemReading { sampler.sample() }
}
