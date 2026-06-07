//
//  InstantTooltip.swift
//  graphic-monitor
//

import AppKit
import SwiftUI

@MainActor
final class InstantTooltipManager {
    static let shared = InstantTooltipManager()

    private var panel: NSPanel?
    private var label: NSTextField?

    private init() {}

    func show(text: String, anchor: NSRect) {
        guard !text.isEmpty else { return }

        let panel = self.panel ?? makePanel()
        let label = self.label ?? makeLabel(in: panel)

        label.stringValue = text
        label.sizeToFit()

        let padding = NSEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        let size = NSSize(
            width: label.frame.width + padding.left + padding.right,
            height: label.frame.height + padding.top + padding.bottom
        )

        panel.setContentSize(size)
        label.frame = NSRect(
            x: padding.left,
            y: padding.bottom,
            width: label.frame.width,
            height: label.frame.height
        )

        let origin = NSPoint(
            x: anchor.midX - size.width / 2,
            y: anchor.minY - size.height - 6
        )
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
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
        panel.backgroundColor = NSColor(white: 0.12, alpha: 0.95)
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        self.panel = panel
        return panel
    }

    private func makeLabel(in panel: NSPanel) -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        label.textColor = .white
        label.backgroundColor = .clear
        label.isBezeled = false
        label.isEditable = false
        label.isSelectable = false
        panel.contentView?.addSubview(label)
        self.label = label
        return label
    }
}

struct InstantTooltipOverlay: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> InstantTooltipView {
        InstantTooltipView()
    }

    func updateNSView(_ nsView: InstantTooltipView, context: Context) {
        nsView.text = text
    }
}

final class InstantTooltipView: NSView {
    var text: String = "" {
        didSet {
            if isMouseInside {
                presentTooltip()
            }
        }
    }

    private var trackingArea: NSTrackingArea?
    private var isMouseInside = false

    override var isFlipped: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isMouseInside = true
        presentTooltip()
    }

    override func mouseExited(with event: NSEvent) {
        isMouseInside = false
        Task { @MainActor in
            InstantTooltipManager.shared.hide()
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    private func presentTooltip() {
        guard let window else { return }
        let screenRect = window.convertToScreen(convert(bounds, to: nil))
        Task { @MainActor in
            InstantTooltipManager.shared.show(text: text, anchor: screenRect)
        }
    }
}
