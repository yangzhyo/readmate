import AppKit
import ApplicationServices

struct Capture {
    let selection: String
    /// 尽力而为：AX 能拿到全文时才有（见 docs/adr/0001）
    let context: String?
    /// 选区在屏幕上的锚点（AppKit 左下原点坐标系），拿不到时由调用方退回鼠标位置
    let anchor: NSPoint?
}

/// 取词：AX 优先，模拟 ⌘C 兜底（读后恢复原剪贴板，恢复写入带 Transient 标记）。
enum SelectionCapture {
    static func capture() -> Capture? {
        if let viaAX = captureViaAX() { return viaAX }
        if let selection = captureViaClipboard() {
            return Capture(selection: selection, context: nil, anchor: nil)
        }
        return nil
    }

    // MARK: - AX 路径

    private static func captureViaAX() -> Capture? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
              let focusedRef else { return nil }
        let element = focusedRef as! AXUIElement

        var selectionRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectionRef) == .success,
              let selection = (selectionRef as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !selection.isEmpty else { return nil }

        return Capture(
            selection: selection,
            context: ContextExtraction.around(element: element, selection: selection),
            anchor: anchorPoint(element: element)
        )
    }

    /// 选区末端的屏幕坐标：AXSelectedTextRange + AXBoundsForRange，AX 的左上原点转 AppKit 左下原点
    private static func anchorPoint(element: AXUIElement) -> NSPoint? {
        var rangeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
              let rangeRef, CFGetTypeID(rangeRef) == AXValueGetTypeID() else { return nil }
        var boundsRef: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element, kAXBoundsForRangeParameterizedAttribute as CFString, rangeRef, &boundsRef
        ) == .success, let boundsRef, CFGetTypeID(boundsRef) == AXValueGetTypeID() else { return nil }
        var rect = CGRect.zero
        guard AXValueGetValue((boundsRef as! AXValue), .cgRect, &rect),
              rect.width > 0 || rect.height > 0,
              let primary = NSScreen.screens.first else { return nil }
        return NSPoint(x: rect.minX, y: primary.frame.maxY - rect.maxY)
    }

    // MARK: - 剪贴板兜底

    /// ⌘C 兜不住时（见下），采用剪贴板既有内容的新鲜度窗口
    private static let clipboardFreshness: TimeInterval = 15

    private static func captureViaClipboard() -> String? {
        let pasteboard = NSPasteboard.general
        ClipboardWatcher.shared.pollNow()

        let saved: [[(NSPasteboard.PasteboardType, Data)]] = (pasteboard.pasteboardItems ?? []).map { item in
            item.types.compactMap { type in item.data(forType: type).map { (type, $0) } }
        }
        let savedString = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let changeCountBefore = pasteboard.changeCount

        postCmdC()
        let deadline = Date().addingTimeInterval(0.5)
        while pasteboard.changeCount == changeCountBefore && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }

        if pasteboard.changeCount != changeCountBefore {
            let selection = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines)
            restore(saved, to: pasteboard)
            ClipboardWatcher.shared.ignoreCurrentChange()
            return (selection?.isEmpty == false) ? selection : nil
        }

        // ⌘C 没产出新内容——有些应用（如 Claude Code 的 TUI）自己接管选择并在选中时即时复制，
        // 终端里没有可拷的原生选区。此时若剪贴板内容是刚刚写入的（选中时的自动复制），直接采用。
        if let savedString, !savedString.isEmpty,
           let changed = ClipboardWatcher.shared.lastChangeDate,
           Date().timeIntervalSince(changed) <= clipboardFreshness {
            return savedString
        }
        return nil
    }

    private static func restore(_ saved: [[(NSPasteboard.PasteboardType, Data)]], to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !saved.isEmpty else { return }
        let items = saved.map { pairs -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in pairs { item.setData(data, forType: type) }
            return item
        }
        // Transient 标记：让守规范的剪贴板历史工具忽略这次恢复写入
        items[0].setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
        pasteboard.writeObjects(items)
    }

    private static func postCmdC() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyC: CGKeyCode = 8
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyC, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyC, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
