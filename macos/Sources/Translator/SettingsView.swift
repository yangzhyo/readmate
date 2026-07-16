import SwiftUI

/// 与插件的设置页对齐：只有 API key 和模型两项
struct SettingsView: View {
    @State private var apiKey = Settings.apiKey
    @State private var model = Settings.model
    @State private var hotkey = Settings.hotkey
    @State private var doubleTap = Settings.doubleTapOption
    var onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("API key 只保存在本机钥匙串；查询直连 Google Gemini，不留任何记录。")
                .font(.caption)
                .foregroundStyle(.secondary)

            SecureField("Gemini API key（aistudio.google.com/apikey）", text: $apiKey)
                .textFieldStyle(.roundedBorder)

            TextField("模型（默认 \(Settings.defaultModel)）", text: $model)
                .textFieldStyle(.roundedBorder)

            Toggle("连按两下 ⌥ 触发", isOn: $doubleTap)

            HotkeyRecorder(hotkey: $hotkey)

            HStack {
                Spacer()
                Button("保存") {
                    Settings.apiKey = apiKey
                    Settings.model = model
                    Settings.hotkey = hotkey
                    Settings.doubleTapOption = doubleTap
                    onDone()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 440)
    }
}
