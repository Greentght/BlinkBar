import Foundation
import Testing
@testable import BlinkBarCore

@Suite
struct ReminderEngineTests {
    private let start = Date(timeIntervalSinceReferenceDate: 0)

    @Test
    func initialDeadlinesUseEnabledIntervals() {
        let settings = SettingsSnapshot(blinkInterval: 600, distanceInterval: 1800)
        let engine = ReminderEngine(settings: settings, now: start)
        let snapshot = engine.snapshot(now: start)

        #expect(snapshot.blinkDeadline == start.addingTimeInterval(600))
        #expect(snapshot.distanceDeadline == start.addingTimeInterval(1800))
        #expect(snapshot.mode == .running)
    }

    @Test
    func blinkCompletionReschedulesFromActualFinish() {
        let settings = SettingsSnapshot(blinkInterval: 600, blinkDisplaySeconds: 5, distanceInterval: 1800)
        var engine = ReminderEngine(settings: settings, now: start)

        let showEvents = engine.tick(now: start.addingTimeInterval(600))
        guard case let .show(reminder) = showEvents.first else {
            Issue.record("expected blink show")
            return
        }
        #expect(reminder.kind == .blink)

        _ = engine.tick(now: start.addingTimeInterval(603))
        let finishEvents = engine.tick(now: start.addingTimeInterval(606))
        #expect(finishEvents.contains(.hide))
        #expect(engine.snapshot(now: start.addingTimeInterval(606)).blinkDeadline == start.addingTimeInterval(1206))
    }

    @Test
    func singleDistanceReminder() {
        let settings = SettingsSnapshot(blinkEnabled: false, distanceInterval: 1800)
        var engine = ReminderEngine(settings: settings, now: start)

        let events = engine.tick(now: start.addingTimeInterval(1800))
        guard case let .show(reminder) = events.first else {
            Issue.record("expected distance show")
            return
        }
        #expect(reminder.kind == .distance)
        #expect(reminder.consumedKinds == [.distance])
    }

    @Test
    func blinkDue119SecondsBeforeDistanceSuppressesBlink() {
        assertBlinkSuppressed(distanceInterval: 719)
    }

    @Test
    func blinkDue120SecondsBeforeDistanceSuppressesBlink() {
        assertBlinkSuppressed(distanceInterval: 720)
    }

    @Test
    func blinkDue121SecondsBeforeDistanceDoesNotMerge() {
        let settings = SettingsSnapshot(blinkInterval: 600, distanceInterval: 721)
        var engine = ReminderEngine(settings: settings, now: start)
        let events = engine.tick(now: start.addingTimeInterval(600))

        guard case let .show(reminder) = events.first else {
            Issue.record("expected blink show")
            return
        }
        #expect(reminder.kind == .blink)
        #expect(reminder.consumedKinds == [.blink])
        #expect(engine.snapshot(now: start.addingTimeInterval(600)).distanceDeadline == start.addingTimeInterval(721))
    }

    @Test
    func distanceDue119SecondsBeforeBlinkConsumesBlink() {
        assertDistanceConsumesBlink(blinkInterval: 719)
    }

    @Test
    func distanceDue120SecondsBeforeBlinkConsumesBlink() {
        assertDistanceConsumesBlink(blinkInterval: 720)
    }

    @Test
    func distanceDue121SecondsBeforeBlinkDoesNotMerge() {
        let settings = SettingsSnapshot(blinkInterval: 721, distanceInterval: 600)
        var engine = ReminderEngine(settings: settings, now: start)
        let events = engine.tick(now: start.addingTimeInterval(600))

        guard case let .show(reminder) = events.first else {
            Issue.record("expected distance show")
            return
        }
        #expect(reminder.kind == .distance)
        #expect(reminder.consumedKinds == [.distance])
    }

    @Test
    func twoOverdueRemindersAreConsumedByDistance() {
        let settings = SettingsSnapshot(blinkInterval: 600, distanceInterval: 900)
        var engine = ReminderEngine(settings: settings, now: start)
        let events = engine.tick(now: start.addingTimeInterval(1800))

        guard case let .show(reminder) = events.first else {
            Issue.record("expected distance show")
            return
        }
        #expect(reminder.kind == .distance)
        #expect(reminder.consumedKinds == [.blink, .distance])
    }

    @Test
    func showingReminderCannotBeDispatchedTwice() {
        let settings = SettingsSnapshot(blinkInterval: 600, blinkDisplaySeconds: 5, distanceEnabled: false)
        var engine = ReminderEngine(settings: settings, now: start)
        _ = engine.tick(now: start.addingTimeInterval(600))

        #expect(engine.tick(now: start.addingTimeInterval(601)).isEmpty)
        #expect(engine.tick(now: start.addingTimeInterval(604)).isEmpty)
        let finish = engine.tick(now: start.addingTimeInterval(605))
        #expect(finish.filter { if case .show = $0 { return true }; return false }.count == 0)
    }

    @Test
    func pauseThirtyMinutesResetsAfterPause() {
        let settings = SettingsSnapshot(blinkInterval: 600, distanceEnabled: false)
        var engine = ReminderEngine(settings: settings, now: start)
        let until = SchedulePolicy.pauseUntil(choice: .thirtyMinutes, now: start)
        _ = engine.pause(until: until, now: start)

        #expect(engine.snapshot(now: start).mode == .paused(until: until))
        #expect(engine.tick(now: until.addingTimeInterval(-1)).isEmpty)

        let resumed = engine.tick(now: until)
        #expect(resumed.contains(.resumed))
        #expect(engine.snapshot(now: until).blinkDeadline == until.addingTimeInterval(600))
    }

    @Test
    func pauseOneHourUsesExactDuration() {
        let until = SchedulePolicy.pauseUntil(choice: .oneHour, now: start)
        #expect(until == start.addingTimeInterval(3600))
    }

    @Test
    func tomorrowAtNineUsesCalendarAndDSTSafeDate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let now = calendar.date(from: DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 3, day: 7, hour: 18))!
        let pause = SchedulePolicy.pauseUntil(choice: .tomorrowAtNine, now: now, calendar: calendar)
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: pause)

        #expect(components.year == 2026)
        #expect(components.month == 3)
        #expect(components.day == 8)
        #expect(components.hour == 9)
        #expect(components.minute == 0)
    }

    @Test
    func idleReasonRequiresExplicitRecoveryBeforeReset() {
        let settings = SettingsSnapshot(blinkInterval: 600, distanceEnabled: false)
        var engine = ReminderEngine(settings: settings, now: start)
        _ = engine.addInactive(.idle, now: start.addingTimeInterval(301))

        #expect(engine.snapshot(now: start.addingTimeInterval(301)).mode == .inactive(reasons: [.idle]))
        #expect(engine.tick(now: start.addingTimeInterval(1000)).isEmpty)

        _ = engine.removeInactive(.idle, now: start.addingTimeInterval(1001))
        #expect(engine.snapshot(now: start.addingTimeInterval(1001)).blinkDeadline == start.addingTimeInterval(1601))
    }

    @Test
    func inactiveReasonsAreNestedAndDoNotResetEarly() {
        let settings = SettingsSnapshot(blinkInterval: 600, distanceEnabled: false)
        var engine = ReminderEngine(settings: settings, now: start)
        _ = engine.addInactive(.sleep, now: start)
        _ = engine.addInactive(.locked, now: start)
        _ = engine.removeInactive(.sleep, now: start.addingTimeInterval(100))

        #expect(engine.snapshot(now: start.addingTimeInterval(100)).inactiveReasons == [.locked])
        #expect(engine.snapshot(now: start.addingTimeInterval(100)).blinkDeadline == start.addingTimeInterval(600))

        _ = engine.removeInactive(.locked, now: start.addingTimeInterval(200))
        #expect(engine.snapshot(now: start.addingTimeInterval(200)).blinkDeadline == start.addingTimeInterval(800))
    }

    @Test
    func disablingAndReenablingReminderChangesDeadline() {
        var settings = SettingsSnapshot(blinkInterval: 600, distanceEnabled: false)
        var engine = ReminderEngine(settings: settings, now: start)
        settings.blinkEnabled = false
        _ = engine.update(settings: settings, now: start.addingTimeInterval(100))
        #expect(engine.snapshot(now: start.addingTimeInterval(100)).blinkDeadline == nil)

        settings.blinkEnabled = true
        _ = engine.update(settings: settings, now: start.addingTimeInterval(200))
        #expect(engine.snapshot(now: start.addingTimeInterval(200)).blinkDeadline == start.addingTimeInterval(800))
    }

    @Test
    func disablingBlinkDoesNotHideDistanceThatConsumedBlink() {
        var settings = SettingsSnapshot(blinkInterval: 600, distanceInterval: 600)
        var engine = ReminderEngine(settings: settings, now: start)
        let events = engine.tick(now: start.addingTimeInterval(600))

        guard case let .show(reminder) = events.first else {
            Issue.record("expected distance show")
            return
        }
        #expect(reminder.kind == .distance)
        #expect(reminder.consumedKinds == [.blink, .distance])

        settings.blinkEnabled = false
        let updateEvents = engine.update(settings: settings, now: start.addingTimeInterval(601))
        #expect(!updateEvents.contains(.hide))
        #expect(engine.snapshot(now: start.addingTimeInterval(601)).activeReminder?.kind == .distance)
    }

    @Test
    func disablingShowingDistanceReschedulesEnabledBlinkFromChangeTime() {
        var settings = SettingsSnapshot(blinkInterval: 600, distanceInterval: 600)
        var engine = ReminderEngine(settings: settings, now: start)
        _ = engine.tick(now: start.addingTimeInterval(600))

        settings.distanceEnabled = false
        let changeTime = start.addingTimeInterval(601)
        let updateEvents = engine.update(settings: settings, now: changeTime)
        #expect(updateEvents.contains(.hide))

        let snapshot = engine.snapshot(now: changeTime)
        #expect(snapshot.activeReminder == nil)
        #expect(snapshot.distanceDeadline == nil)
        #expect(snapshot.blinkDeadline == changeTime.addingTimeInterval(settings.blinkInterval))

        let blinkEvents = engine.tick(now: changeTime.addingTimeInterval(settings.blinkInterval))
        guard case let .show(reminder) = blinkEvents.first else {
            Issue.record("expected blink show at the rescheduled deadline")
            return
        }
        #expect(reminder.kind == .blink)
    }

    @Test
    func changingIntervalStartsNewIntervalFromChangeTime() {
        var settings = SettingsSnapshot(blinkInterval: 600, distanceEnabled: false)
        var engine = ReminderEngine(settings: settings, now: start)
        settings.blinkInterval = 900
        _ = engine.update(settings: settings, now: start.addingTimeInterval(100))

        #expect(engine.snapshot(now: start.addingTimeInterval(100)).blinkDeadline == start.addingTimeInterval(1000))
    }

    private func assertBlinkSuppressed(distanceInterval: TimeInterval) {
        let settings = SettingsSnapshot(blinkInterval: 600, distanceInterval: distanceInterval)
        var engine = ReminderEngine(settings: settings, now: start)
        let events = engine.tick(now: start.addingTimeInterval(600))

        #expect(events == [.scheduleChanged])
        #expect(engine.snapshot(now: start.addingTimeInterval(600)).mode == .running)
        #expect(engine.snapshot(now: start.addingTimeInterval(600)).blinkDeadline == start.addingTimeInterval(1200))
        #expect(engine.snapshot(now: start.addingTimeInterval(600)).distanceDeadline == start.addingTimeInterval(distanceInterval))

        let distanceEvents = engine.tick(now: start.addingTimeInterval(distanceInterval))
        guard case let .show(reminder) = distanceEvents.first else {
            Issue.record("expected distance show at its unchanged deadline")
            return
        }
        #expect(reminder.kind == .distance)
    }

    private func assertDistanceConsumesBlink(blinkInterval: TimeInterval) {
        let settings = SettingsSnapshot(blinkInterval: blinkInterval, distanceInterval: 600)
        var engine = ReminderEngine(settings: settings, now: start)
        let events = engine.tick(now: start.addingTimeInterval(600))

        guard case let .show(reminder) = events.first else {
            Issue.record("expected distance show")
            return
        }
        #expect(reminder.kind == .distance)
        #expect(reminder.consumedKinds == [.blink, .distance])
    }
}
