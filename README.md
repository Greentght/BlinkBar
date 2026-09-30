# BlinkBar

BlinkBar 是一个无网络、无第三方依赖的 macOS 菜单栏用眼提醒工具，使用 AppKit、SwiftUI 与 SwiftPM，最低支持 macOS 13。应用以 accessory 模式运行，不显示 Dock 图标。

本项目采用 [MIT License](LICENSE) 开源。

默认设置：眨眼每 10 分钟显示 5 秒、连续 5 次；看远每 30 分钟显示 20 秒；闲置 5 分钟后重新计时；全屏和所有显示器开启；声音关闭。若眨眼到期且看远将在 120 秒内到期，则只跳过该次眨眼，看远仍在原定期限出现；看远到期时会消费前后 120 秒内的眨眼。设置、暂停时间和剩余调度规则保存在 UserDefaults。

## 构建、测试与打包

```sh
cd /Users/lixinli/Workspace/BlinkBar
swift build
Scripts/test.sh
Scripts/package-app.sh
```

`Scripts/test.sh` 执行 `swift test --disable-sandbox`，并将 SwiftPM scratch、Clang module cache 和 Swift module cache 都放在项目的 `.build/` 下。脚本通过 `xcode-select -p` 推导 `Library/Developer/Frameworks`；仅当其中存在 `Testing.framework` 时，才向编译器和链接器添加对应的框架搜索路径及 rpath。

`Scripts/package-app.sh` 会使用项目 `.build/` 下的 scratch、cache、config、security 和 module cache，配合 `--disable-sandbox --manifest-cache local` 明确执行 `BlinkBar` release 构建；构建成功后才查询 binary path。随后生成 `dist/BlinkBar.app`、复制 `Resources/Info.plist`、执行 ad-hoc 签名，并用 `plutil` 和严格的 `codesign --verify --deep --strict` 验证。构建、打包、签名或验证任一步失败都会以非零状态退出；`codesign` 不可用也会失败。

从 Finder 双击 BlinkBar.app 会打开设置页，作为已经启动的明确反馈；应用已运行时再次双击会前置同一个设置页。登录项自动启动会保持静默，不弹出或激活设置页。

设置窗口左下角提供“退出 BlinkBar…”按钮；当菜单栏图标不可用时，可用它作为退出备用入口。

工具链必须匹配：Swift 编译器、MacOSX SDK 和（如使用）Xcode/Command Line Tools 应来自兼容版本。项目内缓存目录不能修复工具链版本不匹配；如果当前环境的 SwiftPM manifest sandbox 不可用，请使用与 `Scripts/test.sh` 相同的 `--disable-sandbox` 选项，并在修复工具链后再执行上面的 `swift build`、`Scripts/test.sh` 和 `Scripts/package-app.sh`。

打包完成后可将 `dist/BlinkBar.app` 移动到 `/Applications`，也可以移动到当前用户的 `~/Applications`，再从该位置启动。只有位于这两个目录中的真实 `.app` 才允许通过 `SMAppService.mainApp` 注册登录项；从源码、`.build` 或其他路径运行时，登录项会回滚并显示错误。登录项最终状态以系统服务状态为准；若 `SMAppService` 返回 `requiresApproval`，设置中的登录项区域会显示“等待系统批准”并提供打开系统设置批准的按钮。

## 人工验收

1. 启动后只有菜单栏图标，没有 Dock 图标；菜单显示眨眼和看远各自的倒计时，打开菜单时每秒更新，关闭后停止菜单刷新。
2. 将间隔调短后，眨眼显示中央半透明卡片；看远显示轻微暗幕、中央倒计时和每屏独立的跳过面板，点击任一面板都会结束全部看远提醒。
3. 打开/关闭全屏显示、所有显示器和设置中的各项开关，确认对应 deadline 或 overlay 立即取消；重新启用或修改 interval 后从当前时间重新计时。
4. 在多显示器、不同 Space、全屏窗口和热插拔显示器场景中触发提醒，确认覆盖层按设置重建；关闭所有显示器显示时只使用鼠标所在屏幕。
5. 验证暂停 30 分钟、1 小时、到次日 09:00；检查暂停持久化、完成/跳过后从结束时重排，以及夏令时日期仍为本地 09:00。
6. 验证闲置严格超过阈值、睡眠/唤醒、屏幕休眠/唤醒、锁屏/解锁的叠加 inactive reasons：所有原因清除前不重排，锁屏时 overlay 隐藏。
7. 将 App 移到 `/Applications` 后验证登录项成功/失败回滚；断开网络运行，并确认没有网络请求、Dock 图标或额外遥测。
