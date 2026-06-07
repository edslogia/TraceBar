//
//  SystemMonitor.swift
//  graphic-monitor
//

import Foundation
import IOKit

@MainActor
@Observable
final class SystemMonitor {
    static let historyLength = 30

    private(set) var cpuHistory: [Double] = Array(repeating: 0, count: historyLength)
    private(set) var gpuHistory: [Double] = Array(repeating: 0, count: historyLength)
    private(set) var ramHistory: [Double] = Array(repeating: 0, count: historyLength)
    private(set) var netHistory: [Double] = Array(repeating: 0, count: historyLength)

    private(set) var cpuUsage: Double = 0
    private(set) var gpuUsage: Double = 0
    private(set) var ramUsage: Double = 0
    private(set) var netUsage: Double = 0
    private(set) var netBytesPerSecond: Double = 0

    private var timer: Timer?
    private var previousCPUTicks: (user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)?
    private var previousNetworkBytes: (received: UInt64, sent: UInt64)?
    private var networkPeak: Double = 1_048_576

    func start() {
        guard timer == nil else { return }
        sample()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sample()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func sample() {
        let cpu = readCPUUsage()
        cpuUsage = cpu
        append(&cpuHistory, cpu)

        let gpu = readGPUUsage()
        gpuUsage = gpu
        append(&gpuHistory, gpu)

        let ram = readRAMUsage()
        ramUsage = ram
        append(&ramHistory, ram)

        let network = readNetworkSample()
        netUsage = network.normalized
        netBytesPerSecond = network.bytesPerSecond
        append(&netHistory, network.normalized)
    }

    static func formatPercent(_ value: Double) -> String {
        "\(Int((min(max(value, 0), 1) * 100).rounded()))%"
    }

    static func formatNetworkSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond >= 1_048_576 {
            return String(format: "%.1f MB/s", bytesPerSecond / 1_048_576)
        }
        if bytesPerSecond >= 1024 {
            return String(format: "%.0f KB/s", bytesPerSecond / 1024)
        }
        return String(format: "%.0f B/s", bytesPerSecond)
    }

    private func append(_ history: inout [Double], _ value: Double) {
        history.removeFirst()
        history.append(min(max(value, 0), 1))
    }

    // MARK: - CPU

    private func readCPUUsage() -> Double {
        var load = host_cpu_load_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &load) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }

        let ticks = (
            user: load.cpu_ticks.0,
            system: load.cpu_ticks.1,
            idle: load.cpu_ticks.2,
            nice: load.cpu_ticks.3
        )

        defer { previousCPUTicks = ticks }

        guard let previous = previousCPUTicks else { return 0 }

        let userDelta = Double(ticks.user &- previous.user)
        let systemDelta = Double(ticks.system &- previous.system)
        let idleDelta = Double(ticks.idle &- previous.idle)
        let niceDelta = Double(ticks.nice &- previous.nice)
        let total = userDelta + systemDelta + idleDelta + niceDelta

        guard total > 0 else { return 0 }
        return (userDelta + systemDelta + niceDelta) / total
    }

    // MARK: - GPU

    private func readGPUUsage() -> Double {
        let serviceNames = ["IOAccelerator", "AGXAccelerator", "AppleM2ScalerCSC"]

        for name in serviceNames {
            if let usage = gpuUtilization(matching: name) {
                return usage
            }
        }
        return 0
    }

    private func gpuUtilization(matching name: String) -> Double? {
        let matching = IOServiceMatching(name)
        var iterator: io_iterator_t = 0

        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service) }

            if let stats = IORegistryEntryCreateCFProperty(
                service,
                "PerformanceStatistics" as CFString,
                kCFAllocatorDefault,
                0
            )?.takeRetainedValue() as? [String: Any] {
                for key in ["Device Utilization %", "GPU Activity(%)", "Renderer Utilization %"] {
                    if let value = stats[key] as? Int {
                        return Double(value) / 100.0
                    }
                    if let value = stats[key] as? Double {
                        return value / 100.0
                    }
                }
            }

            service = IOIteratorNext(iterator)
        }

        return nil
    }

    // MARK: - RAM

    private func readRAMUsage() -> Double {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }

        let pageSize = UInt64(vm_kernel_page_size)
        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let used = active + wired + compressed
        let total = ProcessInfo.processInfo.physicalMemory

        guard total > 0 else { return 0 }
        return Double(used) / Double(total)
    }

    // MARK: - Network

    private struct NetworkSample {
        let normalized: Double
        let bytesPerSecond: Double
    }

    private func readNetworkSample() -> NetworkSample {
        let bytes = networkBytes()
        defer { previousNetworkBytes = bytes }

        guard let previous = previousNetworkBytes else {
            return NetworkSample(normalized: 0, bytesPerSecond: 0)
        }

        let receivedDelta = bytes.received >= previous.received
            ? bytes.received - previous.received
            : 0
        let sentDelta = bytes.sent >= previous.sent
            ? bytes.sent - previous.sent
            : 0
        let throughput = Double(receivedDelta + sentDelta)

        networkPeak = max(networkPeak * 0.95, throughput, 65_536)
        let normalized = min(throughput / networkPeak, 1)
        return NetworkSample(normalized: normalized, bytesPerSecond: throughput)
    }

    private func networkBytes() -> (received: UInt64, sent: UInt64) {
        var addresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addresses) == 0, let first = addresses else {
            return (0, 0)
        }
        defer { freeifaddrs(addresses) }

        var received: UInt64 = 0
        var sent: UInt64 = 0
        var pointer: UnsafeMutablePointer<ifaddrs>? = first

        while let current = pointer {
            let interface = current.pointee

            if interface.ifa_addr?.pointee.sa_family == UInt8(AF_LINK) {
                let name = String(cString: interface.ifa_name)
                if isNetworkInterface(name),
                   let data = interface.ifa_data?.assumingMemoryBound(to: if_data.self) {
                    received += UInt64(data.pointee.ifi_ibytes)
                    sent += UInt64(data.pointee.ifi_obytes)
                }
            }

            pointer = interface.ifa_next
        }

        return (received, sent)
    }

    private func isNetworkInterface(_ name: String) -> Bool {
        let ignoredPrefixes = ["lo", "utun", "awdl", "llw", "bridge", "gif", "stf"]
        return !ignoredPrefixes.contains { name.hasPrefix($0) }
    }
}
