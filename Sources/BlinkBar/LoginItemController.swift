@preconcurrency import ServiceManagement
import Foundation

private enum LoginItemError: LocalizedError {
    case appBundleRequired

    var errorDescription: String? {
        switch self {
        case .appBundleRequired:
            return "登录项只能从位于 /Applications 或 ~/Applications 的真实 BlinkBar.app 注册。请先完成打包并移动 App。"
        }
    }
}

enum LoginItemStatus: Equatable {
    case enabled
    case requiresApproval
    case notRegistered
    case notFound
    case unknown

    var description: String {
        switch self {
        case .enabled: return "已启用"
        case .requiresApproval: return "等待系统批准"
        case .notRegistered: return "未启用"
        case .notFound: return "当前不是已安装的 App"
        case .unknown: return "未知状态"
        }
    }

    var isEnabled: Bool { self == .enabled }
    var requiresApproval: Bool { self == .requiresApproval }
}

@MainActor
final class LoginItemController {
    var status: LoginItemStatus {
        switch SMAppService.mainApp.status {
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        case .notRegistered: return .notRegistered
        case .notFound: return .notFound
        @unknown default: return .unknown
        }
    }

    var isEnabled: Bool { status.isEnabled }
    var requiresApproval: Bool { status.requiresApproval }
    var statusDescription: String { status.description }

    func openSystemSettingsLoginItems() {
        SMAppService.openSystemSettingsLoginItems()
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            switch SMAppService.mainApp.status {
            case .enabled, .requiresApproval:
                return
            case .notRegistered:
                guard isInstalledApplication else { throw LoginItemError.appBundleRequired }
                try SMAppService.mainApp.register()
            case .notFound:
                throw LoginItemError.appBundleRequired
            @unknown default:
                throw LoginItemError.appBundleRequired
            }
        } else {
            switch SMAppService.mainApp.status {
            case .notRegistered, .notFound:
                return
            case .enabled, .requiresApproval:
                try SMAppService.mainApp.unregister()
            @unknown default:
                return
            }
        }
    }

    private var isInstalledApplication: Bool {
        let bundleURL = Bundle.main.bundleURL.standardizedFileURL
        guard bundleURL.pathExtension.caseInsensitiveCompare("app") == .orderedSame,
              FileManager.default.fileExists(atPath: bundleURL.path) else {
            return false
        }

        let homeApplications = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true).path
        let parent = bundleURL.deletingLastPathComponent().path
        return parent == "/Applications" || parent == homeApplications
    }
}
