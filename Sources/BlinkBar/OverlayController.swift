@preconcurrency import AppKit
import SwiftUI
import BlinkBarCore

@MainActor
final class OverlayController {
    private var panels: [CGDirectDisplayID: OverlayPanel] = [:]
    private var actionPanels: [CGDirectDisplayID: OverlayActionPanel] = [:]
    private var activeReminder: ActiveReminder?
    private var activeSettings = SettingsSnapshot.default
    private var activeNow = Date()

    func show(reminder: ActiveReminder, settings: SettingsSnapshot, now: Date) {
        activeReminder = reminder
        activeSettings = settings
        activeNow = now
        rebuildIfVisible()
    }

    private var onSkip: (() -> Void)?

    func setSkipHandler(_ handler: @escaping () -> Void) { onSkip = handler }

    func update(now: Date) {
        guard activeReminder != nil else { return }
        activeNow = now
        let remaining = max(0, activeReminder!.endsAt.timeIntervalSince(now))
        for panel in panels.values {
            panel.contentView = NSHostingView(rootView: OverlayView(reminder: activeReminder!, remaining: remaining))
        }
    }

    func hide() {
        activeReminder = nil
        panels.values.forEach { $0.orderOut(nil) }
        panels.removeAll()
        actionPanels.values.forEach { $0.orderOut(nil) }
        actionPanels.removeAll()
    }

    func rebuildIfVisible() {
        guard let reminder = activeReminder else { return }
        panels.values.forEach { $0.orderOut(nil) }
        panels.removeAll()
        actionPanels.values.forEach { $0.orderOut(nil) }
        actionPanels.removeAll()
        let screens = targetScreens()
        let remaining = max(0, reminder.endsAt.timeIntervalSince(activeNow))
        for screen in screens {
            let id = displayID(for: screen)
            let panel = OverlayPanel(frame: screen.frame, joinsFullScreen: activeSettings.fullScreenEnabled)
            panel.contentView = NSHostingView(rootView: OverlayView(reminder: reminder, remaining: remaining))
            panels[id] = panel
            panel.orderFrontRegardless()
            guard reminder.kind == .distance else { continue }
            let actionPanel = OverlayActionPanel()
            actionPanels[id] = actionPanel
            actionPanel.show(on: screen, joinsFullScreen: activeSettings.fullScreenEnabled) { [weak self] in
                self?.onSkip?()
            }
        }
    }

    private func targetScreens() -> [NSScreen] {
        if activeSettings.allDisplays, !NSScreen.screens.isEmpty { return NSScreen.screens }
        let location = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(location) }) { return [screen] }
        if let main = NSScreen.main { return [main] }
        return NSScreen.screens.first.map { [$0] } ?? []
    }

    private func displayID(for screen: NSScreen) -> CGDirectDisplayID {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return CGMainDisplayID()
        }
        let value = number.uint32Value
        return value == 0 ? CGMainDisplayID() : CGDirectDisplayID(value)
    }
}
