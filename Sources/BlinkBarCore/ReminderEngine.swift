import Foundation

public struct ReminderEngine: Sendable {
    public private(set) var settings: SettingsSnapshot

    private var blinkDeadline: Date?
    private var distanceDeadline: Date?
    private var activeReminder: ActiveReminder?
    private var pauseUntilDate: Date?
    private var inactiveReasons: Set<InactiveReason>

    public init(settings: SettingsSnapshot, now: Date, pauseUntil: Date? = nil) {
        let normalized = settings.normalized()
        self.settings = normalized
        self.blinkDeadline = nil
        self.distanceDeadline = nil
        self.activeReminder = nil
        self.inactiveReasons = []
        if let pauseUntil, pauseUntil > now {
            self.pauseUntilDate = pauseUntil
        } else {
            self.pauseUntilDate = nil
            let deadlines = SchedulePolicy.resetDeadlines(settings: normalized, now: now)
            self.blinkDeadline = deadlines.blink
            self.distanceDeadline = deadlines.distance
        }
    }

    public func snapshot(now: Date) -> EngineSnapshot {
        EngineSnapshot(
            now: now,
            mode: currentMode,
            blinkDeadline: blinkDeadline,
            distanceDeadline: distanceDeadline,
            pauseUntil: pauseUntilDate,
            inactiveReasons: inactiveReasons
        )
    }

    public var currentMode: EngineMode {
        if let pauseUntilDate {
            return .paused(until: pauseUntilDate)
        }
        if !inactiveReasons.isEmpty {
            return .inactive(reasons: inactiveReasons)
        }
        if let activeReminder {
            return .showing(activeReminder)
        }
        return .running
    }

    public mutating func reset(now: Date) -> [ReminderEngineEvent] {
        var events: [ReminderEngineEvent] = []
        if activeReminder != nil {
            activeReminder = nil
            events.append(.hide)
        }
        guard pauseUntilDate == nil, inactiveReasons.isEmpty else {
            blinkDeadline = nil
            distanceDeadline = nil
            events.append(.scheduleChanged)
            return events
        }
        let deadlines = SchedulePolicy.resetDeadlines(settings: settings, now: now)
        blinkDeadline = deadlines.blink
        distanceDeadline = deadlines.distance
        events.append(.scheduleChanged)
        return events
    }

    public mutating func update(settings newSettings: SettingsSnapshot, now: Date) -> [ReminderEngineEvent] {
        let normalized = newSettings.normalized()
        let old = settings
        settings = normalized
        var events: [ReminderEngineEvent] = []

        let blinkScheduleChanged = old.blinkEnabled != normalized.blinkEnabled
            || (old.blinkEnabled && normalized.blinkEnabled && old.blinkInterval != normalized.blinkInterval)
        let distanceScheduleChanged = old.distanceEnabled != normalized.distanceEnabled
            || (old.distanceEnabled && normalized.distanceEnabled && old.distanceInterval != normalized.distanceInterval)

        if blinkScheduleChanged {
            blinkDeadline = normalized.blinkEnabled ? now.addingTimeInterval(normalized.blinkInterval) : nil
            if !normalized.blinkEnabled, activeReminder?.kind == .blink {
                activeReminder = nil
                events.append(.hide)
            }
        }

        if distanceScheduleChanged {
            distanceDeadline = normalized.distanceEnabled ? now.addingTimeInterval(normalized.distanceInterval) : nil
            if !normalized.distanceEnabled, activeReminder?.kind == .distance {
                activeReminder = nil
                if !events.contains(.hide) {
                    events.append(.hide)
                }
            }
        }

        // A setting change can hide an active reminder. Only after all such changes
        // have been applied can an enabled reminder safely be scheduled again.
        if activeReminder == nil, pauseUntilDate == nil, inactiveReasons.isEmpty {
            if normalized.blinkEnabled, blinkDeadline == nil {
                blinkDeadline = now.addingTimeInterval(normalized.blinkInterval)
            }
            if normalized.distanceEnabled, distanceDeadline == nil {
                distanceDeadline = now.addingTimeInterval(normalized.distanceInterval)
            }
        }

        if blinkScheduleChanged || distanceScheduleChanged {
            events.append(.scheduleChanged)
        }
        return events
    }

    public mutating func pause(until date: Date, now: Date) -> [ReminderEngineEvent] {
        guard date > now else {
            return tick(now: now)
        }
        var events: [ReminderEngineEvent] = []
        if activeReminder != nil {
            activeReminder = nil
            events.append(.hide)
        }
        pauseUntilDate = date
        blinkDeadline = nil
        distanceDeadline = nil
        events.append(.pauseChanged(date))
        events.append(.scheduleChanged)
        return events
    }

    public mutating func addInactive(_ reason: InactiveReason, now: Date) -> [ReminderEngineEvent] {
        guard inactiveReasons.insert(reason).inserted else { return [] }
        var events: [ReminderEngineEvent] = []
        if inactiveReasons.count == 1, activeReminder != nil {
            activeReminder = nil
            events.append(.hide)
        }
        return events
    }

    public mutating func removeInactive(_ reason: InactiveReason, now: Date) -> [ReminderEngineEvent] {
        guard inactiveReasons.remove(reason) != nil else { return [] }
        guard inactiveReasons.isEmpty, pauseUntilDate == nil else { return [] }
        let deadlines = SchedulePolicy.resetDeadlines(settings: settings, now: now)
        blinkDeadline = deadlines.blink
        distanceDeadline = deadlines.distance
        return [.scheduleChanged]
    }

    public mutating func skipCurrent(now: Date) -> [ReminderEngineEvent] {
        guard activeReminder != nil else { return [] }
        return finishCurrent(now: now)
    }

    public mutating func tick(now: Date) -> [ReminderEngineEvent] {
        var events: [ReminderEngineEvent] = []

        if let pauseUntilDate {
            guard now >= pauseUntilDate else { return events }
            self.pauseUntilDate = nil
            events.append(.pauseChanged(nil))
            if inactiveReasons.isEmpty {
                let deadlines = SchedulePolicy.resetDeadlines(settings: settings, now: now)
                blinkDeadline = deadlines.blink
                distanceDeadline = deadlines.distance
                events.append(.resumed)
                events.append(.scheduleChanged)
            } else {
                blinkDeadline = nil
                distanceDeadline = nil
            }
            return events
        }

        guard inactiveReasons.isEmpty else { return events }

        if let activeReminder {
            guard now >= activeReminder.endsAt else { return events }
            events.append(contentsOf: finishCurrent(now: now))
            return events
        }

        if shouldSuppressBlink(at: now) {
            blinkDeadline = settings.blinkEnabled ? now.addingTimeInterval(settings.blinkInterval) : nil
            events.append(.scheduleChanged)
            return events
        }

        guard let kind = dueKind(at: now) else { return events }
        let consumedKinds = consumedKinds(for: kind, at: now)
        let duration: TimeInterval
        let blinkCount: Int?
        switch kind {
        case .blink:
            duration = TimeInterval(settings.blinkDisplaySeconds)
            blinkCount = settings.blinkCount
        case .distance:
            duration = TimeInterval(settings.distanceDisplaySeconds)
            blinkCount = nil
        }
        let reminder = ActiveReminder(
            kind: kind,
            startedAt: now,
            endsAt: now.addingTimeInterval(duration),
            consumedKinds: consumedKinds,
            blinkCount: blinkCount
        )
        activeReminder = reminder
        if consumedKinds.contains(.blink) {
            blinkDeadline = nil
        }
        if consumedKinds.contains(.distance) {
            distanceDeadline = nil
        }
        events.append(.show(reminder))
        return events
    }

    private func dueKind(at now: Date) -> ReminderKind? {
        let blinkDue = blinkDeadline.map { $0 <= now } ?? false
        let distanceDue = distanceDeadline.map { $0 <= now } ?? false
        guard blinkDue || distanceDue else { return nil }

        if distanceDue {
            return .distance
        }
        return blinkDue ? .blink : .distance
    }

    private func shouldSuppressBlink(at now: Date) -> Bool {
        guard blinkDeadline.map({ $0 <= now }) ?? false,
              let distanceDeadline,
              distanceDeadline > now,
              distanceDeadline <= now.addingTimeInterval(SchedulePolicy.mergeWindow) else {
            return false
        }
        return true
    }

    private func consumedKinds(for kind: ReminderKind, at now: Date) -> Set<ReminderKind> {
        switch kind {
        case .blink:
            return [.blink]
        case .distance:
            var result: Set<ReminderKind> = [.distance]
            if let blinkDeadline, blinkDeadline <= now.addingTimeInterval(SchedulePolicy.mergeWindow) {
                result.insert(.blink)
            }
            return result
        }
    }

    private mutating func finishCurrent(now: Date) -> [ReminderEngineEvent] {
        guard let reminder = activeReminder else { return [] }
        activeReminder = nil
        for kind in reminder.consumedKinds {
            switch kind {
            case .blink:
                blinkDeadline = settings.blinkEnabled ? now.addingTimeInterval(settings.blinkInterval) : nil
            case .distance:
                distanceDeadline = settings.distanceEnabled ? now.addingTimeInterval(settings.distanceInterval) : nil
            }
        }
        return [.hide, .scheduleChanged]
    }
}
