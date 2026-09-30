import SwiftUI
import BlinkBarCore

@MainActor
struct SettingsView: View {
    @State private var draft: SettingsSnapshot
    private let loginItemStatus: LoginItemStatus
    private let onOpenLoginItems: () -> Void
    private let onSave: (SettingsSnapshot) -> Void
    private let onCancel: () -> Void
    private let onQuit: () -> Void
    private let onClose: () -> Void
    @State private var isQuitAlertPresented = false

    init(
        settings: SettingsSnapshot,
        loginItemStatus: LoginItemStatus,
        onOpenLoginItems: @escaping () -> Void,
        onSave: @escaping (SettingsSnapshot) -> Void,
        onCancel: @escaping () -> Void = {},
        onQuit: @escaping () -> Void = {},
        onClose: @escaping () -> Void = {}
    ) {
        _draft = State(initialValue: settings)
        self.loginItemStatus = loginItemStatus
        self.onOpenLoginItems = onOpenLoginItems
        self.onSave = onSave
        self.onCancel = onCancel
        self.onQuit = onQuit
        self.onClose = onClose
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Form {
                Section("提醒") {
                    Toggle("启用眨眼提醒", isOn: binding(\.blinkEnabled))
                        .help("按间隔提醒闭眼放松")
                    Stepper(value: binding(\.blinkInterval), in: 60...7200, step: 60) {
                        Text("眨眼间隔：\(minutes(draft.blinkInterval)) 分钟")
                    }
                    .disabled(!draft.blinkEnabled)
                    Stepper(value: binding(\.blinkDisplaySeconds), in: 1...30) {
                        Text("眨眼显示：\(draft.blinkDisplaySeconds) 秒")
                    }
                    .disabled(!draft.blinkEnabled)
                    Stepper(value: binding(\.blinkCount), in: 1...20) {
                        Text("眨眼次数：\(draft.blinkCount) 次")
                    }
                    .disabled(!draft.blinkEnabled)
                    Toggle("启用看远提醒", isOn: binding(\.distanceEnabled))
                    Stepper(value: binding(\.distanceInterval), in: 300...14400, step: 300) {
                        Text("看远间隔：\(minutes(draft.distanceInterval)) 分钟")
                    }
                    .disabled(!draft.distanceEnabled)
                    Stepper(value: binding(\.distanceDisplaySeconds), in: 5...120, step: 5) {
                        Text("看远持续：\(draft.distanceDisplaySeconds) 秒")
                    }
                    .disabled(!draft.distanceEnabled)
                }
                Section("显示与行为") {
                    Toggle("全屏显示", isOn: binding(\.fullScreenEnabled))
                    Toggle("所有显示器显示", isOn: binding(\.allDisplays))
                    Toggle("闲置后重新计时", isOn: binding(\.idleResetEnabled))
                    Stepper(value: binding(\.idleThreshold), in: 60...7200, step: 60) {
                        Text("闲置阈值：\(minutes(draft.idleThreshold)) 分钟")
                    }
                    .disabled(!draft.idleResetEnabled)
                    Toggle("提醒声音", isOn: binding(\.soundEnabled))
                    Toggle("登录时自动启动", isOn: binding(\.launchAtLogin))
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("系统状态：\(loginItemStatus.description)")
                            Spacer()
                            if loginItemStatus.requiresApproval {
                                Button("打开系统设置…", action: onOpenLoginItems)
                            }
                        }
                        Text(loginItemExplanation)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            HStack {
                Button("退出 BlinkBar…", role: .destructive) {
                    isQuitAlertPresented = true
                }
                Spacer()
                Button("取消") { onCancel(); onClose() }
                Button("保存") { onSave(draft.normalized()); onClose() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460, height: 520)
        .alert("退出 BlinkBar？", isPresented: $isQuitAlertPresented) {
            Button("取消", role: .cancel) {}
            Button("退出 BlinkBar", role: .destructive, action: onQuit)
        } message: {
            Text("退出会停止所有提醒，并丢弃任何尚未保存的设置更改。")
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<SettingsSnapshot, Value>) -> Binding<Value> {
        Binding(get: { draft[keyPath: keyPath] }, set: { draft[keyPath: keyPath] = $0 })
    }

    private func minutes(_ seconds: TimeInterval) -> Int { Int((seconds / 60).rounded()) }

    private var loginItemExplanation: String {
        if draft.launchAtLogin {
            switch loginItemStatus {
            case .enabled:
                return "已请求登录时自动启动，系统已启用。"
            case .requiresApproval:
                return "这是启动偏好请求，仍待系统批准；开关开启不代表系统已经批准。"
            case .notRegistered:
                return "已请求登录时自动启动，保存后将向系统注册。"
            case .notFound:
                return "已请求登录时自动启动，但当前不是已安装的 App，无法注册。"
            case .unknown:
                return "已请求登录时自动启动，但系统尚未返回可确认的状态。"
            }
        }

        switch loginItemStatus {
        case .enabled:
            return "启动偏好已关闭，但系统当前仍显示已启用；保存后将取消注册。"
        case .requiresApproval:
            return "启动偏好已关闭；系统当前仍显示等待批准，保存后将取消注册。"
        case .notRegistered:
            return "启动偏好已关闭，系统未启用。"
        case .notFound:
            return "启动偏好已关闭；当前不是已安装的 App。"
        case .unknown:
            return "启动偏好已关闭，但系统尚未返回可确认的状态。"
        }
    }
}
