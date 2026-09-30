@preconcurrency import AppKit
import SwiftUI
import BlinkBarCore

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let onClose: () -> Void
    private var hasCentered = false

    init(
        settings: SettingsSnapshot,
        loginItemStatus: LoginItemStatus,
        onOpenLoginItems: @escaping () -> Void,
        onSave: @escaping (SettingsSnapshot) -> Void,
        onQuit: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.onClose = onClose
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        let view = SettingsView(
            settings: settings,
            loginItemStatus: loginItemStatus,
            onOpenLoginItems: onOpenLoginItems,
            onSave: onSave,
            onQuit: onQuit,
            onClose: { [weak window] in window?.close() }
        )
        window.title = "BlinkBar 设置"
        window.contentViewController = NSHostingController(rootView: view)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        guard let window else { return }
        if !hasCentered {
            window.center()
            hasCentered = true
        }
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
