//
//  SystemMonitor.swift
//  TraceBar
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
    private(set) var netDownloadHistory: [Double] = Array(repeating: 0, count: historyLength)
    private(set) var netUploadHistory: [Double] = Array(repeating: 0, count: historyLength)

    private(set) var cpuUsage: Double = 0
    private(set) var gpuUsage: Double = 0
    private(set) var ramUsage: Double = 0
    private(set) var netDownloadBytesPerSecond: Double = 0
    private(set) var netUploadBytesPerSecond: Double = 0
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
        netDownloadBytesPerSecond = network.downloadBytesPerSecond
        netUploadBytesPerSecond = network.uploadBytesPerSecond
        netBytesPerSecond = network.downloadBytesPerSecond + network.uploadBytesPerSecond
        append(&netDownloadHistory, network.downloadNormalized)
        append(&netUploadHistory, network.uploadNormalized)
    }

    static func formatPercent(_ value: Double) -> String {
        "\(Int((min(max(value, 0), 1) * 100).rounded()))%"
    }

    static func formatNetworkSpeedMbps(_ bytesPerSecond: Double) -> String {
        "\(networkSpeedMbpsValue(bytesPerSecond)) Mbps"
    }

    static func networkSpeedMbpsValue(_ bytesPerSecond: Double) -> String {
        formattedMetricValue(bytesPerSecond * 8 / 1_000_000)
    }

    static func formatNetworkSpeed(_ bytesPerSecond: Double) -> String {
        let components = networkSpeedComponents(bytesPerSecond)
        return "\(components.value) \(components.unit)"
    }

    static func networkSpeedComponents(_ bytesPerSecond: Double) -> (value: String, unit: String) {
        if bytesPerSecond >= 1_048_576 {
            return (formattedMetricValue(bytesPerSecond / 1_048_576), "MB/s")
        }
        if bytesPerSecond >= 1024 {
            return (formattedMetricValue(bytesPerSecond / 1024), "KB/s")
        }
        return (formattedMetricValue(bytesPerSecond), "B/s")
    }

    private static func formattedMetricValue(_ value: Double) -> String {
        if value >= 100 {
            return String(format: "%.0f", value)
        }
        if value >= 10 {
            return String(format: "%.1f", value)
        }
        if value >= 1 {
            return String(format: "%.1f", value)
        }
        return String(format: "%.2f", value)
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
        let downloadNormalized: Double
        let uploadNormalized: Double
        let downloadBytesPerSecond: Double
        let uploadBytesPerSecond: Double
    }

    private func readNetworkSample() -> NetworkSample {
        let bytes = networkBytes()
        defer { previousNetworkBytes = bytes }

        guard let previous = previousNetworkBytes else {
            return NetworkSample(
                downloadNormalized: 0,
                uploadNormalized: 0,
                downloadBytesPerSecond: 0,
                uploadBytesPerSecond: 0
            )
        }

        let receivedDelta = bytes.received >= previous.received
            ? bytes.received - previous.received
            : 0
        let sentDelta = bytes.sent >= previous.sent
            ? bytes.sent - previous.sent
            : 0
        let download = Double(receivedDelta)
        let upload = Double(sentDelta)
        let throughput = download + upload

        networkPeak = max(networkPeak * 0.95, throughput, 65_536)
        return NetworkSample(
            downloadNormalized: min(download / networkPeak, 1),
            uploadNormalized: min(upload / networkPeak, 1),
            downloadBytesPerSecond: download,
            uploadBytesPerSecond: upload
        )
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
