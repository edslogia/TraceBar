//
//  GraphMetric.swift
//  TraceBar
//

import SwiftUI

enum GraphMetric: Hashable, CaseIterable {
    case cpu
    case gpu
    case ram
    case network

    var storageKey: String {
        switch self {
        case .cpu: "cpu"
        case .gpu: "gpu"
        case .ram: "ram"
        case .network: "network"
        }
    }

    init?(storageKey: String) {
        switch storageKey {
        case "cpu": self = .cpu
        case "gpu": self = .gpu
        case "ram": self = .ram
        case "network": self = .network
        default: return nil
        }
    }

    var title: String {
        switch self {
        case .cpu: "CPU"
        case .gpu: "GPU"
        case .ram: "RAM"
        case .network: "Network"
        }
    }

    var color: Color {
        switch self {
        case .cpu: Color(red: 0.45, green: 0.82, blue: 0.09)
        case .gpu: Color(red: 0.99, green: 0.69, blue: 0.24)
        case .ram: Color(red: 0.45, green: 0.62, blue: 0.81)
        case .network: Self.downloadColor
        }
    }

    static let downloadColor = Color(red: 0.35, green: 0.78, blue: 0.98)
    static let uploadColor = Color(red: 0.98, green: 0.55, blue: 0.35)

    func history(from monitor: SystemMonitor) -> [Double] {
        switch self {
        case .cpu: monitor.cpuHistory
        case .gpu: monitor.gpuHistory
        case .ram: monitor.ramHistory
        case .network: monitor.netDownloadHistory
        }
    }

    func secondaryHistory(from monitor: SystemMonitor) -> [Double]? {
        switch self {
        case .network: monitor.netUploadHistory
        default: nil
        }
    }

    func secondaryColor() -> Color? {
        switch self {
        case .network: Self.uploadColor
        default: nil
        }
    }

    func tooltip(from monitor: SystemMonitor) -> String {
        switch self {
        case .cpu:
            "CPU: \(SystemMonitor.formatPercent(monitor.cpuUsage))"
        case .gpu:
            "GPU: \(SystemMonitor.formatPercent(monitor.gpuUsage))"
        case .ram:
            "RAM: \(SystemMonitor.formatPercent(monitor.ramUsage))"
        case .network:
            "↓ \(SystemMonitor.formatNetworkSpeedMbps(monitor.netDownloadBytesPerSecond)) \(SystemMonitor.formatNetworkSpeed(monitor.netDownloadBytesPerSecond)) · ↑ \(SystemMonitor.formatNetworkSpeedMbps(monitor.netUploadBytesPerSecond)) \(SystemMonitor.formatNetworkSpeed(monitor.netUploadBytesPerSecond))"
        }
    }

    func valueText(from monitor: SystemMonitor) -> String {
        switch self {
        case .cpu:
            SystemMonitor.formatPercent(monitor.cpuUsage)
        case .gpu:
            SystemMonitor.formatPercent(monitor.gpuUsage)
        case .ram:
            SystemMonitor.formatPercent(monitor.ramUsage)
        case .network:
            "↓ \(SystemMonitor.formatNetworkSpeedMbps(monitor.netDownloadBytesPerSecond)) \(SystemMonitor.formatNetworkSpeed(monitor.netDownloadBytesPerSecond)) · ↑ \(SystemMonitor.formatNetworkSpeedMbps(monitor.netUploadBytesPerSecond)) \(SystemMonitor.formatNetworkSpeed(monitor.netUploadBytesPerSecond))"
        }
    }

    func subtitle(from monitor: SystemMonitor) -> String? {
        "Last \(SystemMonitor.historyLength)s"
    }

    func adjacentMetric(offset: Int) -> GraphMetric {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self) else { return self }
        let nextIndex = (index + offset + all.count) % all.count
        return all[nextIndex]
    }
}
