import Foundation

public enum ReminderKind: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case blink
    case distance
}

public enum InactiveReason: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case idle
    case sleep
    case screensSleep
    case locked
}

public enum PauseChoice: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case thirtyMinutes
    case oneHour
    case tomorrowAtNine
}

public struct ActiveReminder: Equatable, Sendable {
    public let kind: ReminderKind
    public let startedAt: Date
    public let endsAt: Date
    public let consumedKinds: Set<ReminderKind>
    public let blinkCount: Int?

    public init(
        kind: ReminderKind,
        startedAt: Date,
        endsAt: Date,
        consumedKinds: Set<ReminderKind>,
        blinkCount: Int?
    ) {
        self.kind = kind
        self.startedAt = startedAt
        self.endsAt = endsAt
        self.consumedKinds = consumedKinds
        self.blinkCount = blinkCount
    }

    public var duration: TimeInterval {
        max(0, endsAt.timeIntervalSince(startedAt))
    }
}

public enum EngineMode: Equatable, Sendable {
    case running
    case showing(ActiveReminder)
    case paused(until: Date)
    case inactive(reasons: Set<InactiveReason>)
}

public struct EngineSnapshot: Equatable, Sendable {
    public let now: Date
    public let mode: EngineMode
    public let blinkDeadline: Date?
    public let distanceDeadline: Date?
    public let pauseUntil: Date?
    public let inactiveReasons: Set<InactiveReason>

    public init(
        now: Date,
        mode: EngineMode,
        blinkDeadline: Date?,
        distanceDeadline: Date?,
        pauseUntil: Date?,
        inactiveReasons: Set<InactiveReason>
    ) {
        self.now = now
        self.mode = mode
        self.blinkDeadline = blinkDeadline
        self.distanceDeadline = distanceDeadline
        self.pauseUntil = pauseUntil
        self.inactiveReasons = inactiveReasons
    }

    public var activeReminder: ActiveReminder? {
        guard case let .showing(reminder) = mode else { return nil }
        return reminder
    }
}

public enum ReminderEngineEvent: Equatable, Sendable {
    case show(ActiveReminder)
    case hide
    case scheduleChanged
    case pauseChanged(Date?)
    case resumed
}
