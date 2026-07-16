import AppKit

/// 全局键盘事件监听：⌥T 触发解释；解释卡可见时吞掉 Esc 用于关卡
/// （避免 Esc 漏到底下的应用——在 Claude Code 里那是打断 Agent 的键）。
/// Chrome 前台时放行 ⌥T，让位给浏览器插件。
final class EventTap {
    var onTrigger: (() -> Void)?
    /// 返回 true 表示 Esc 已被消费（解释卡正显示并被关闭）
    var onEscape: (() -> Bool)?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var hotkeyKeyCode: Int64 = 17
    private var hotkeyFlags: CGEventFlags = .maskAlternate
    private var doubleTapFlag: CGEventFlags? = .maskAlternate
    private var previousRelevantFlags: CGEventFlags = []
    private var lastLoneModifierDownTime: TimeInterval = 0

    private static let keyCodeEscape: Int64 = 53
    private static let relevantFlags: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]
    private static let doubleTapWindow: TimeInterval = 0.4
    private static let chromeBundleIDs: Set<String> = [
        "com.google.Chrome",
        "com.google.Chrome.beta",
        "com.google.Chrome.canary",
        "com.google.Chrome.dev",
    ]

    /// 应用用户自定义的触发快捷键（主线程调用；回调也跑在主 RunLoop，无并发问题）
    func setHotkey(keyCode: Int, nsModifierRawValue: UInt) {
        hotkeyKeyCode = Int64(keyCode)
        let ns = NSEvent.ModifierFlags(rawValue: nsModifierRawValue)
        var flags: CGEventFlags = []
        if ns.contains(.command) { flags.insert(.maskCommand) }
        if ns.contains(.control) { flags.insert(.maskControl) }
        if ns.contains(.option) { flags.insert(.maskAlternate) }
        if ns.contains(.shift) { flags.insert(.maskShift) }
        hotkeyFlags = flags
    }

    /// 设置连按两下触发所用的修饰键；传 0 表示关闭
    func setDoubleTap(nsModifierRawValue: UInt) {
        let ns = NSEvent.ModifierFlags(rawValue: nsModifierRawValue)
        if ns.contains(.command) { doubleTapFlag = .maskCommand }
        else if ns.contains(.control) { doubleTapFlag = .maskControl }
        else if ns.contains(.option) { doubleTapFlag = .maskAlternate }
        else if ns.contains(.shift) { doubleTapFlag = .maskShift }
        else { doubleTapFlag = nil }
    }

    /// 需要辅助功能权限；未授权时创建失败，返回 false
    func start() -> Bool {
        guard tap == nil else { return true }
        let mask = CGEventMask((1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue))
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            let eventTap = Unmanaged<EventTap>.fromOpaque(refcon!).takeUnretainedValue()
            return eventTap.handle(type: type, event: event)
        }
        guard let created = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        tap = created
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, created, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: created, enable: true)
        return true
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        // 双击修饰键：两次「单独按下该键」间隔在窗口内，且中间没有敲过别的键。
        // 裸修饰键的点按对底下的应用是无操作，无需吞事件，也不与终端的 Meta 用法冲突。
        if type == .flagsChanged {
            let mods = event.flags.intersection(Self.relevantFlags)
            defer { previousRelevantFlags = mods }
            if let doubleTapFlag, mods == doubleTapFlag, previousRelevantFlags.isEmpty {
                let now = ProcessInfo.processInfo.systemUptime
                if now - lastLoneModifierDownTime <= Self.doubleTapWindow {
                    lastLoneModifierDownTime = 0
                    DispatchQueue.main.async { [weak self] in self?.onTrigger?() }
                } else {
                    lastLoneModifierDownTime = now
                }
            } else if !mods.isEmpty, mods != doubleTapFlag {
                lastLoneModifierDownTime = 0
            }
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        lastLoneModifierDownTime = 0 // 敲了实键就不算连按修饰键

        if keyCode == Self.keyCodeEscape {
            if let onEscape, onEscape() { return nil }
            return Unmanaged.passUnretained(event)
        }

        if keyCode == hotkeyKeyCode,
           event.flags.intersection(Self.relevantFlags) == hotkeyFlags {
            if let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
               Self.chromeBundleIDs.contains(frontmost) {
                return Unmanaged.passUnretained(event)
            }
            // 回调里不做重活（取词可能阻塞数百毫秒），异步派发
            DispatchQueue.main.async { [weak self] in self?.onTrigger?() }
            return nil
        }

        return Unmanaged.passUnretained(event)
    }
}
