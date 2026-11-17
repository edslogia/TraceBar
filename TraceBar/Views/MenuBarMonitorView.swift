//
//  MenuBarMonitorView.swift
//  TraceBar
//

import SwiftUI

struct MenuBarMonitorView: View {
    let monitor: SystemMonitor
    @ObservedObject private var styleStore = GraphStyleStore.shared

    var body: some View {
        HStack(spacing: 3) {
            graph(.cpu)
            graph(.gpu)
            graph(.ram)
            graph(.network)
        }
        .frame(width: 164, height: 18)
        .fixedSize()
    }

    private func graph(_ metric: GraphMetric) -> some View {
        MiniGraphView(
            data: metric.history(from: monitor),
            color: metric.color,
            tooltip: metric.tooltip(from: monitor),
            style: styleStore.style(for: metric),
            secondaryData: metric.secondaryHistory(from: monitor),
            secondaryColor: metric.secondaryColor()
            // Taps are handled by StatusBarController (macOS 27 status-item scenes
            // often don't deliver mouseUp to SwiftUI overlay views).
        )
    }
}

#Preview {
    MenuBarMonitorView(monitor: SystemMonitor())
        .padding()
}
