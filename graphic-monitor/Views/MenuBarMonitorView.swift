//
//  MenuBarMonitorView.swift
//  graphic-monitor
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
            secondaryColor: metric.secondaryColor(),
            onTap: { anchor in
                ExpandedGraphPanelManager.shared.toggle(
                    metric: metric,
                    monitor: monitor,
                    anchor: anchor
                )
            }
        )
    }
}

#Preview {
    MenuBarMonitorView(monitor: SystemMonitor())
        .padding()
}
