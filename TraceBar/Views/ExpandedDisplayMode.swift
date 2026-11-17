//
//  ExpandedDisplayMode.swift
//  TraceBar
//

import SwiftUI

enum ExpandedDisplayMode: Equatable {
    case single
    case grid
    case stack

    var isMultiMetric: Bool {
        self != .single
    }

    var next: ExpandedDisplayMode {
        switch self {
        case .single: .grid
        case .grid: .stack
        case .stack: .single
        }
    }

    var usesWidePanel: Bool {
        self == .grid
    }

    func layoutHelp(restoreMetric: GraphMetric) -> String {
        switch self {
        case .single:
            "Mostrar cuadrícula"
        case .grid:
            "Apilar gráficas verticalmente"
        case .stack:
            "Restaurar \(restoreMetric.title)"
        }
    }
}

struct FourHorizontalLinesIcon: View {
    var color: Color

    var body: some View {
        VStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 0.5, style: .continuous)
                    .fill(color)
                    .frame(height: 1.5)
            }
        }
        .frame(width: 12, height: 12)
    }
}
