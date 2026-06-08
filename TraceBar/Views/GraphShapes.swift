//
//  GraphShapes.swift
//  TraceBar
//

import SwiftUI

struct BarGraphShape: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        guard !values.isEmpty else { return Path() }

        var path = Path()
        let barWidth = max(rect.width / CGFloat(values.count) * 0.72, 1)
        let stepX = rect.width / CGFloat(values.count)

        for (index, value) in values.enumerated() {
            let barHeight = CGFloat(value) * rect.height
            let x = CGFloat(index) * stepX + (stepX - barWidth) / 2
            let y = rect.height - barHeight
            path.addRect(CGRect(x: x, y: y, width: barWidth, height: barHeight))
        }

        return path
    }
}
