import AppKit

/// 全局事件监听：
/// - 选取手势（拖选 / 双击选词）结束时上报，用于浮现划词图标
/// - 解释卡可见时吞掉 Esc 用于关卡（避免 Esc 漏给底下的应用——在 Claude Code 里那是打断 Agent 的键）
/// - 任意按键 / 鼠标按下时上报，用于收起划词图标
final class EventTap {
    /// 选取手势结束，参数为 AppKit（左下原点）坐标。Chrome 前台时不上报——浏览器内由插件的划词图标负责。
    /// Chrome App 独立窗口的 shim 进程 bundle ID 形如 com.google.Chrome.app.<id>，同样属于插件地盘
    var onSelectionGesture: ((NSPoint) -> Void)?
    /// 返回 true 表示 Esc 已被消费（解释卡正显示并被关闭）
    var onEscape: (() -> Bool)?
    /// 任意实体按键按下（用于收起图标）
    var onKeyDown: (() -> Void)?
    /// 鼠标左键按下，参数为 AppKit 坐标（用于收起不在点击处的图标）
    var onMouseDown: ((NSPoint) -> Void)?
    /// 返回 true 表示该点落在自家窗口（解释卡/图标/设置窗）上，手势应忽略
    var shouldIgnorePoint: ((NSPoint) -> Bool)?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var mouseDownLocation: CGPoint?

    private static let keyCodeEscape: Int64 = 53
    private static let dragThreshold: CGFloat = 12
    private static let chromeBundleIDPrefix = "com.google.Chrome"

    private static func isChromeFamily(_ bundleID: String) -> Bool {
        bundleID == chromeBundleIDPrefix || bundleID.hasPrefix(chromeBundleIDPrefix + ".")
    }

    /// 需要辅助功能权限；未授权时创建失败，返回 false
    func start() -> Bool {
        guard tap == nil else { return true }
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue)
                | (1 << CGEventType.leftMouseDown.rawValue)
                | (1 << CGEventType.leftMouseUp.rawValue)
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
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }

        case .leftMouseDown:
            mouseDownLocation = event.location
            let point = Self.appKitPoint(event.location)
            DispatchQueue.main.async { [weak self] in self?.onMouseDown?(point) }

        case .leftMouseUp:
            handleMouseUp(event)

        case .keyDown:
            DispatchQueue.main.async { [weak self] in self?.onKeyDown?() }
            if event.getIntegerValueField(.keyboardEventKeycode) == Self.keyCodeEscape,
               let onEscape, onEscape() {
                return nil
            }

        default:
            break
        }
        return Unmanaged.passUnretained(event)
    }

    private func handleMouseUp(_ event: CGEvent) {
        let upLocation = event.location
        let downLocation = mouseDownLocation
        mouseDownLocation = nil

        // 拖选（按下→移动超过阈值→抬起）或双击/三击选词才算选取手势
        let clickCount = event.getIntegerValueField(.mouseEventClickState)
        let dragged = downLocation.map {
            hypot(upLocation.x - $0.x, upLocation.y - $0.y) >= Self.dragThreshold
        } ?? false
        guard dragged || clickCount >= 2 else { return }

        if let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           Self.isChromeFamily(frontmost) {
            return
        }

        let point = Self.appKitPoint(upLocation)
        if shouldIgnorePoint?(point) == true { return }
        DispatchQueue.main.async { [weak self] in self?.onSelectionGesture?(point) }
    }

    /// CGEvent 坐标原点在主屏左上，AppKit 在主屏左下
    private static func appKitPoint(_ location: CGPoint) -> NSPoint {
        let primaryHeight = NSScreen.screens.first?.frame.maxY ?? 0
        return NSPoint(x: location.x, y: primaryHeight - location.y)
    }
}
