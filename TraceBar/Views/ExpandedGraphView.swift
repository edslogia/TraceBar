//
//  ExpandedGraphView.swift
//  TraceBar
//

import AppKit
import SwiftUI

private enum ExpandedPanelLayout {
    static let panelWidth: CGFloat = 300
    static let singleGraphHeight: CGFloat = 96
    static let multiMetricSpacing: CGFloat = 10
    static let gridPanelWidth: CGFloat = panelWidth * 2
    static let gridGraphRegionHeight: CGFloat = singleGraphHeight * 2
    static let stackGraphRegionHeight: CGFloat = singleGraphHeight * 4 + multiMetricSpacing * 3
}

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

    private var displayMode: ExpandedDisplayMode {
        panelManager.displayMode
    }

    private var isMultiMetric: Bool {
        displayMode.isMultiMetric
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: headerValueAlignment) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(headerTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)

                    HStack(spacing: 0) {
                        headerIconButton(
                            help: isPinned ? "Desfijar panel" : "Fijar panel"
                        ) {
                            isPinned.toggle()
                            ExpandedGraphPanelManager.shared.setPinned(isPinned)
                        } label: {
                            Image(systemName: isPinned ? "pin.fill" : "pin")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(isPinned ? displayedMetric.color : Color.secondary)
                                .rotationEffect(.degrees(45))
                                .frame(width: 20, height: 16)
                        }

                        layoutModeButton

                        if !isMultiMetric {
                            headerIconButton(
                                systemImage: styleStore.style(for: displayedMetric).systemImage,
                                foreground: displayedMetric.color,
                                help: styleToggleHelp
                            ) {
                                styleStore.toggleStyle(for: displayedMetric)
                            }
                        }
                    }
                }

                Spacer(minLength: 8)

                if !isMultiMetric {
                    AnimatedMetricValueView(metric: displayedMetric, monitor: monitor)
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .foregroundStyle(displayedMetric.color)
                        .layoutPriority(1)
                }
            }

            graphContent

            HStack(alignment: .firstTextBaseline) {
                Text(isMultiMetric ? "All metrics" : displayedMetric.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                Text("⌘Q to quit")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .frame(width: panelWidth)
        .onChange(of: panelManager.displayMode) { _, _ in
            DispatchQueue.main.async {
                panelManager.refreshPanelSize()
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
                }
        }
        // macOS 15+: restores click-drag to move the borderless panel anywhere.
        .gesture(WindowDragGesture())
        .allowsWindowActivationEvents()
    }

    @ViewBuilder
    private var graphContent: some View {
        switch displayMode {
        case .single:
            ExpandedMetricCarouselView(
                metric: displayedMetricBinding,
                styleStore: styleStore,
                monitor: monitor
            )
            .frame(height: ExpandedPanelLayout.singleGraphHeight)
        case .grid:
            ExpandedAllMetricsGridView(monitor: monitor, styleStore: styleStore)
                .frame(height: ExpandedPanelLayout.gridGraphRegionHeight)
        case .stack:
            ExpandedAllMetricsStackView(monitor: monitor, styleStore: styleStore)
                .frame(height: ExpandedPanelLayout.stackGraphRegionHeight)
        }
    }

    private var layoutModeButton: some View {
        let foreground = isMultiMetric ? displayedMetric.color : Color.secondary
        let help = displayMode.layoutHelp(restoreMetric: displayedMetric)

        return headerIconButton(help: help) {
            panelManager.cycleDisplayMode()
        } label: {
            Group {
                switch displayMode {
                case .single:
                    Image(systemName: "square.grid.2x2")
                case .grid:
                    FourHorizontalLinesIcon(color: foreground)
                case .stack:
                    Image(systemName: "square")
                }
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(foreground)
            .frame(width: 20, height: 16)
        }
    }

    private var panelWidth: CGFloat {
        displayMode.usesWidePanel
            ? ExpandedPanelLayout.gridPanelWidth
            : ExpandedPanelLayout.panelWidth
    }

    private var headerTitle: String {
        isMultiMetric ? "All" : displayedMetric.title
    }

    private var headerValueAlignment: VerticalAlignment {
        if isMultiMetric { return .firstTextBaseline }
        return displayedMetric == .network ? .top : .firstTextBaseline
    }

    private var styleToggleHelp: String {
        let current = styleStore.style(for: displayedMetric)
        let next = current == .line ? GraphStyle.bars : GraphStyle.line
        return "Vista \(current.title.lowercased()) · clic para \(next.title.lowercased())"
    }

    private func headerIconButton(
        systemImage: String,
        foreground: Color,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        headerIconButton(help: help, action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(foreground)
                .frame(width: 20, height: 16)
        }
    }

    private func headerIconButton<Label: View>(
        help: String,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) -> some View {
        Button(action: action) {
            label()
        }
        .buttonStyle(.plain)
        .onHover { inside in
            inside ? NSCursor.pointingHand.push() : NSCursor.pop()
        }
        .help(help)
    }
}

#Preview {
    ExpandedGraphView(monitor: SystemMonitor())
        .padding()
        .onAppear {
            ExpandedGraphPanelManager.shared.selectMetric(.cpu)
        }
}
