//
//  ExpandedGraphView.swift
//  graphic-monitor
//

import SwiftUI

struct ExpandedGraphView: View {
    let metric: GraphMetric
    let monitor: SystemMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(metric.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                Text(metric.valueText(from: monitor))
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
            }
            .frame(height: 96)

            if let subtitle = metric.subtitle(from: monitor) {
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
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
