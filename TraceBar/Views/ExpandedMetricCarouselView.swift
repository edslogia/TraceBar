//
//  ExpandedMetricCarouselView.swift
//  TraceBar
//

import AppKit
import SwiftUI

struct ExpandedMetricCarouselView: View {
    @Binding var metric: GraphMetric
    @ObservedObject var styleStore: GraphStyleStore
    let monitor: SystemMonitor

    @State private var isGraphHovered = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                graphLayer(size: geometry.size)
                arrowLayer(size: geometry.size)
            }
            .onHover { hovered in
                isGraphHovered = hovered
                if !hovered {
                    InstantTooltipManager.shared.hide()
                }
            }
        }
    }

    private func graphLayer(size: CGSize) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.thinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(metric.color.opacity(0.45), lineWidth: 1)
                }

            StyledMetricGraph(
                values: metric.history(from: monitor),
                color: metric.color,
                style: styleStore.style(for: metric),
                secondaryValues: metric.secondaryHistory(from: monitor),
                secondaryColor: metric.secondaryColor(),
                lineWidth: 2.2,
                padding: 10
            )
            .id(metric)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .contentShape(Rectangle())
        // highPriority so horizontal swipes change metric instead of moving the panel.
        .highPriorityGesture(
            DragGesture(minimumDistance: 8)
                .onEnded { value in
                    let threshold = size.width * 0.12
                    if value.translation.width < -threshold {
                        navigate(by: 1)
                    } else if value.translation.width > threshold {
                        navigate(by: -1)
                    }
                }
        )
        .onHover { inside in
            inside ? NSCursor.openHand.push() : NSCursor.pop()
        }
    }

    private func arrowLayer(size: CGSize) -> some View {
        HStack {
            navigationArrow(direction: -1)
            Spacer(minLength: 0)
            navigationArrow(direction: 1)
        }
        .padding(.horizontal, 4)
        .frame(width: size.width, height: size.height)
        .opacity(isGraphHovered ? 1 : 0)
        .animation(.easeInOut(duration: 0.15), value: isGraphHovered)
        .allowsHitTesting(isGraphHovered)
        .zIndex(1)
    }

    private func navigationArrow(direction: Int) -> some View {
        let targetMetric = metric.adjacentMetric(offset: direction)

        return Button {
            navigate(by: direction)
        } label: {
            Image(systemName: direction < 0 ? "chevron.left" : "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.black.opacity(0.55)))
        }
        .buttonStyle(.plain)
        .onHover { inside in
            if inside {
                NSCursor.pointingHand.push()
                let point = NSEvent.mouseLocation
                let anchor = NSRect(x: point.x - 11, y: point.y - 11, width: 22, height: 22)
                InstantTooltipManager.shared.show(text: targetMetric.title, anchor: anchor)
            } else {
                NSCursor.pop()
                InstantTooltipManager.shared.hide()
            }
        }
    }

    private func navigate(by direction: Int) {
        let next = metric.adjacentMetric(offset: direction)
        guard next != metric else { return }
        metric = next
    }
}
