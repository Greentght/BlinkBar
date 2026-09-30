import Foundation
import Testing
@testable import BlinkBarCore

@Suite
struct SchedulePolicyTests {
    @Test
    func resetDeadlinesHonorsDisabledItems() {
        let now = Date(timeIntervalSinceReferenceDate: 100)
        let settings = SettingsSnapshot(blinkEnabled: false, distanceInterval: 1000)
        let deadlines = SchedulePolicy.resetDeadlines(settings: settings, now: now)

        #expect(deadlines.blink == nil)
        #expect(deadlines.distance == now.addingTimeInterval(1000))
    }

    @Test
    func mergeWindowIsInclusive() {
        let now = Date(timeIntervalSinceReferenceDate: 0)
        #expect(SchedulePolicy.shouldMerge(
            blinkDeadline: now,
            distanceDeadline: now.addingTimeInterval(120),
            now: now
        ))
        #expect(!SchedulePolicy.shouldMerge(
            blinkDeadline: now,
            distanceDeadline: now.addingTimeInterval(121),
            now: now
        ))
    }

    @Test
    func tomorrowAtNineAcrossDSTSpringForward() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let now = calendar.date(from: DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 3, day: 7, hour: 12))!
        let tomorrow = SchedulePolicy.pauseUntil(choice: .tomorrowAtNine, now: now, calendar: calendar)
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: tomorrow)

        #expect(components.year == 2026)
        #expect(components.month == 3)
        #expect(components.day == 8)
        #expect(components.hour == 9)
    }
}
