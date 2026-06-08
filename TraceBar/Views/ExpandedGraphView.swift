//
//  ExpandedGraphView.swift
//  TraceBar
//

import AppKit
import SwiftUI

struct ExpandedGraphView: View {
    let monitor: SystemMonitor

    @ObservedObject private var panelManager = ExpandedGraphPanelManager.shared
    @ObservedObject private var styleStore = GraphStyleStore.shared
    @State private var isPinned: Bool

    init(monitor: SystemMonitor) {
        self.monitor = monitor
        _isPinned = State(initialValue: ExpandedGraphPanelManager.shared.isPinned)
    }

    private var displayedMetric: GraphMetric {
        panelManager.displayedMetric
    }

    private var displayedMetricBinding: Binding<GraphMetric> {
        Binding(
            get: { panelManager.displayedMetric },
            set: { panelManager.selectMetric($0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: displayedMetric == .network ? .top : .firstTextBaseline) {
                Text(displayedMetric.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                Button {
                    styleStore.toggleStyle(for: displayedMetric)
                } label: {
                    Image(systemName: styleStore.style(for: displayedMetric).systemImage)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(displayedMetric.color)
                        .frame(width: 20, height: 16)
                }
                .buttonStyle(.plain)
                .onHover { inside in
                    inside ? NSCursor.pointingHand.push() : NSCursor.pop()
                }
                .help(styleToggleHelp)

                Button {
                    isPinned.toggle()
                    ExpandedGraphPanelManager.shared.setPinned(isPinned)
                } label: {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isPinned ? displayedMetric.color : Color.secondary)
                        .frame(width: 20, height: 16)
                }
                .buttonStyle(.plain)
                .onHover { inside in
                    inside ? NSCursor.pointingHand.push() : NSCursor.pop()
                }
                .help(isPinned ? "Desfijar panel" : "Fijar panel")

                Spacer(minLength: 8)

                AnimatedMetricValueView(metric: displayedMetric, monitor: monitor)
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .foregroundStyle(displayedMetric.color)
                    .layoutPriority(1)
            }

            ExpandedMetricCarouselView(
                metric: displayedMetricBinding,
                styleStore: styleStore,
                monitor: monitor
            )
            .frame(height: 96)

            HStack(alignment: .firstTextBaseline) {
                Text(displayedMetric.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                Text("⌘Q to quit")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .frame(width: 300)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
                }
        }
    }

    private var styleToggleHelp: String {
        let current = styleStore.style(for: displayedMetric)
        let next = current == .line ? GraphStyle.bars : GraphStyle.line
        return "Vista \(current.title.lowercased()) · clic para \(next.title.lowercased())"
    }
}

#Preview {
    ExpandedGraphView(monitor: SystemMonitor())
        .padding()
        .onAppear {
            ExpandedGraphPanelManager.shared.selectMetric(.cpu)
        }
}
