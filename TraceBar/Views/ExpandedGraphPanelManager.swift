//
//  ExpandedGraphPanelManager.swift
//  TraceBar
//

import AppKit
import Combine
import SwiftUI

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

    override func layout() {
        super.layout()
        configureTransparency()
    }

    private func configureTransparency() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.isOpaque = false
    }
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
        let newSize = hosting.fittingSize
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

        hosting.layoutSubtreeIfNeeded()

        let size = hosting.fittingSize
        panel.setContentSize(size)

        anchorOrigin = NSPoint(
            x: anchor.midX - size.width / 2,
            y: anchor.minY - size.height - 8
        )
        if !keepPosition {
            panel.setFrameOrigin(anchorOrigin)
        }
        NSApp.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()

        self.monitor = monitor

        if isPinned {
            removeOutsideClickMonitor()
        } else {
            installOutsideClickMonitor(for: panel)
        }
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
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
