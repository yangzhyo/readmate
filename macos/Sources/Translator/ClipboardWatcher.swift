import AppKit

/// 只记录剪贴板「何时变过」，从不读取内容——用于判断兜底取词时剪贴板内容是否新鲜。
final class ClipboardWatcher {
    static let shared = ClipboardWatcher()

    private(set) var lastChangeDate: Date?
    private var lastSeenChangeCount = NSPasteboard.general.changeCount
    private var timer: Timer?

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.pollNow()
        }
    }

    func pollNow() {
        let count = NSPasteboard.general.changeCount
        if count != lastSeenChangeCount {
            lastSeenChangeCount = count
            lastChangeDate = Date()
        }
    }

    /// 自己写剪贴板（恢复原内容）后调用，避免把自家写入当成新变化
    func ignoreCurrentChange() {
        lastSeenChangeCount = NSPasteboard.general.changeCount
    }
}
