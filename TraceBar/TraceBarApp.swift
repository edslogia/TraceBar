//
//  TraceBarApp.swift
//  TraceBar
//

import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var panelQuitKeyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installQuitKeyboardShortcut()
        statusBarController = StatusBarController(monitor: SystemMonitor())
    }

    /// Atajos de salida para una app de barra de menú (sin Dock ni menú de aplicación).
    /// - Monitor local: ⌘Q cuando la app está activa (p. ej. tras abrir el menú o un gráfico).
    /// - Monitor global: ⌘Q mientras el panel de gráfico sigue visible aunque el foco esté en otra app.
    private func installQuitKeyboardShortcut() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.modifierFlags.contains(.command),
                  event.charactersIgnoringModifiers?.lowercased() == "q" else {
                return event
            }
            NSApp.terminate(nil)
            return nil
        }

        panelQuitKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            guard event.modifierFlags.contains(.command),
                  event.charactersIgnoringModifiers?.lowercased() == "q" else { return }
            Task { @MainActor in
                guard ExpandedGraphPanelManager.shared.isPanelVisible else { return }
                NSApp.terminate(nil)
            }
        }
    }
}

@main
struct TraceBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
