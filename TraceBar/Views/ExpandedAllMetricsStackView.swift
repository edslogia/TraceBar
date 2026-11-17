//
//  ExpandedAllMetricsStackView.swift
//  TraceBar
//

import SwiftUI

struct ExpandedAllMetricsStackView: View {
    let monitor: SystemMonitor
    @ObservedObject var styleStore: GraphStyleStore

    private let rowSpacing: CGFloat = 10

    var body: some View {
        GeometryReader { geometry in
            let rowHeight = (geometry.size.height - rowSpacing * 3) / 4

            VStack(spacing: rowSpacing) {
                ForEach(GraphMetric.allCases, id: \.self) { metric in
                    ExpandedMetricPanelCell(
                        metric: metric,
                        monitor: monitor,
                        styleStore: styleStore
                    )
                    .frame(height: rowHeight)
                }
            }
        }
    }
}
