@preconcurrency import AppKit
@preconcurrency import CoreGraphics

@MainActor
final class ActivityMonitor {
    private var enabled: Bool
    private var threshold: TimeInterval
    private var isInactive = false
    private var timer: Timer?
    private let onInactiveChanged: (Bool) -> Void

    init(enabled: Bool, threshold: TimeInterval, onInactiveChanged: @escaping (Bool) -> Void) {
        self.enabled = enabled
        self.threshold = threshold
        self.onInactiveChanged = onInactiveChanged
    }

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkIdle()
            }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func update(enabled: Bool, threshold value: TimeInterval) {
        self.enabled = enabled
        threshold = max(60, value)
        if !enabled, isInactive {
            isInactive = false
            onInactiveChanged(false)
        }
    }

    private func checkIdle() {
        guard enabled else { return }
        let idleSeconds = [
            CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved),
            CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown),
            CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .leftMouseDown),
            CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .rightMouseDown),
            CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .scrollWheel)
        ].min() ?? 0
        guard idleSeconds > threshold else {
            if isInactive {
                isInactive = false
                onInactiveChanged(false)
            }
            return
        }
        guard !isInactive else { return }
        isInactive = true
        onInactiveChanged(true)
    }
}
