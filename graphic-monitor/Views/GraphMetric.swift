//
//  GraphMetric.swift
//  graphic-monitor
//

import SwiftUI

enum GraphMetric: Hashable {
    case cpu
    case gpu
    case ram
    case network

    var title: String {
        switch self {
        case .cpu: "CPU"
        case .gpu: "GPU"
        case .ram: "RAM"
        case .network: "Red"
        }
    }

    var color: Color {
        switch self {
        case .cpu: Color(red: 0.45, green: 0.82, blue: 0.09)
        case .gpu: Color(red: 0.99, green: 0.69, blue: 0.24)
        case .ram: Color(red: 0.45, green: 0.62, blue: 0.81)
        case .network: Color(red: 0.68, green: 0.50, blue: 0.66)
        }
    }

    func history(from monitor: SystemMonitor) -> [Double] {
        switch self {
        case .cpu: monitor.cpuHistory
        case .gpu: monitor.gpuHistory
        case .ram: monitor.ramHistory
        case .network: monitor.netHistory
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
            "Red: \(SystemMonitor.formatPercent(monitor.netUsage)) · \(SystemMonitor.formatNetworkSpeed(monitor.netBytesPerSecond))"
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
            "\(SystemMonitor.formatPercent(monitor.netUsage)) · \(SystemMonitor.formatNetworkSpeed(monitor.netBytesPerSecond))"
        }
    }

    func subtitle(from monitor: SystemMonitor) -> String? {
        "Últimos \(SystemMonitor.historyLength)s"
    }
}
