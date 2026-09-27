import AVFoundation
import Foundation

/// 发音：选区的读音，「怎么读」的听觉通道。
/// 由系统合成，不经引擎——因而不产生任何查询，也与解释的成败无关。
enum Pronunciation {
    private static let synthesizer = AVSpeechSynthesizer()

    /// 只有单词才发音，与音标同条件：去掉首尾标点后不含空白，且是拉丁字母词
    static func speakableWord(in selection: String) -> String? {
        let word = selection.trimmingCharacters(in: CharacterSet.letters.inverted)
        guard !word.isEmpty,
              word.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              word.range(of: "[A-Za-z]", options: .regularExpression) != nil
        else { return nil }
        return word
    }

    /// 正在播时再点 = 打断重播，不叠音
    static func speak(_ word: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: word)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US") // 与卡片上的美式 IPA 同口音
        synthesizer.speak(utterance)
    }

    static func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
