//
//  GraphStyleCarouselView.swift
//  graphic-monitor
//

import SwiftUI

struct GraphStyleCarouselView<Background: View>: View {
    let metric: GraphMetric
    @ObservedObject var styleStore: GraphStyleStore
    let background: Background
    let graphContent: (_ style: GraphStyle) -> AnyView

    @State private var isHovered = false

    init(
        metric: GraphMetric,
        styleStore: GraphStyleStore = .shared,
        @ViewBuilder background: () -> Background,
        @ViewBuilder graphContent: @escaping (_ style: GraphStyle) -> some View
    ) {
        self.metric = metric
        self.styleStore = styleStore
        self.background = background()
        self.graphContent = { AnyView(graphContent($0)) }
    }

    private var currentStyle: GraphStyle {
        styleStore.style(for: metric)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ZStack {
                    background

                    graphContent(currentStyle)
                        .id(currentStyle)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 8)
                        .onEnded { value in
                            let threshold = geometry.size.width * 0.12
                            if value.translation.width < -threshold {
                                styleStore.cycleStyle(for: metric, direction: 1)
                            } else if value.translation.width > threshold {
                                styleStore.cycleStyle(for: metric, direction: -1)
                            }
                        }
                )

                HStack {
                    navigationArrow(direction: -1)
                    Spacer(minLength: 0)
                    navigationArrow(direction: 1)
                }
                .padding(.horizontal, 4)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .opacity(isHovered ? 1 : 0)
                .animation(.easeInOut(duration: 0.15), value: isHovered)
                .allowsHitTesting(isHovered)
                .zIndex(1)
            }
            .onHover { isHovered = $0 }
        }
    }

    private func navigationArrow(direction: Int) -> some View {
        Button {
            styleStore.cycleStyle(for: metric, direction: direction)
        } label: {
            Image(systemName: direction < 0 ? "chevron.left" : "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.black.opacity(0.55)))
        }
        .buttonStyle(.plain)
        .help(direction < 0 ? "Vista anterior" : "Vista siguiente")
    }
}
