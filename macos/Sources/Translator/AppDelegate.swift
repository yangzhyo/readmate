import AppKit
import ServiceManagement
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let eventTap = EventTap()
    private let panel = ExplanationPanel()
    private let triggerIcon = TriggerIcon()
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var explainTask: Task<Void, Never>?
    private var tapRetryTimer: Timer?
    private var enabled = true
    private var lastCapture: Capture?

    private static let didAttemptAutoLaunchKey = "didAttemptAutoLaunchRegistration"

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        setupStatusItem()
        registerLaunchAtLoginOnce()
        promptForAccessibilityIfNeeded()
        ClipboardWatcher.shared.start()

        eventTap.onSelectionGesture = { [weak self] point in
            guard let self, self.enabled else { return }
            self.triggerIcon.show(at: point)
        }
        eventTap.onMouseDown = { [weak self] point in
            guard let self else { return }
            if !self.triggerIcon.frameContains(point) { self.triggerIcon.hide() }
        }
        eventTap.onKeyDown = { [weak self] in self?.triggerIcon.hide() }
        eventTap.onEscape = { [weak self] in
            guard let self, self.panel.isVisible else { return false }
            self.cancelAndClose()
            return true
        }
        eventTap.shouldIgnorePoint = { [weak self] point in
            self?.ownWindowsContain(point) ?? false
        }
        triggerIcon.onClick = { [weak self] in self?.performCaptureAndExplain() }
        panel.onRetry = { [weak self] in self?.explainCurrent() }

        startTapOrRetry()
    }

    private func ownWindowsContain(_ point: NSPoint) -> Bool {
        NSApp.windows.contains { $0.isVisible && NSPointInRect(point, $0.frame) }
    }

    // MARK: - 触发链路

    @objc private func explainSelectionNow() {
        performCaptureAndExplain()
    }

    private func performCaptureAndExplain() {
        triggerIcon.hide()
        let mouse = NSEvent.mouseLocation
        guard let capture = SelectionCapture.capture() else {
            panel.showTransientHint("未取到选中文字", near: mouse)
            return
        }
        lastCapture = capture
        panel.show(near: capture.anchor ?? mouse)
        explainCurrent()
    }

    private func explainCurrent() {
        guard let capture = lastCapture else { return }
        explainTask?.cancel()
        panel.begin(selection: capture.selection)

        let apiKey = Settings.apiKey
        guard !apiKey.isEmpty else {
            panel.fail("未配置 API key——点菜单栏「译」→ 设置…")
            return
        }

        let model = Settings.model
        explainTask = Task { @MainActor [weak self] in
            do {
                let stream = GeminiClient.stream(
                    selection: capture.selection,
                    context: capture.context,
                    apiKey: apiKey,
                    model: model
                )
                for try await chunk in stream {
                    guard !Task.isCancelled else { return }
                    self?.panel.append(chunk)
                }
                guard !Task.isCancelled else { return }
                self?.panel.finish()
            } catch {
                guard !Task.isCancelled else { return }
                self?.panel.fail(error.localizedDescription)
            }
        }
    }

    private func cancelAndClose() {
        explainTask?.cancel()
        explainTask = nil
        panel.close()
    }

    // MARK: - 事件监听（辅助功能授权前会失败，定时重试）

    private func startTapOrRetry() {
        if eventTap.start() {
            tapRetryTimer?.invalidate()
            tapRetryTimer = nil
            return
        }
        guard tapRetryTimer == nil else { return }
        tapRetryTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.startTapOrRetry()
        }
    }

    private func promptForAccessibilityIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - 主菜单

    /// LSUIElement 应用不显示菜单栏，但 ⌘V/⌘C 等快捷键依赖主菜单的键位等价项分发——
    /// 不挂这个菜单，设置窗口的输入框就无法粘贴。
    private func setupMainMenu() {
        let mainMenu = NSMenu()
        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)

        let editMenu = NSMenu(title: "编辑")
        editItem.submenu = editMenu
        editMenu.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "重做", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "拷贝", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        NSApp.mainMenu = mainMenu
    }

    // MARK: - 菜单栏

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "译"
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let toggle = NSMenuItem(title: "启用划词图标", action: #selector(toggleEnabled), keyEquivalent: "")
        toggle.target = self
        toggle.state = enabled ? .on : .off
        menu.addItem(toggle)

        let explainNow = NSMenuItem(title: "解释当前选中", action: #selector(explainSelectionNow), keyEquivalent: "")
        explainNow.target = self
        menu.addItem(explainNow)

        if !AXIsProcessTrusted() {
            let warn = NSMenuItem(title: "⚠︎ 需要辅助功能权限", action: #selector(openAccessibilitySettings), keyEquivalent: "")
            warn.target = self
            menu.addItem(warn)
        }

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "设置…", action: #selector(openSettings), keyEquivalent: "")
        settings.target = self
        menu.addItem(settings)

        let launch = NSMenuItem(title: "开机自启", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launch.target = self
        launch.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(launch)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    @objc private func toggleEnabled() {
        enabled.toggle()
        if !enabled {
            triggerIcon.hide()
            cancelAndClose()
        }
    }

    @objc private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - 开机自启（决策：默认注册，可在菜单栏关）

    private func registerLaunchAtLoginOnce() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.didAttemptAutoLaunchKey) else { return }
        defaults.set(true, forKey: Self.didAttemptAutoLaunchKey)
        // 未打包成 .app 运行（swift run）时注册会失败，静默忽略
        try? SMAppService.mainApp.register()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("切换开机自启失败：\(error.localizedDescription)")
        }
    }

    // MARK: - 设置窗口

    @objc private func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 440, height: 160),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Translator 设置"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(onDone: { [weak self] in
                self?.settingsWindow?.close()
            }))
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
