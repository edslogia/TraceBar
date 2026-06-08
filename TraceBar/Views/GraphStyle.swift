//
//  GraphStyle.swift
//  TraceBar
//

enum GraphStyle: String, Hashable {
    case line
    case bars

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
