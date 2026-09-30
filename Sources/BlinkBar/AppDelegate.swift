@preconcurrency import AppKit
import CoreServices
import BlinkBarCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settingsStore: SettingsStore
    private let loginItemController = LoginItemController()
    private var engine: ReminderEngine
    private var statusMenu: StatusMenuController!
    private var settingsWindow: SettingsWindowController?
    private var overlayController: OverlayController!
    private var activityMonitor: ActivityMonitor!
    private var timer: Timer?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var lastSettings: SettingsSnapshot
    private var launchedAsLoginItem = false
    private var pendingLoginItemError: Error?

    override init() {
        let store = SettingsStore()
        let settings = store.settings
        let now = Date()
        self.settingsStore = store
        self.lastSettings = settings
        self.engine = ReminderEngine(
            settings: settings,
            now: now,
            pauseUntil: store.pauseUntil
        )
        if let pauseUntil = store.pauseUntil, pauseUntil <= now {
            store.setPauseUntil(nil)
        }
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        launchedAsLoginItem = Self.wasLaunchedAsLoginItem()
        overlayController = OverlayController()
        overlayController.setSkipHandler { [weak self] in self?.skipCurrent() }
        statusMenu = StatusMenuController(
            settingsStore: settingsStore,
            onPause: { [weak self] choice in self?.pause(choice) },
            onSettings: { [weak self] in self?.showSettings() },
            onToggle: { [weak self] kind in self?.toggleReminder(kind) },
            onSkip: { [weak self] in self?.skipCurrent() },
            onQuit: { [weak self] in self?.quit() }
        )
        activityMonitor = ActivityMonitor(
            enabled: settingsStore.settings.idleResetEnabled,
            threshold: settingsStore.settings.idleThreshold
        ) { [weak self] inactive in
            self?.setInactive(.idle, active: inactive)
        }
        activityMonitor.start()
        settingsStore.onChange = { [weak self] settings in
            self?.applySettings(settings)
        }
        installSystemObservers()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
        reconcileLoginItem()
        handle(events: engine.tick(now: Date()), now: Date())
        refreshMenu()
        if !launchedAsLoginItem {
            showSettings()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }

    private func tick() {
        let now = Date()
        handle(events: engine.tick(now: now), now: now)
        overlayController.update(now: now)
        refreshMenu()
    }

    private func pause(_ choice: PauseChoice) {
        let now = Date()
        let until = SchedulePolicy.pauseUntil(choice: choice, now: now)
        settingsStore.setPauseUntil(until)
        handle(events: engine.pause(until: until, now: now), now: now)
        refreshMenu()
    }

    private func skipCurrent() {
        let now = Date()
        handle(events: engine.skipCurrent(now: now), now: now)
        refreshMenu()
    }

    private func toggleReminder(_ kind: ReminderKind) {
        var settings = settingsStore.settings
        switch kind {
        case .blink:
            settings.blinkEnabled.toggle()
        case .distance:
            settings.distanceEnabled.toggle()
        }
        settingsStore.setSettings(settings)
    }

    private func applySettings(_ settings: SettingsSnapshot) {
        let now = Date()
        let old = lastSettings
        lastSettings = settings
        activityMonitor?.update(enabled: settings.idleResetEnabled, threshold: settings.idleThreshold)
        handle(events: engine.update(settings: settings, now: now), now: now)
        if old.launchAtLogin != settings.launchAtLogin {
            do {
                try loginItemController.setEnabled(settings.launchAtLogin)
            } catch {
                var reverted = settings
                reverted.launchAtLogin = loginItemController.isEnabled
                settingsStore.setSettings(reverted, notify: false)
                lastSettings = reverted
                present(error: error)
            }
        }
        refreshMenu()
    }

    private func reconcileLoginItem() {
        guard settingsStore.settings.launchAtLogin else { return }
        do {
            try loginItemController.setEnabled(true)
        } catch {
            var reverted = settingsStore.settings
            reverted.launchAtLogin = loginItemController.isEnabled
            settingsStore.setSettings(reverted, notify: false)
            lastSettings = reverted
            if launchedAsLoginItem {
                pendingLoginItemError = error
            } else {
                present(error: error)
            }
        }
    }

    private func showSettings() {
        if let settingsWindow {
            settingsWindow.show()
        } else {
            let controller = SettingsWindowController(
                settings: settingsStore.settings,
                loginItemStatus: loginItemController.status,
                onOpenLoginItems: { [weak self] in
                    self?.loginItemController.openSystemSettingsLoginItems()
                },
                onSave: { [weak self] settings in
                    self?.settingsStore.setSettings(settings)
                },
                onQuit: { [weak self] in
                    self?.quit()
                },
                onClose: { [weak self] in
                    self?.settingsWindow = nil
                }
            )
            settingsWindow = controller
            controller.show()
        }

        if let error = pendingLoginItemError {
            pendingLoginItemError = nil
            present(error: error)
        }
    }

    private func setInactive(_ reason: InactiveReason, active: Bool) {
        let now = Date()
        let events = active ? engine.addInactive(reason, now: now) : engine.removeInactive(reason, now: now)
        handle(events: events, now: now)
        refreshMenu()
    }

    private func handle(events: [ReminderEngineEvent], now: Date) {
        for event in events {
            switch event {
            case let .show(reminder):
                if engine.settings.soundEnabled {
                    NSSound.beep()
                }
                overlayController.show(reminder: reminder, settings: engine.settings, now: now)
            case .hide:
                overlayController.hide()
            case .pauseChanged(let until):
                settingsStore.setPauseUntil(until)
            case .scheduleChanged, .resumed:
                break
            }
        }
        refreshMenu()
    }

    private func refreshMenu() {
        guard statusMenu != nil else { return }
        let now = Date()
        statusMenu.update(snapshot: engine.snapshot(now: now), now: now)
    }

    private func quit() {
        NSApp.terminate(nil)
    }

    private func installSystemObservers() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        observers.append((workspaceCenter, workspaceCenter.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor [weak self] in self?.setInactive(.sleep, active: true) } }))
        observers.append((workspaceCenter, workspaceCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor [weak self] in self?.setInactive(.sleep, active: false) } }))
        observers.append((workspaceCenter, workspaceCenter.addObserver(
            forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor [weak self] in self?.setInactive(.screensSleep, active: true) } }))
        observers.append((workspaceCenter, workspaceCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor [weak self] in self?.setInactive(.screensSleep, active: false) } }))

        let center = DistributedNotificationCenter.default()
        observers.append((center, center.addObserver(
            forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor [weak self] in self?.setInactive(.locked, active: true) } }))
        observers.append((center, center.addObserver(
            forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor [weak self] in self?.setInactive(.locked, active: false) } }))

        observers.append((NotificationCenter.default, NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor [weak self] in self?.overlayController.rebuildIfVisible() } }))
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        timer = nil
        activityMonitor?.stop()
        statusMenu?.stop()
        observers.forEach { $0.0.removeObserver($0.1) }
        observers.removeAll()
    }

    private func present(error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "BlinkBar 设置失败"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "好")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private static func wasLaunchedAsLoginItem() -> Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              event.eventClass == kCoreEventClass,
              event.eventID == kAEOpenApplication else {
            return false
        }

        return event.paramDescriptor(forKeyword: keyAELaunchedAsLogInItem) != nil
    }

}
