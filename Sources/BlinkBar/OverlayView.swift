import SwiftUI
import BlinkBarCore

@MainActor
struct OverlayView: View {
    let reminder: ActiveReminder
    let remaining: TimeInterval

    var body: some View {
        ZStack {
            if reminder.kind == .blink {
                Color.clear
                VStack(spacing: 14) {
                    Image(systemName: "eye")
                        .font(.system(size: 52, weight: .medium))
                    Text("眨眨眼")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                    Text("轻轻闭眼，放松眼部")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.86))
                    if let count = reminder.blinkCount {
                        Text("慢慢眨眼 \(count) 次")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.76))
                    }
                    countdown
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 46)
                .padding(.vertical, 34)
                .background(.black.opacity(0.68), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            } else {
                Color.black.opacity(0.28)
                VStack(spacing: 16) {
                    Image(systemName: "binoculars")
                        .font(.system(size: 52, weight: .medium))
                    Text("看远一点")
                        .font(.system(size: 38, weight: .semibold, design: .rounded))
                    Text("看看 6 米以外的地方")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.9))
                    countdown
                }
                .foregroundStyle(.white)
            }
        }
        .ignoresSafeArea()
    }

    private var countdown: some View {
        Text("\(Int(remaining.rounded(.up))) 秒")
            .font(.system(size: 24, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.78))
    }
}
