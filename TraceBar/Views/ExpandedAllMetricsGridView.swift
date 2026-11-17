//
//  ExpandedAllMetricsGridView.swift
//  TraceBar
//

import SwiftUI

struct ExpandedAllMetricsGridView: View {
    let monitor: SystemMonitor
    @ObservedObject var styleStore: GraphStyleStore

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        GeometryReader { geometry in
            let rowHeight = (geometry.size.height - 10) / 2

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(GraphMetric.allCases, id: \.self) { metric in
                    metricCell(metric)
                        .frame(height: rowHeight)
                }
            }
        }
    }

    private func metricCell(_ metric: GraphMetric) -> some View {
        ExpandedMetricPanelCell(metric: metric, monitor: monitor, styleStore: styleStore)
    }
}
