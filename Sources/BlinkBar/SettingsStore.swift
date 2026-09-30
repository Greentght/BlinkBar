import Foundation
import BlinkBarCore

@MainActor
final class SettingsStore {
    private let defaults: UserDefaults
    private let settingsKey = "BlinkBar.settings"
    private let pauseKey = "BlinkBar.pauseUntil"
    private(set) var settings: SettingsSnapshot
    private(set) var pauseUntil: Date?
    var onChange: ((SettingsSnapshot) -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: settingsKey), let value = try? JSONDecoder().decode(SettingsSnapshot.self, from: data) {
            settings = value.normalized()
        } else {
            settings = .default
        }
        pauseUntil = defaults.object(forKey: pauseKey) as? Date
    }

    func setSettings(_ value: SettingsSnapshot, notify: Bool = true) {
        settings = value.normalized()
        if let data = try? JSONEncoder().encode(settings) { defaults.set(data, forKey: settingsKey) }
        if notify { onChange?(settings) }
    }

    func setPauseUntil(_ date: Date?) {
        pauseUntil = date
        if let date { defaults.set(date, forKey: pauseKey) } else { defaults.removeObject(forKey: pauseKey) }
    }
}
