import AppKit
import SwiftUI

/// 快捷键录制控件：点击进入录制态，按下新组合即生效；Esc 取消。
/// 要求至少含 ⌘⌃⌥ 之一，避免把普通打字键劫持成全局触发。
struct HotkeyRecorder: View {
    @Binding var hotkey: Settings.Hotkey
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack {
            Text("触发快捷键")
            Spacer()
            Button(recording ? "按下新组合…（Esc 取消）" : hotkey.display) {
                recording ? stopRecording() : startRecording()
            }
        }
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            defer { stopRecording() }
            guard event.keyCode != 53 else { return nil } // Esc 取消
            let mods = event.modifierFlags.intersection([.command, .control, .option, .shift])
            guard !mods.intersection([.command, .control, .option]).isEmpty else { return nil }
            hotkey = Settings.Hotkey(
                keyCode: Int(event.keyCode),
                modifiers: mods.rawValue,
                display: Self.display(for: event, modifiers: mods)
            )
            return nil
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
    }

    private static func display(for event: NSEvent, modifiers: NSEvent.ModifierFlags) -> String {
        var text = ""
        if modifiers.contains(.control) { text += "⌃" }
        if modifiers.contains(.option) { text += "⌥" }
        if modifiers.contains(.shift) { text += "⇧" }
        if modifiers.contains(.command) { text += "⌘" }
        return text + keyName(for: event)
    }

    private static let specialKeyNames: [Int: String] = [
        36: "↩", 48: "⇥", 49: "空格", 51: "⌫", 117: "⌦",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
    ]

    private static func keyName(for event: NSEvent) -> String {
        if let name = specialKeyNames[Int(event.keyCode)] { return name }
        let chars = event.charactersIgnoringModifiers ?? ""
        return chars.isEmpty ? "键码\(event.keyCode)" : chars.uppercased()
    }
}
