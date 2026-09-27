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
            // 鹦鹉按原尺寸（每格 1pt）显示，放在 26pt 见方的点击区域中央
            Image(nsImage: ParrotSprite.color)
                .interpolation(.none)
                .shadow(color: .black.opacity(0.35), radius: 1.5, y: 1)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(3)
    }
}
