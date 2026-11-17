//
//  ExpandedGraphPanelManager.swift
//  TraceBar
//

import AppKit
import Combine
import OSLog
import SwiftUI

private let panelLog = Logger(subsystem: "logiatecnologia.TraceBar", category: "ExpandedPanel")

private final class DraggableHostingView<Content: View>: NSHostingView<Content> {
    override var mouseDownCanMoveWindow: Bool { true }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .openHand)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureTransparency()
    }

    private func configureTransparency() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.isOpaque = false
    }
}

/// Panel that can become key on macOS 27 glass/status-item hosts.
private final class ExpandedMetricPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class ExpandedGraphPanelManager: ObservableObject {
    static let shared = ExpandedGraphPanelManager()

    @Published private(set) var displayedMetric: GraphMetric = .cpu
    @Published private(set) var displayMode: ExpandedDisplayMode = .single

    private var metricBeforeMultiView: GraphMetric?
    private var panel: NSPanel?
    private var hostingView: DraggableHostingView<ExpandedGraphView>?
    private weak var monitor: SystemMonitor?
    private var outsideClickMonitor: Any?
    private var dismissExclusionRect: (() -> NSRect)?
    private(set) var isPinned = false
    private var anchorOrigin: NSPoint = .zero

    private init() {}

    var isPanelVisible: Bool {
        panel?.isVisible == true
    }

    func setPinned(_ pinned: Bool) {
        isPinned = pinned
        guard let panel, panel.isVisible else { return }

        if pinned {
            removeOutsideClickMonitor()
        } else {
            installOutsideClickMonitor(for: panel)
        }
    }

    func setDismissExclusionRect(_ provider: @escaping () -> NSRect) {
        dismissExclusionRect = provider
    }

    func selectMetric(_ metric: GraphMetric) {
        guard displayedMetric != metric else { return }
        displayedMetric = metric
    }

    func cycleDisplayMode() {
        let next = displayMode.next

        switch (displayMode, next) {
        case (.single, .grid):
            metricBeforeMultiView = displayedMetric
        case (.stack, .single):
            if let restored = metricBeforeMultiView {
                displayedMetric = restored
            }
            metricBeforeMultiView = nil
        default:
            break
        }

        displayMode = next
    }

    func refreshPanelSize() {
        guard let panel, let hosting = hostingView, panel.isVisible else { return }

        hosting.layoutSubtreeIfNeeded()
        let newSize = resolvedSize(for: hosting)
        let oldFrame = panel.frame
        let newOrigin = NSPoint(
            x: oldFrame.origin.x + (oldFrame.width - newSize.width) / 2,
            y: oldFrame.origin.y + (oldFrame.height - newSize.height)
        )
        panel.setFrame(NSRect(origin: newOrigin, size: newSize), display: true)
    }

    func toggle(metric: GraphMetric, monitor: SystemMonitor, anchor: NSRect) {
        if panel?.isVisible == true, displayedMetric == metric {
            hide()
            return
        }

        show(metric: metric, monitor: monitor, anchor: anchor)
    }

    func hide() {
        removeOutsideClickMonitor()
        isPinned = false
        displayMode = .single
        metricBeforeMultiView = nil
        resetPanelPosition()
        panel?.orderOut(nil)
        self.monitor = nil
    }

    private func show(metric: GraphMetric, monitor: SystemMonitor, anchor: NSRect) {
        InstantTooltipManager.shared.hide()

        displayedMetric = metric
        displayMode = .single
        metricBeforeMultiView = nil

        let panel = self.panel ?? makePanel()
        let hosting = self.hostingView ?? makeHostingView(in: panel, monitor: monitor)
        let keepPosition = panel.isVisible && isPinned

        if self.monitor !== monitor {
            hosting.rootView = ExpandedGraphView(monitor: monitor)
        }

        self.monitor = monitor

        hosting.layoutSubtreeIfNeeded()
        let size = resolvedSize(for: hosting)
        panel.setContentSize(size)

        anchorOrigin = origin(for: size, anchor: anchor)
        if !keepPosition {
            panel.setFrameOrigin(anchorOrigin)
        }

        // isFloatingPanel resets level — set level after.
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true

        NSApp.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)

        panelLog.info(
            "show metric=\(String(describing: metric), privacy: .public) size=\(size.width, format: .fixed(precision: 1))x\(size.height, format: .fixed(precision: 1)) origin=(\(self.anchorOrigin.x, format: .fixed(precision: 1)),\(self.anchorOrigin.y, format: .fixed(precision: 1))) visible=\(panel.isVisible) frame=\(String(describing: panel.frame), privacy: .public)"
        )

        if isPinned {
            removeOutsideClickMonitor()
        } else {
            installOutsideClickMonitor(for: panel)
        }
    }

    private func resolvedSize(for hosting: NSView) -> NSSize {
        let fitted = hosting.fittingSize
        if fitted.width > 1, fitted.height > 1 {
            return fitted
        }
        // Fallback when NSHostingView reports zero before first real layout (macOS 27).
        return NSSize(width: 300, height: 200)
    }

    private func origin(for size: NSSize, anchor: NSRect) -> NSPoint {
        var origin = NSPoint(
            x: anchor.midX - size.width / 2,
            y: anchor.minY - size.height - 8
        )

        let screen = NSScreen.screens.first { $0.frame.intersects(anchor) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen else { return origin }

        let visible = screen.visibleFrame
        origin.x = min(max(origin.x, visible.minX + 4), max(visible.maxX - size.width - 4, visible.minX + 4))
        origin.y = min(max(origin.y, visible.minY + 4), max(visible.maxY - size.height - 4, visible.minY + 4))
        return origin
    }

    private func makePanel() -> NSPanel {
        let panel = ExpandedMetricPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        self.panel = panel
        return panel
    }

    private func makeHostingView(
        in panel: NSPanel,
        monitor: SystemMonitor
    ) -> DraggableHostingView<ExpandedGraphView> {
        let hosting = DraggableHostingView(
            rootView: ExpandedGraphView(monitor: monitor)
        )
        panel.contentView = hosting
        self.hostingView = hosting
        return hosting
    }

    private func installOutsideClickMonitor(for panel: NSPanel) {
        removeOutsideClickMonitor()

        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self, weak panel] _ in
            guard let self, let panel, panel.isVisible else { return }

            let screenPoint = NSEvent.mouseLocation
            if panel.frame.contains(screenPoint) { return }
            if let exclusion = self.dismissExclusionRect?(), exclusion.contains(screenPoint) { return }

            Task { @MainActor in
                self.hide()
            }
        }
    }

    private func removeOutsideClickMonitor() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
    }

    private func resetPanelPosition() {
        panel?.setFrameOrigin(anchorOrigin)
    }
}
