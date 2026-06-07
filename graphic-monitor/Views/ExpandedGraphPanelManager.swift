//
//  ExpandedGraphPanelManager.swift
//  graphic-monitor
//

import AppKit
import SwiftUI

private final class DraggableHostingView<Content: View>: NSHostingView<Content> {
    override var mouseDownCanMoveWindow: Bool { true }

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
final class ExpandedGraphPanelManager {
    static let shared = ExpandedGraphPanelManager()

    private var panel: NSPanel?
    private var hostingView: DraggableHostingView<ExpandedGraphView>?
    private var currentMetric: GraphMetric?
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

    func toggle(metric: GraphMetric, monitor: SystemMonitor, anchor: NSRect) {
        if panel?.isVisible == true, currentMetric == metric {
            hide()
            return
        }

        show(metric: metric, monitor: monitor, anchor: anchor)
    }

    func hide() {
        removeOutsideClickMonitor()
        isPinned = false
        resetPanelPosition()
        panel?.orderOut(nil)
        currentMetric = nil
        self.monitor = nil
    }

    private func show(metric: GraphMetric, monitor: SystemMonitor, anchor: NSRect) {
        InstantTooltipManager.shared.hide()

        let panel = self.panel ?? makePanel()
        let hosting = self.hostingView ?? makeHostingView(in: panel)
        let keepPosition = panel.isVisible && isPinned

        hosting.rootView = ExpandedGraphView(metric: metric, monitor: monitor)
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

        self.currentMetric = metric
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

    private func makeHostingView(in panel: NSPanel) -> DraggableHostingView<ExpandedGraphView> {
        let hosting = DraggableHostingView(
            rootView: ExpandedGraphView(metric: .cpu, monitor: SystemMonitor())
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
