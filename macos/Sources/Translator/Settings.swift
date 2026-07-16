import AppKit
import Foundation
import Security

/// API key 存钥匙串，模型等非敏感设置存 UserDefaults。两个载体各存一份 key，不同步。
enum Settings {
    static let defaultModel = "gemini-3.5-flash"

    struct Hotkey: Equatable {
        /// 硬件键码（与修饰键无关）
        var keyCode: Int
        /// NSEvent.ModifierFlags 的 rawValue（仅设备无关的 ⌘⌃⌥⇧ 部分）
        var modifiers: UInt
        /// 录制时生成的展示文本，如 "⌥T"
        var display: String
    }

    static let defaultHotkey = Hotkey(
        keyCode: 17, // T
        modifiers: NSEvent.ModifierFlags.option.rawValue,
        display: "⌥T"
    )

    private static let modelKey = "model"
    private static let hotkeyKeyCodeKey = "hotkeyKeyCode"
    private static let hotkeyModifiersKey = "hotkeyModifiers"
    private static let hotkeyDisplayKey = "hotkeyDisplay"
    private static let keychainService = "Translator"
    private static let keychainAccount = "gemini-api-key"

    static var hotkey: Hotkey {
        get {
            let defaults = UserDefaults.standard
            guard defaults.object(forKey: hotkeyKeyCodeKey) != nil else { return defaultHotkey }
            return Hotkey(
                keyCode: defaults.integer(forKey: hotkeyKeyCodeKey),
                modifiers: UInt(defaults.integer(forKey: hotkeyModifiersKey)),
                display: defaults.string(forKey: hotkeyDisplayKey) ?? "?"
            )
        }
        set {
            let defaults = UserDefaults.standard
            defaults.set(newValue.keyCode, forKey: hotkeyKeyCodeKey)
            defaults.set(Int(newValue.modifiers), forKey: hotkeyModifiersKey)
            defaults.set(newValue.display, forKey: hotkeyDisplayKey)
        }
    }

    static var model: String {
        get {
            let stored = UserDefaults.standard.string(forKey: modelKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return stored.isEmpty ? defaultModel : stored
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            UserDefaults.standard.set(trimmed.isEmpty ? defaultModel : trimmed, forKey: modelKey)
        }
    }

    static var apiKey: String {
        get { readKeychain() ?? "" }
        set { writeKeychain(newValue.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
    }

    private static func readKeychain() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func writeKeychain(_ value: String) {
        if value.isEmpty {
            SecItemDelete(baseQuery as CFDictionary)
            return
        }
        let data = Data(value.utf8)
        let update = [kSecValueData as String: data] as CFDictionary
        let status = SecItemUpdate(baseQuery as CFDictionary, update)
        if status == errSecItemNotFound {
            var add = baseQuery
            add[kSecValueData as String] = data
            SecItemAdd(add as CFDictionary, nil)
        }
    }
}
