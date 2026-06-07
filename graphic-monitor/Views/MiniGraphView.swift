//
//  MiniGraphView.swift
//  graphic-monitor
//

import SwiftUI

struct MiniGraphView: View {
    let data: [Double]
    let color: Color
    let tooltip: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color(white: 0.12))
                .overlay {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(color.opacity(0.6), lineWidth: 0.75)
                }

            SparklineShape(values: data)
                .stroke(color, style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
                .padding(2)
        }
        .frame(width: 38, height: 18)
        .contentShape(Rectangle())
        .overlay {
            InstantTooltipOverlay(text: tooltip)
        }
    }
}

private struct SparklineShape: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        guard values.count > 1 else { return Path() }

        var path = Path()
        let stepX = rect.width / CGFloat(values.count - 1)

        for (index, value) in values.enumerated() {
            let x = CGFloat(index) * stepX
            let y = rect.height - (CGFloat(value) * rect.height)

            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        return path
    }
}

#Preview {
    HStack(spacing: 4) {
        MiniGraphView(
            data: [0.1, 0.3, 0.5, 0.8, 0.4, 0.6, 0.9, 0.2],
            color: Color(red: 0.45, green: 0.82, blue: 0.09),
            tooltip: "CPU: 45%"
        )
        MiniGraphView(
            data: [0.2, 0.4, 0.3, 0.7, 0.5, 0.6, 0.4, 0.8],
            color: Color(red: 0.99, green: 0.69, blue: 0.24),
            tooltip: "GPU: 12%"
        )
    }
    .padding()
}
