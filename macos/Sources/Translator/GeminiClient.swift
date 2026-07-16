import Foundation

// 与 extension/utils/gemini.ts 行为对齐：streamGenerateContent SSE、maxOutputTokens 2048、错误摘要截断。
enum GeminiError: LocalizedError {
    case api(Int, String)

    var errorDescription: String? {
        switch self {
        case .api(let status, let message):
            return "Gemini API \(status)：\(message)"
        }
    }
}

enum GeminiClient {
    private static let apiBase = "https://generativelanguage.googleapis.com/v1beta/models"

    static func stream(
        selection: String,
        context: String?,
        apiKey: String,
        model: String
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let encodedModel = model.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? model
                    var request = URLRequest(url: URL(string: "\(apiBase)/\(encodedModel):streamGenerateContent?alt=sse")!)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
                    let body: [String: Any] = [
                        "systemInstruction": ["parts": [["text": Prompt.system]]],
                        "contents": [
                            ["role": "user", "parts": [["text": Prompt.user(selection: selection, context: context)]]]
                        ],
                        "generationConfig": ["maxOutputTokens": 2048],
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    guard (200..<300).contains(status) else {
                        var detail = ""
                        for try await line in bytes.lines {
                            detail += line
                            if detail.count > 2000 { break }
                        }
                        throw GeminiError.api(status, summarizeApiError(detail))
                    }
                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        if let text = parseSseLine(line), !text.isEmpty {
                            continuation.yield(text)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func parseSseLine(_ raw: String) -> String? {
        let line = raw.trimmingCharacters(in: .whitespaces)
        guard line.hasPrefix("data:") else { return nil }
        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
        guard !payload.isEmpty, payload != "[DONE]",
              let json = try? JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else { return nil }
        return parts.compactMap { $0["text"] as? String }.joined()
    }

    private static func summarizeApiError(_ body: String) -> String {
        if let json = try? JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any],
           let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            return String(message.prefix(200))
        }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未知错误" : String(trimmed.prefix(200))
    }
}
