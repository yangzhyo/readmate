import AppKit
import SwiftUI

/// 划词图标：选取手势结束后浮现在鼠标附近的小按钮，点击即触发解释。
/// 随下一次按键/别处点击收起；对假阳性手势（拖窗口等）则超时自动消失。
final class TriggerIcon {
    var onClick: (() -> Void)?

    private var panel: NSPanel?
    private var hideTimer: Timer?

    private static let panelSize: CGFloat = 32
    private static let lifetime: TimeInterval = 6

    func show(at point: NSPoint) {
        createPanelIfNeeded()
        guard let panel else { return }
        var origin = NSPoint(x: point.x + 8, y: point.y - Self.panelSize - 10)
        if let screen = NSScreen.screens.first(where: { NSPointInRect(point, $0.frame) }) ?? NSScreen.main {
            let visible = screen.visibleFrame
            origin.x = min(max(origin.x, visible.minX + 4), visible.maxX - Self.panelSize - 4)
            origin.y = min(max(origin.y, visible.minY + 4), visible.maxY - Self.panelSize - 4)
        }
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: Self.lifetime, repeats: false) { [weak self] _ in
            self?.hide()
        }
    }

    func hide() {
        hideTimer?.invalidate()
        hideTimer = nil
        panel?.orderOut(nil)
    }

    /// 给「别处点击收起」用：点在图标上不算别处
    func frameContains(_ point: NSPoint) -> Bool {
        guard let panel, panel.isVisible else { return false }
        return NSPointInRect(point, panel.frame)
    }

    private func createPanelIfNeeded() {
        guard panel == nil else { return }
        let created = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.panelSize, height: Self.panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        created.level = .floating
        created.isFloatingPanel = true
        created.hidesOnDeactivate = false
        created.backgroundColor = .clear
        created.isOpaque = false
        created.hasShadow = false
        created.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        created.contentView = NSHostingView(rootView: TriggerIconView(onClick: { [weak self] in
            self?.hide()
            self?.onClick?()
        }))
        panel = created
    }
}

struct TriggerIconView: View {
    var onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            Text("译")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                // 与插件划词图标同色（#0969da）
                .background(Circle().fill(Color(red: 0x09 / 255.0, green: 0x69 / 255.0, blue: 0xda / 255.0)))
                .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
        }
        .buttonStyle(.plain)
        .padding(3)
    }
}
