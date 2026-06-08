//
//  InstantTooltip.swift
//  TraceBar
//

import AppKit
import SwiftUI

@MainActor
final class InstantTooltipManager {
    static let shared = InstantTooltipManager()

    private var panel: NSPanel?
    private var effectView: NSVisualEffectView?
    private var label: NSTextField?

    private init() {}

    func show(text: String, anchor: NSRect) {
        guard !text.isEmpty else { return }

        let panel = self.panel ?? makePanel()
        let effectView = self.effectView ?? makeEffectView(in: panel)
        let label = self.label ?? makeLabel(in: effectView)

        label.stringValue = text
        label.sizeToFit()

        let padding = NSEdgeInsets(top: 3, left: 6, bottom: 3, right: 6)
        let size = NSSize(
            width: label.frame.width + padding.left + padding.right,
            height: label.frame.height + padding.top + padding.bottom
        )

        effectView.frame = NSRect(origin: .zero, size: size)
        panel.setContentSize(size)
        label.frame = NSRect(
            x: padding.left,
            y: padding.bottom,
            width: label.frame.width,
            height: label.frame.height
        )

        let origin = NSPoint(
            x: anchor.midX - size.width / 2,
            y: anchor.minY - size.height - 4
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
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        self.panel = panel
        return panel
    }

    private func makeEffectView(in panel: NSPanel) -> NSVisualEffectView {
        let effectView = NSVisualEffectView()
        effectView.material = .toolTip
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 5
        effectView.layer?.masksToBounds = true
        panel.contentView = effectView
        self.effectView = effectView
        return effectView
    }

    private func makeLabel(in effectView: NSVisualEffectView) -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 11)
        label.textColor = .labelColor
        label.backgroundColor = .clear
        label.isBezeled = false
        label.isEditable = false
        label.isSelectable = false
        effectView.addSubview(label)
        self.label = label
        return label
    }
}

struct InstantTooltipOverlay: NSViewRepresentable {
    let text: String
    var onTap: ((NSRect) -> Void)? = nil

    func makeNSView(context: Context) -> InstantTooltipView {
        InstantTooltipView()
    }

    func updateNSView(_ nsView: InstantTooltipView, context: Context) {
        nsView.text = text
        nsView.onTap = onTap
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

    var onTap: ((NSRect) -> Void)?

    private var trackingArea: NSTrackingArea?
    private var isMouseInside = false
    private var dragStartPoint: NSPoint?

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

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseEntered(with event: NSEvent) {
        isMouseInside = true
        presentTooltip()
    }

    override func mouseExited(with event: NSEvent) {
        isMouseInside = false
        dragStartPoint = nil
        Task { @MainActor in
            InstantTooltipManager.shared.hide()
        }
    }

    override func mouseDown(with event: NSEvent) {
        dragStartPoint = convert(event.locationInWindow, from: nil)
    }

    override func mouseUp(with event: NSEvent) {
        defer { dragStartPoint = nil }

        guard let dragStartPoint else { return }
        let current = convert(event.locationInWindow, from: nil)
        let deltaX = abs(current.x - dragStartPoint.x)
        let deltaY = abs(current.y - dragStartPoint.y)
        guard deltaX <= 6, deltaY <= 6 else { return }

        guard let onTap, let window else { return }
        InstantTooltipManager.shared.hide()
        let screenRect = window.convertToScreen(convert(bounds, to: nil))
        Task { @MainActor in
            onTap(screenRect)
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
