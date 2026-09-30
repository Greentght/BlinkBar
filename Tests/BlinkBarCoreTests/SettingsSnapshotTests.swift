import Testing
@testable import BlinkBarCore

@Suite
struct SettingsSnapshotTests {
    @Test
    func defaultsMatchProductDefaults() {
        let settings = SettingsSnapshot.default
        #expect(settings.blinkEnabled)
        #expect(settings.blinkInterval == 600)
        #expect(settings.blinkDisplaySeconds == 5)
        #expect(settings.blinkCount == 5)
        #expect(settings.distanceEnabled)
        #expect(settings.distanceInterval == 1800)
        #expect(settings.distanceDisplaySeconds == 20)
        #expect(settings.idleResetEnabled)
        #expect(settings.idleThreshold == 300)
        #expect(settings.fullScreenEnabled)
        #expect(settings.allDisplays)
        #expect(!settings.soundEnabled)
        #expect(settings.launchAtLogin)
    }

    @Test
    func normalizationKeepsUserInputInSafeBounds() {
        let settings = SettingsSnapshot(
            blinkInterval: 1,
            blinkDisplaySeconds: 100,
            blinkCount: 0,
            distanceInterval: 1,
            distanceDisplaySeconds: 1,
            idleThreshold: 1
        ).normalized()

        #expect(settings.blinkInterval == 60)
        #expect(settings.blinkDisplaySeconds == 30)
        #expect(settings.blinkCount == 1)
        #expect(settings.distanceInterval == 300)
        #expect(settings.distanceDisplaySeconds == 5)
        #expect(settings.idleThreshold == 60)
    }
}
