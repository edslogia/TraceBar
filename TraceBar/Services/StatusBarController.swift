//
//  StatusBarController.swift
//  TraceBar
//

import AppKit
import OSLog
import SwiftUI

private let statusLog = Logger(subsystem: "logiatecnologia.TraceBar", category: "StatusBar")

@MainActor
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let monitor: SystemMonitor
    private let menu = NSMenu()
    private var hostingView: NSHostingView<MenuBarMonitorView>?
    private var localMouseMonitor: Any?
    private var globalMouseMonitor: Any?
    private var mouseDownLocation: NSPoint?
    private var lastHandledTapUptime: TimeInterval = 0

    /// Matches MenuBarMonitorView: 4×38pt graphs with 3pt gaps inside a 164pt hosting view.
    private let graphWidth: CGFloat = 38
    private let graphSpacing: CGFloat = 3
    private let hostingLeadingInset: CGFloat = 4

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

        let hosting = NSHostingView(rootView: MenuBarMonitorView(monitor: monitor))
        hostingView = hosting

        button.subviews.forEach { $0.removeFromSuperview() }
        button.addSubview(hosting)
        hosting.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: hostingLeadingInset),
            hosting.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -4),
            hosting.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            hosting.heightAnchor.constraint(equalToConstant: 18),
            hosting.widthAnchor.constraint(equalToConstant: 164),
        ])

        ExpandedGraphPanelManager.shared.setDismissExclusionRect { [weak button] in
            guard let button, let window = button.window else { return .zero }
            return window.convertToScreen(button.convert(button.bounds, to: nil))
        }

        installMouseMonitors()
    }

    /// macOS 27 may route status-item clicks via MenuBarAgent; use local + global monitors.
    private func installMouseMonitors() {
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { [weak self] event in
            self?.handleStatusItemMouse(event)
            return event
        }
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { [weak self] event in
            DispatchQueue.main.async {
                self?.handleStatusItemMouse(event)
            }
        }
    }

    private func handleStatusItemMouse(_ event: NSEvent) {
        guard let button = statusItem.button else { return }
        // Prefer accessibilityFrame — macOS 27 status-item scenes may lack a normal NSWindow.
        let screenPoint = NSEvent.mouseLocation
        let buttonScreen = screenRect(for: button)
        guard buttonScreen.width > 0, buttonScreen.contains(screenPoint) else {
            if event.type == .leftMouseDown {
                mouseDownLocation = nil
            }
            return
        }

        if event.type == .leftMouseDown {
            mouseDownLocation = screenPoint
            return
        }

        guard event.type == .leftMouseUp, let down = mouseDownLocation else { return }
        mouseDownLocation = nil

        let dx = abs(screenPoint.x - down.x)
        let dy = abs(screenPoint.y - down.y)
        guard dx <= 6, dy <= 6 else { return }

        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastHandledTapUptime > 0.2 else { return }
        lastHandledTapUptime = now

        guard let hosting = hostingView else { return }
        let hostingScreen = screenRect(for: hosting)
        let localX = screenPoint.x - hostingScreen.minX
        guard let metric = metricAtHostingX(localX) else {
            statusLog.error("tap missed metric localX=\(localX, format: .fixed(precision: 1)) hosting=\(String(describing: hostingScreen), privacy: .public)")
            return
        }

        let graphFrameInHosting = frameInHosting(for: metric)
        let anchor: NSRect
        if let window = hosting.window {
            anchor = window.convertToScreen(hosting.convert(graphFrameInHosting, to: nil))
        } else {
            anchor = NSRect(
                x: hostingScreen.minX + graphFrameInHosting.minX,
                y: hostingScreen.minY,
                width: graphFrameInHosting.width,
                height: hostingScreen.height
            )
        }

        statusLog.info("tap metric=\(String(describing: metric), privacy: .public) localX=\(localX, format: .fixed(precision: 1))")
        InstantTooltipManager.shared.hide()
        ExpandedGraphPanelManager.shared.toggle(
            metric: metric,
            monitor: monitor,
            anchor: anchor
        )
    }

    private func screenRect(for view: NSView) -> NSRect {
        if let window = view.window {
            return window.convertToScreen(view.convert(view.bounds, to: nil))
        }
        return view.accessibilityFrame()
    }

    private func metricAtHostingX(_ x: CGFloat) -> GraphMetric? {
        let stride = graphWidth + graphSpacing
        let metrics = GraphMetric.allCases
        for (index, metric) in metrics.enumerated() {
            let minX = CGFloat(index) * stride
            let maxX = minX + graphWidth
            if x >= minX, x < maxX {
                return metric
            }
        }
        return nil
    }

    private func frameInHosting(for metric: GraphMetric) -> NSRect {
        let index = GraphMetric.allCases.firstIndex(of: metric) ?? 0
        let stride = graphWidth + graphSpacing
        let x = CGFloat(index) * stride
        return NSRect(x: x, y: 0, width: graphWidth, height: 18)
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

    func stopMonitoring() {
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
        monitor.stop()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
