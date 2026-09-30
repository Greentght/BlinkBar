import Foundation

public enum SchedulePolicy {
    public static let mergeWindow: TimeInterval = 120

    public static func resetDeadlines(
        settings: SettingsSnapshot,
        now: Date
    ) -> (blink: Date?, distance: Date?) {
        let settings = settings.normalized()
        return (
            settings.blinkEnabled ? now.addingTimeInterval(settings.blinkInterval) : nil,
            settings.distanceEnabled ? now.addingTimeInterval(settings.distanceInterval) : nil
        )
    }

    public static func shouldMerge(
        blinkDeadline: Date?,
        distanceDeadline: Date?,
        now: Date,
        window: TimeInterval = mergeWindow
    ) -> Bool {
        guard blinkDeadline != nil || distanceDeadline != nil else { return false }
        let limit = now.addingTimeInterval(window)
        if let blinkDeadline, blinkDeadline <= limit,
           let distanceDeadline, distanceDeadline <= limit {
            return true
        }
        return false
    }

    public static func pauseUntil(
        choice: PauseChoice,
        now: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Date {
        switch choice {
        case .thirtyMinutes:
            return now.addingTimeInterval(30 * 60)
        case .oneHour:
            return now.addingTimeInterval(60 * 60)
        case .tomorrowAtNine:
            let startOfToday = calendar.startOfDay(for: now)
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now.addingTimeInterval(24 * 60 * 60)
            return calendar.date(
                bySettingHour: 9,
                minute: 0,
                second: 0,
                of: tomorrow,
                matchingPolicy: .nextTime,
                repeatedTimePolicy: .first,
                direction: .forward
            ) ?? tomorrow.addingTimeInterval(9 * 60 * 60)
        }
    }
}
