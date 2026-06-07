//
//  GraphStyleStore.swift
//  graphic-monitor
//

import Combine
import SwiftUI

@MainActor
final class GraphStyleStore: ObservableObject {
    static let shared = GraphStyleStore()

    @Published private(set) var styles: [GraphMetric: GraphStyle]

    private let defaultsKey = "graphStylesByMetric"

    private init() {
        var loaded: [GraphMetric: GraphStyle] = [:]

        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            for (key, raw) in decoded {
                guard let metric = GraphMetric(storageKey: key) else { continue }
                loaded[metric] = GraphStyle(rawValue: raw) ?? .line
            }
        }

        styles = loaded

        for metric in GraphMetric.allCases where styles[metric] == nil {
            styles[metric] = .line
        }
    }

    func style(for metric: GraphMetric) -> GraphStyle {
        styles[metric] ?? .line
    }

    func setStyle(_ style: GraphStyle, for metric: GraphMetric) {
        guard styles[metric] != style else { return }
        styles[metric] = style
        persist()
    }

    func cycleStyle(for metric: GraphMetric, direction: Int) {
        let all = GraphStyle.allCases
        guard let currentIndex = all.firstIndex(of: style(for: metric)) else { return }
        let nextIndex = (currentIndex + direction + all.count) % all.count
        setStyle(all[nextIndex], for: metric)
    }

    private func persist() {
        let encoded = styles.reduce(into: [String: String]()) { result, pair in
            result[pair.key.storageKey] = pair.value.rawValue
        }
        if let data = try? JSONEncoder().encode(encoded) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}
