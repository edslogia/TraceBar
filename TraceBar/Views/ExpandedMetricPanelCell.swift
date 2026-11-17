//
//  ExpandedMetricPanelCell.swift
//  TraceBar
//

import SwiftUI

struct ExpandedMetricPanelCell: View {
    let metric: GraphMetric
    let monitor: SystemMonitor
    @ObservedObject var styleStore: GraphStyleStore

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.thinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(metric.color.opacity(0.45), lineWidth: 1)
                }

            StyledMetricGraph(
                values: metric.history(from: monitor),
                color: metric.color,
                style: styleStore.style(for: metric),
                secondaryValues: metric.secondaryHistory(from: monitor),
                secondaryColor: metric.secondaryColor(),
                lineWidth: 2.2,
                padding: 10
            )

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(metric.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(metric.color)

                Spacer(minLength: 0)

                Text(compactValue)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(metric.color.opacity(0.85))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var compactValue: String {
        switch metric {
        case .cpu:
            SystemMonitor.formatPercent(monitor.cpuUsage)
        case .gpu:
            SystemMonitor.formatPercent(monitor.gpuUsage)
        case .ram:
            SystemMonitor.formatPercent(monitor.ramUsage)
        case .network:
            SystemMonitor.formatNetworkSpeedMbps(monitor.netDownloadBytesPerSecond)
        }
    }
}
