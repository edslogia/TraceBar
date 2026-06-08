//
//  GraphStyle.swift
//  graphic-monitor
//

import SwiftUI

enum GraphStyle: String, CaseIterable, Codable, Identifiable, Hashable {
    case line
    case bars

    var id: String { rawValue }

    var title: String {
        switch self {
        case .line: "Línea"
        case .bars: "Barras"
        }
    }

    var systemImage: String {
        switch self {
        case .line: "chart.xyaxis.line"
        case .bars: "chart.bar.fill"
        }
    }
}
