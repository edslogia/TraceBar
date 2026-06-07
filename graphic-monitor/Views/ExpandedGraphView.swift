//
//  ExpandedGraphView.swift
//  graphic-monitor
//

import SwiftUI

struct ExpandedGraphView: View {
    let metric: GraphMetric
    let monitor: SystemMonitor

    @State private var isPinned: Bool

    init(metric: GraphMetric, monitor: SystemMonitor) {
        self.metric = metric
        self.monitor = monitor
        _isPinned = State(initialValue: ExpandedGraphPanelManager.shared.isPinned)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(metric.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                Button {
                    isPinned.toggle()
                    ExpandedGraphPanelManager.shared.setPinned(isPinned)
                } label: {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isPinned ? metric.color : Color.secondary)
                        .frame(width: 20, height: 16)
                }
                .buttonStyle(.plain)
                .help(isPinned ? "Desfijar panel" : "Fijar panel")

                Spacer(minLength: 8)

                AnimatedMetricValueView(metric: metric, monitor: monitor)
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .foregroundStyle(metric.color)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(white: 0.10))

                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(metric.color.opacity(0.45), lineWidth: 1)

                SparklineShape(values: metric.history(from: monitor))
                    .stroke(
                        metric.color,
                        style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                    )
                    .padding(10)

                if let secondaryHistory = metric.secondaryHistory(from: monitor),
                   let secondaryColor = metric.secondaryColor() {
                    SparklineShape(values: secondaryHistory)
                        .stroke(
                            secondaryColor,
                            style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                        )
                        .padding(10)
                }
            }
            .frame(height: 96)

            HStack(alignment: .firstTextBaseline) {
                if let subtitle = metric.subtitle(from: monitor) {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Text("Press ⌘Q to quit")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .frame(width: 300)
    }
}

#Preview {
    ExpandedGraphView(metric: .cpu, monitor: SystemMonitor())
        .padding()
}
