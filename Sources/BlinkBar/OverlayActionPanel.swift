@preconcurrency import AppKit
import SwiftUI
import BlinkBarCore

@MainActor
final class OverlayActionPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 160, height: 56),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        ignoresMouseEvents = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func show(on screen: NSScreen, joinsFullScreen: Bool, onAction: @escaping () -> Void) {
        collectionBehavior = joinsFullScreen
            ? [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            : [.canJoinAllSpaces, .stationary, .ignoresCycle]
        let size = NSSize(width: 160, height: 56)
        setFrame(NSRect(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.midY - 210,
            width: size.width,
            height: size.height
        ), display: true)
        let content = OverlayActionPanelContent(onAction: { [weak self] in
            self?.orderOut(nil)
            onAction()
        })
        contentView = NSHostingView(rootView: content)
        orderFrontRegardless()
    }
}

@MainActor
private struct OverlayActionPanelContent: View {
    let onAction: () -> Void

    var body: some View {
        Button(action: onAction) {
            HStack(spacing: 8) {
                Image(systemName: "forward.end.fill")
                Text("跳过")
                    .font(.headline)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
