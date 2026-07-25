import AppKit

/// 全局事件监听：
/// - 选取手势（拖选 / 双击选词）结束且有选区证据时上报，用于浮现划词图标
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
    private var mouseDownChangeCount: Int?
    /// 每次鼠标按下/按键递增。选区证据是异步探测的，靠它丢弃过期结果——
    /// 探测期间用户已有新动作时，迟到的图标不该再浮出来
    private var gestureGeneration = 0
    /// 已尝试注入无障碍激活开关的进程（每个应用实例只试一次）
    private var activationAttemptedPIDs = Set<pid_t>()

    private static let keyCodeEscape: Int64 = 53
    private static let dragThreshold: CGFloat = 12
    private static let chromeBundleIDPrefix = "com.google.Chrome"
    /// 复判等待：选中即复制的应用可能在 mouseUp 之后才写剪贴板；刚注入激活开关的应用需要一点时间起树
    private static let evidenceGraceDelay: TimeInterval = 0.3
    private static let evidenceQueue = DispatchQueue(label: "translator.selection-evidence")

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
            gestureGeneration += 1
            mouseDownLocation = event.location
            mouseDownChangeCount = NSPasteboard.general.changeCount
            let point = Self.appKitPoint(event.location)
            DispatchQueue.main.async { [weak self] in self?.onMouseDown?(point) }

        case .leftMouseUp:
            handleMouseUp(event)

        case .keyDown:
            gestureGeneration += 1
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
        let changeCountAtDown = mouseDownChangeCount
        mouseDownLocation = nil
        mouseDownChangeCount = nil

        // 拖选（按下→移动超过阈值→抬起）或双击/三击选词才算选取手势
        let clickCount = event.getIntegerValueField(.mouseEventClickState)
        let dragged = downLocation.map {
            hypot(upLocation.x - $0.x, upLocation.y - $0.y) >= Self.dragThreshold
        } ?? false
        guard dragged || clickCount >= 2 else { return }

        let frontmost = NSWorkspace.shared.frontmostApplication
        if let bundleID = frontmost?.bundleIdentifier, Self.isChromeFamily(bundleID) {
            return
        }

        let point = Self.appKitPoint(upLocation)
        if shouldIgnorePoint?(point) == true { return }
        confirmSelectionEvidence(changeCountAtDown: changeCountAtDown, frontmost: frontmost) { [weak self] in
            self?.onSelectionGesture?(point)
        }
    }

    /// 手势只是形似选取，还须有选区证据才上报，否则双击空白/空白处拖动/拖窗口也会浮出图标。
    /// 证据规则（见 docs/adr/0003）：
    /// ① AX 焦点元素报出非空选区 → 浮现——覆盖多数原生应用；
    /// ② 手势期间剪贴板变过 → 浮现——覆盖选中即复制、没有 AX 选区的应用（如 Claude Code 的 TUI）；
    /// ③ AX 明确作证无选区且剪贴板没动 → 按假阳性丢弃；
    /// ④ AX 无法作证（无障碍树未启用/焦点是不透明容器）→ 尝试注入 Electron 激活开关后复判，
    ///    仍无法作证则宁可疑罪从无，按旧行为浮现（WhatsApp 这类 AX 暴露不全的应用还得能用）。
    /// AX 询问对假死应用最多阻塞 0.3 秒/次，放主线程就是拖住全局事件投递
    /// （前车之鉴见 SelectionCapture 的超时注释），所以放串行后台队列。
    private func confirmSelectionEvidence(
        changeCountAtDown: Int?,
        frontmost: NSRunningApplication?,
        then report: @escaping () -> Void
    ) {
        let generation = gestureGeneration
        let clipboardChanged = {
            changeCountAtDown.map { NSPasteboard.general.changeCount != $0 } ?? false
        }
        let bundleID = frontmost?.bundleIdentifier
        Self.evidenceQueue.async {
            let verdict = SelectionCapture.axSelectionVerdict(frontmostBundleID: bundleID)
            DispatchQueue.main.async { [weak self] in
                guard let self, generation == self.gestureGeneration else { return }
                switch verdict {
                case .selected:
                    report()
                case .noSelection:
                    self.reportIfEvidenceEmerges(
                        clipboardChanged: clipboardChanged,
                        frontmostBundleID: bundleID,
                        generation: generation,
                        report: report
                    )
                case .unjudgeable:
                    self.resolveUnjudgeable(
                        frontmost: frontmost,
                        clipboardChanged: clipboardChanged,
                        generation: generation,
                        report: report
                    )
                }
            }
        }
    }

    /// 无选区判定的兜底：立即看剪贴板，0.3 秒后再复查剪贴板并复判一次 AX。
    /// 迟到的证据是真实存在的——选中即复制的应用（TUI）写剪贴板晚于 mouseUp；
    /// Terminal 则连选区本身都是 mouseUp 之后才异步提交（实测双击 +50ms 才可读，
    /// 拖选在 +5ms 可读但仍晚于本探测），首判必然扑空
    private func reportIfEvidenceEmerges(
        clipboardChanged: @escaping () -> Bool,
        frontmostBundleID: String?,
        generation: Int,
        report: @escaping () -> Void
    ) {
        if clipboardChanged() {
            report()
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.evidenceGraceDelay) { [weak self] in
            guard let self, generation == self.gestureGeneration else { return }
            if clipboardChanged() {
                report()
                return
            }
            Self.evidenceQueue.async {
                let verdict = SelectionCapture.axSelectionVerdict(frontmostBundleID: frontmostBundleID)
                DispatchQueue.main.async { [weak self] in
                    guard let self, generation == self.gestureGeneration else { return }
                    // 复判只认「有选区」；仍无选区或反而无法作证都维持原判，避免复判放宽标准
                    if verdict == .selected { report() }
                }
            }
        }
    }

    /// AX 无法作证时：没试过的应用先注入 Electron 无障碍激活开关（接受后给树一点启动时间再复判一次）；
    /// 开关被拒或复判仍无法作证 → 回退旧行为浮现
    private func resolveUnjudgeable(
        frontmost: NSRunningApplication?,
        clipboardChanged: @escaping () -> Bool,
        generation: Int,
        report: @escaping () -> Void
    ) {
        guard let frontmost, !activationAttemptedPIDs.contains(frontmost.processIdentifier) else {
            report()
            return
        }
        activationAttemptedPIDs.insert(frontmost.processIdentifier)
        let bundleID = frontmost.bundleIdentifier
        let pid = frontmost.processIdentifier
        Self.evidenceQueue.async {
            guard SelectionCapture.requestAXActivation(pid: pid) else {
                DispatchQueue.main.async { [weak self] in
                    guard let self, generation == self.gestureGeneration else { return }
                    report()
                }
                return
            }
            Self.evidenceQueue.asyncAfter(deadline: .now() + Self.evidenceGraceDelay) {
                let verdict = SelectionCapture.axSelectionVerdict(frontmostBundleID: bundleID)
                DispatchQueue.main.async { [weak self] in
                    guard let self, generation == self.gestureGeneration else { return }
                    switch verdict {
                    case .selected, .unjudgeable:
                        report()
                    case .noSelection:
                        if clipboardChanged() { report() }
                    }
                }
            }
        }
    }

    /// CGEvent 坐标原点在主屏左上，AppKit 在主屏左下
    private static func appKitPoint(_ location: CGPoint) -> NSPoint {
        let primaryHeight = NSScreen.screens.first?.frame.maxY ?? 0
        return NSPoint(x: location.x, y: primaryHeight - location.y)
    }
}
