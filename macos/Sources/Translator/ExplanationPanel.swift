import AppKit
import SwiftUI

final class PanelModel: ObservableObject {
    enum State {
        case loading
        case streaming
        case done
        case error(String)
        case hint
    }

    @Published var text = ""
    @Published var state: State = .loading
}

/// 解释卡：不抢焦点的浮动面板。Esc 的关闭由 EventTap 兜住（见 AppDelegate 接线），
/// 点卡外由全局鼠标监听关闭。
final class ExplanationPanel {
    var onRetry: (() -> Void)?

    private var panel: NSPanel?
    private var hostingView: NSHostingView<PanelView>?
    private let model = PanelModel()
    private var clickMonitor: Any?
    private var topLeft = NSPoint.zero
    private var hintToken = 0

    private static let width: CGFloat = 380
    private static let maxHeight: CGFloat = 480

    var isVisible: Bool { panel?.isVisible ?? false }

    // MARK: - 生命周期

    func show(near anchor: NSPoint) {
        createPanelIfNeeded()
        topLeft = NSPoint(x: anchor.x, y: anchor.y - 6)
        resizeToFit()
        panel?.orderFrontRegardless()
        installClickMonitor()
    }

    func close() {
        panel?.orderOut(nil)
        removeClickMonitor()
    }

    // MARK: - 内容状态

    func begin() {
        hintToken += 1
        model.text = ""
        model.state = .loading
        resizeSoon()
    }

    func append(_ chunk: String) {
        model.text += chunk
        model.state = .streaming
        resizeSoon()
    }

    func finish() {
        if case .streaming = model.state { model.state = .done }
        resizeSoon()
    }

    func fail(_ message: String) {
        model.text = message
        model.state = .error(message)
        resizeSoon()
    }

    /// 取词失败等一句话提示，短暂显示后自动消失
    func showTransientHint(_ message: String, near anchor: NSPoint) {
        show(near: anchor)
        model.text = message
        model.state = .hint
        resizeSoon()
        hintToken += 1
        let token = hintToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self, self.hintToken == token, case .hint = self.model.state else { return }
            self.close()
        }
    }

    // MARK: - 私有

    private func createPanelIfNeeded() {
        guard panel == nil else { return }
        let created = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.width, height: 100),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        created.level = .floating
        created.isFloatingPanel = true
        created.hidesOnDeactivate = false
        created.isMovableByWindowBackground = true
        created.backgroundColor = .clear
        created.isOpaque = false
        created.hasShadow = true
        created.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let hosting = NSHostingView(rootView: PanelView(model: model, onRetry: { [weak self] in self?.onRetry?() }))
        created.contentView = hosting
        hostingView = hosting
        panel = created
    }

    /// SwiftUI 布局是异步的，等一拍再量尺寸
    private func resizeSoon() {
        DispatchQueue.main.async { [weak self] in self?.resizeToFit() }
    }

    private func resizeToFit() {
        guard let panel, let hostingView else { return }
        var size = hostingView.fittingSize
        size.width = Self.width
        size.height = min(max(size.height, 48), Self.maxHeight)
        panel.setContentSize(size)
        panel.setFrameTopLeftPoint(clampedTopLeft(for: size))
    }

    private func clampedTopLeft(for size: NSSize) -> NSPoint {
        let screen = NSScreen.screens.first { NSPointInRect(topLeft, $0.frame) }
            ?? NSScreen.main ?? NSScreen.screens.first
        guard let visible = screen?.visibleFrame else { return topLeft }
        var point = topLeft
        point.x = min(max(point.x, visible.minX + 8), visible.maxX - size.width - 8)
        if point.y - size.height < visible.minY + 8 {
            point.y = visible.minY + 8 + size.height
        }
        point.y = min(point.y, visible.maxY - 8)
        return point
    }

    private func installClickMonitor() {
        guard clickMonitor == nil else { return }
        // 全局监听只收到其他应用的点击——正好是「点卡外」；卡内点击走本应用事件,不经过这里
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }
    }

    private func removeClickMonitor() {
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        clickMonitor = nil
    }
}

// MARK: - SwiftUI 内容

struct PanelView: View {
    @ObservedObject var model: PanelModel
    var onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch model.state {
            case .loading:
                Text("…")
                    .foregroundStyle(.secondary)
            case .hint:
                Text(model.text)
                    .foregroundStyle(.secondary)
            case .streaming, .done:
                Text(rendered)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .error(let message):
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("重试", action: onRetry)
            }
        }
        .padding(12)
        .frame(width: 380, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.separator, lineWidth: 1)
        )
    }

    /// prompt 约定输出只有 **加粗** 和换行，用系统的 inline Markdown 解析即可
    private var rendered: AttributedString {
        (try? AttributedString(
            markdown: model.text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(model.text)
    }
}
