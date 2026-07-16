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

    private static let keyCodeT: Int64 = 17
    private static let keyCodeEscape: Int64 = 53
    private static let chromeBundleIDs: Set<String> = [
        "com.google.Chrome",
        "com.google.Chrome.beta",
        "com.google.Chrome.canary",
        "com.google.Chrome.dev",
    ]

    /// 需要辅助功能权限；未授权时创建失败，返回 false
    func start() -> Bool {
        guard tap == nil else { return true }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
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

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        if keyCode == Self.keyCodeEscape {
            if let onEscape, onEscape() { return nil }
            return Unmanaged.passUnretained(event)
        }

        if keyCode == Self.keyCodeT {
            let flags = event.flags
            let optionOnly = flags.contains(.maskAlternate)
                && flags.intersection([.maskCommand, .maskControl, .maskShift]).isEmpty
            if optionOnly {
                if let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
                   Self.chromeBundleIDs.contains(frontmost) {
                    return Unmanaged.passUnretained(event)
                }
                // 回调里不做重活（取词可能阻塞数百毫秒），异步派发
                DispatchQueue.main.async { [weak self] in self?.onTrigger?() }
                return nil
            }
        }

        return Unmanaged.passUnretained(event)
    }
}
