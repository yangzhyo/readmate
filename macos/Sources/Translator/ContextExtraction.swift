import Foundation
import ApplicationServices

/// 上下文提取（尽力而为）：焦点元素暴露全文（AXValue）时，切出选区两侧的窗口。
/// 与 extension/utils/extract-context.ts 的 3000 字符总量对齐；AX 拿不到段落结构，用定长窗口近似。
enum ContextExtraction {
    private static let sideCap = 1500

    static func around(element: AXUIElement, selection: String) -> String? {
        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success,
              let fullText = valueRef as? String, !fullText.isEmpty else { return nil }

        let ns = fullText as NSString
        var location = NSNotFound
        var length = 0

        var rangeRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
           let rangeRef, CFGetTypeID(rangeRef) == AXValueGetTypeID() {
            var cfRange = CFRange()
            if AXValueGetValue((rangeRef as! AXValue), .cfRange, &cfRange),
               cfRange.location >= 0, cfRange.location + cfRange.length <= ns.length {
                location = cfRange.location
                length = cfRange.length
            }
        }
        if location == NSNotFound {
            let found = ns.range(of: selection)
            guard found.location != NSNotFound else { return nil }
            location = found.location
            length = found.length
        }

        let start = max(0, location - sideCap)
        let end = min(ns.length, location + length + sideCap)
        guard end > start else { return nil }

        var window = ns.substring(with: NSRange(location: start, length: end - start))
        window = normalize(window)
        if start > 0 { window = "…" + window }
        if end < ns.length { window += "…" }

        // 上下文和选区一样长说明没有增量信息
        return normalize(window) == normalize(selection) ? nil : window
    }

    private static func normalize(_ text: String) -> String {
        text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
