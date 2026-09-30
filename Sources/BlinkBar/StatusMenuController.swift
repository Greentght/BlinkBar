@preconcurrency import AppKit
import BlinkBarCore

@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    private let settingsStore: SettingsStore
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let blinkCountdownItem = NSMenuItem(title: "下一次眨眼：正在计算…", action: nil, keyEquivalent: "")
    private let distanceCountdownItem = NSMenuItem(title: "下一次看远：正在计算…", action: nil, keyEquivalent: "")
    private let blinkToggleItem = NSMenuItem(title: "眨眼提醒", action: #selector(blinkToggleSelected), keyEquivalent: "")
    private let distanceToggleItem = NSMenuItem(title: "远眺提醒", action: #selector(distanceToggleSelected), keyEquivalent: "")
    private let stateItem = NSMenuItem(title: "运行中", action: nil, keyEquivalent: "")
    private let skipItem = NSMenuItem(title: "跳过当前提醒", action: #selector(skipSelected), keyEquivalent: "")
    private var pauseItems: [PauseChoice: NSMenuItem] = [:]
    private var menuTimer: Timer?
    private var latestSnapshot: EngineSnapshot?
    private var latestNow = Date()
    private let onPause: (PauseChoice) -> Void
    private let onSettings: () -> Void
    private let onToggle: (ReminderKind) -> Void
    private let onSkip: () -> Void
    private let onQuit: () -> Void

    init(
        settingsStore: SettingsStore,
        onPause: @escaping (PauseChoice) -> Void,
        onSettings: @escaping () -> Void,
        onToggle: @escaping (ReminderKind) -> Void,
        onSkip: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.settingsStore = settingsStore
        self.onPause = onPause
        self.onSettings = onSettings
        self.onToggle = onToggle
        self.onSkip = onSkip
        self.onQuit = onQuit
        super.init()
        menu.delegate = self
        statusItem.button?.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "BlinkBar")
        statusItem.button?.imagePosition = .imageOnly
        buildMenu()
    }

    private func buildMenu() {
        menu.autoenablesItems = false
        let headerItem = NSMenuItem(title: "BlinkBar", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        stateItem.isEnabled = false
        menu.addItem(stateItem)
        blinkCountdownItem.isEnabled = false
        distanceCountdownItem.isEnabled = false
        menu.addItem(blinkCountdownItem)
        menu.addItem(distanceCountdownItem)
        blinkToggleItem.target = self
        distanceToggleItem.target = self
        menu.addItem(blinkToggleItem)
        menu.addItem(distanceToggleItem)
        menu.addItem(.separator())

        let pause = NSMenuItem(title: "暂停", action: nil, keyEquivalent: "")
        let pauseMenu = NSMenu(title: "暂停")
        for choice in PauseChoice.allCases {
            let item = NSMenuItem(title: title(for: choice), action: #selector(pauseSelected(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = choice.rawValue
            pauseItems[choice] = item
            pauseMenu.addItem(item)
        }
        pause.submenu = pauseMenu
        menu.addItem(pause)

        skipItem.target = self
        menu.addItem(skipItem)
        menu.addItem(.separator())

        let settings = NSMenuItem(title: "设置…", action: #selector(settingsSelected), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        let quit = NSMenuItem(title: "退出 BlinkBar", action: #selector(quitSelected), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
    }

    func update(snapshot: EngineSnapshot, now: Date) {
        latestSnapshot = snapshot
        latestNow = now
        render(snapshot: snapshot, now: now)
    }

    func menuWillOpen(_ menu: NSMenu) {
        menuTimer?.invalidate()
        menuTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let snapshot = self.latestSnapshot else { return }
                self.latestNow = Date()
                self.render(snapshot: snapshot, now: self.latestNow)
            }
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        menuTimer?.invalidate()
        menuTimer = nil
    }

    func stop() {
        menuTimer?.invalidate()
        menuTimer = nil
    }

    private func render(snapshot: EngineSnapshot, now: Date) {
        let settings = settingsStore.settings
        switch snapshot.mode {
        case .running:
            stateItem.title = "运行中"
        case .showing(let reminder):
            stateItem.title = reminder.kind == .blink ? "眨眼提醒进行中" : "看远提醒进行中"
        case .paused(let until):
            stateItem.title = "已暂停至 \(timeString(until))"
        case .inactive(let reasons):
            stateItem.title = "暂时暂停（\(reasons.count) 个原因）"
        }
        blinkCountdownItem.title = "下一次眨眼：\(countdown(deadline: snapshot.blinkDeadline, kind: .blink, snapshot: snapshot, now: now))"
        distanceCountdownItem.title = "下一次看远：\(countdown(deadline: snapshot.distanceDeadline, kind: .distance, snapshot: snapshot, now: now))"
        blinkToggleItem.title = "眨眼提醒（每\(intervalString(settings.blinkInterval))）"
        blinkToggleItem.state = settings.blinkEnabled ? .on : .off
        distanceToggleItem.title = "远眺提醒（每\(intervalString(settings.distanceInterval))）"
        distanceToggleItem.state = settings.distanceEnabled ? .on : .off
        skipItem.isHidden = snapshot.activeReminder == nil
    }

    private func countdown(deadline: Date?, kind: ReminderKind, snapshot: EngineSnapshot, now: Date) -> String {
        if let until = snapshot.pauseUntil { return "暂停至 \(timeString(until))" }
        if let active = snapshot.activeReminder, active.consumedKinds.contains(kind) {
            return "进行中（剩余 \(format(seconds: active.endsAt.timeIntervalSince(now)))）"
        }
        guard let deadline else { return "已关闭" }
        return format(seconds: deadline.timeIntervalSince(now))
    }

    private func format(seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.up)))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private func intervalString(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        if minutes >= 60, minutes.isMultiple(of: 60) {
            return "\(minutes / 60) 小时"
        }
        return "\(minutes) 分钟"
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func title(for choice: PauseChoice) -> String {
        switch choice {
        case .thirtyMinutes: return "暂停 30 分钟"
        case .oneHour: return "暂停 1 小时"
        case .tomorrowAtNine: return "暂停到明天 09:00"
        }
    }

    @objc private func pauseSelected(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let choice = PauseChoice(rawValue: raw) else { return }
        onPause(choice)
    }

    @objc private func settingsSelected() { onSettings() }
    @objc private func blinkToggleSelected() { onToggle(.blink) }
    @objc private func distanceToggleSelected() { onToggle(.distance) }
    @objc private func skipSelected() { onSkip() }
    @objc private func quitSelected() { onQuit() }
}
