//
//  StyledMetricGraph.swift
//  TraceBar
//

import SwiftUI

struct StyledMetricGraph: View {
    let values: [Double]
    let color: Color
    let style: GraphStyle
    var secondaryValues: [Double]? = nil
    var secondaryColor: Color? = nil
    var lineWidth: CGFloat = 1.2
    var padding: CGFloat = 2

    var body: some View {
        ZStack {
            seriesView(values: values, color: color)

            if let secondaryValues, let secondaryColor {
                seriesView(values: secondaryValues, color: secondaryColor)
            }
        }
        .padding(padding)
    }

    @ViewBuilder
    private func seriesView(values: [Double], color: Color) -> some View {
        switch style {
        case .line:
            SparklineShape(values: values)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )

        case .bars:
            BarGraphShape(values: values)
                .fill(color.opacity(0.88))
        }
    }
}
