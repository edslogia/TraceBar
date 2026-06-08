//
//  StatusBarController.swift
//  graphic-monitor
//

import AppKit
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let monitor: SystemMonitor
    private var hostingView: NSHostingView<MenuBarMonitorView>?
    private let menu = NSMenu()

    init(monitor: SystemMonitor) {
        self.monitor = monitor
        statusItem = NSStatusBar.system.statusItem(withLength: 170)
        super.init()
        configureMenu()
        configure()
        monitor.start()
    }

    private func configureMenu() {
        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func configure() {
        guard let button = statusItem.button else { return }

        button.title = ""
        button.image = nil
        button.imagePosition = .noImage
        button.target = self
        button.action = #selector(handleClick(_:))
        button.sendAction(on: [.rightMouseUp])

        let view = MenuBarMonitorView(monitor: monitor)
        let hosting = NSHostingView(rootView: view)
        hostingView = hosting

        button.subviews.forEach { $0.removeFromSuperview() }
        button.addSubview(hosting)
        hosting.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 4),
            hosting.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -4),
            hosting.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            hosting.heightAnchor.constraint(equalToConstant: 18),
            hosting.widthAnchor.constraint(equalToConstant: 164),
        ])

        ExpandedGraphPanelManager.shared.setDismissExclusionRect { [weak button] in
            guard let button, let window = button.window else { return .zero }
            return window.convertToScreen(button.convert(button.bounds, to: nil))
        }
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent, event.type == .rightMouseUp else { return }

        NSApp.activate(ignoringOtherApps: true)
        menu.popUp(
            positioning: nil,
            at: NSPoint(x: 0, y: sender.bounds.height + 4),
            in: sender
        )
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
