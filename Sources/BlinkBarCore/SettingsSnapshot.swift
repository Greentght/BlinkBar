import Foundation

public struct SettingsSnapshot: Codable, Equatable, Sendable {
    public var blinkEnabled: Bool
    public var blinkInterval: TimeInterval
    public var blinkDisplaySeconds: Int
    public var blinkCount: Int

    public var distanceEnabled: Bool
    public var distanceInterval: TimeInterval
    public var distanceDisplaySeconds: Int

    public var idleResetEnabled: Bool
    public var idleThreshold: TimeInterval

    public var fullScreenEnabled: Bool
    public var allDisplays: Bool
    public var soundEnabled: Bool
    public var launchAtLogin: Bool

    public init(
        blinkEnabled: Bool = true,
        blinkInterval: TimeInterval = 10 * 60,
        blinkDisplaySeconds: Int = 5,
        blinkCount: Int = 5,
        distanceEnabled: Bool = true,
        distanceInterval: TimeInterval = 30 * 60,
        distanceDisplaySeconds: Int = 20,
        idleResetEnabled: Bool = true,
        idleThreshold: TimeInterval = 5 * 60,
        fullScreenEnabled: Bool = true,
        allDisplays: Bool = true,
        soundEnabled: Bool = false,
        launchAtLogin: Bool = true
    ) {
        self.blinkEnabled = blinkEnabled
        self.blinkInterval = blinkInterval
        self.blinkDisplaySeconds = blinkDisplaySeconds
        self.blinkCount = blinkCount
        self.distanceEnabled = distanceEnabled
        self.distanceInterval = distanceInterval
        self.distanceDisplaySeconds = distanceDisplaySeconds
        self.idleResetEnabled = idleResetEnabled
        self.idleThreshold = idleThreshold
        self.fullScreenEnabled = fullScreenEnabled
        self.allDisplays = allDisplays
        self.soundEnabled = soundEnabled
        self.launchAtLogin = launchAtLogin
    }

    public static let `default` = SettingsSnapshot()

    public func normalized() -> SettingsSnapshot {
        var value = self
        value.blinkInterval = min(max(value.blinkInterval, 60), 2 * 60 * 60)
        value.blinkDisplaySeconds = min(max(value.blinkDisplaySeconds, 1), 30)
        value.blinkCount = min(max(value.blinkCount, 1), 20)
        value.distanceInterval = min(max(value.distanceInterval, 5 * 60), 4 * 60 * 60)
        value.distanceDisplaySeconds = min(max(value.distanceDisplaySeconds, 5), 120)
        value.idleThreshold = min(max(value.idleThreshold, 60), 2 * 60 * 60)
        return value
    }

    private enum CodingKeys: String, CodingKey {
        case blinkEnabled
        case blinkInterval
        case blinkDisplaySeconds
        case blinkCount
        case distanceEnabled
        case distanceInterval
        case distanceDisplaySeconds
        case idleResetEnabled
        case idleThreshold
        case fullScreenEnabled
        case allDisplays
        case soundEnabled
        case launchAtLogin
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            blinkEnabled: try container.decodeIfPresent(Bool.self, forKey: .blinkEnabled) ?? true,
            blinkInterval: try container.decodeIfPresent(TimeInterval.self, forKey: .blinkInterval) ?? 10 * 60,
            blinkDisplaySeconds: try container.decodeIfPresent(Int.self, forKey: .blinkDisplaySeconds) ?? 5,
            blinkCount: try container.decodeIfPresent(Int.self, forKey: .blinkCount) ?? 5,
            distanceEnabled: try container.decodeIfPresent(Bool.self, forKey: .distanceEnabled) ?? true,
            distanceInterval: try container.decodeIfPresent(TimeInterval.self, forKey: .distanceInterval) ?? 30 * 60,
            distanceDisplaySeconds: try container.decodeIfPresent(Int.self, forKey: .distanceDisplaySeconds) ?? 20,
            idleResetEnabled: try container.decodeIfPresent(Bool.self, forKey: .idleResetEnabled) ?? true,
            idleThreshold: try container.decodeIfPresent(TimeInterval.self, forKey: .idleThreshold) ?? 5 * 60,
            fullScreenEnabled: try container.decodeIfPresent(Bool.self, forKey: .fullScreenEnabled) ?? true,
            allDisplays: try container.decodeIfPresent(Bool.self, forKey: .allDisplays) ?? true,
            soundEnabled: try container.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? false,
            launchAtLogin: try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? true
        )
    }
}
