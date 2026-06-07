//
//  MenuBarMonitorView.swift
//  graphic-monitor
//

import SwiftUI

struct MenuBarMonitorView: View {
    let monitor: SystemMonitor

    var body: some View {
        HStack(spacing: 3) {
            MiniGraphView(
                data: monitor.cpuHistory,
                color: .cpu,
                tooltip: "CPU: \(SystemMonitor.formatPercent(monitor.cpuUsage))"
            )
            MiniGraphView(
                data: monitor.gpuHistory,
                color: .gpu,
                tooltip: "GPU: \(SystemMonitor.formatPercent(monitor.gpuUsage))"
            )
            MiniGraphView(
                data: monitor.ramHistory,
                color: .ram,
                tooltip: "RAM: \(SystemMonitor.formatPercent(monitor.ramUsage))"
            )
            MiniGraphView(
                data: monitor.netHistory,
                color: .network,
                tooltip: "Red: \(SystemMonitor.formatPercent(monitor.netUsage)) · \(SystemMonitor.formatNetworkSpeed(monitor.netBytesPerSecond))"
            )
        }
        .frame(width: 164, height: 18)
        .fixedSize()
    }
}

private extension Color {
    static let cpu = Color(red: 0.45, green: 0.82, blue: 0.09)
    static let gpu = Color(red: 0.99, green: 0.69, blue: 0.24)
    static let ram = Color(red: 0.45, green: 0.62, blue: 0.81)
    static let network = Color(red: 0.68, green: 0.50, blue: 0.66)
}

#Preview {
    MenuBarMonitorView(monitor: SystemMonitor())
        .padding()
}
