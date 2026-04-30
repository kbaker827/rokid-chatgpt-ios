import Foundation

actor ChatGPTAPIClient {

    private let baseURL = URL(string: "https://api.openai.com/v1/chat/completions")!

    // MARK: - Streaming

    func stream(
        messages: [ChatMessage],
        apiKey: String,
        modelId: String,
        systemPrompt: String,
        maxTokens: Int
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let request = try self.buildRequest(
                        messages: messages,
                        apiKey: apiKey,
                        modelId: modelId,
                        systemPrompt: systemPrompt,
                        maxTokens: maxTokens,
                        stream: true
                    )

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    if let httpResponse = response as? HTTPURLResponse,
                       !(200..<300).contains(httpResponse.statusCode) {
                        let errorData = try await self.collectBody(bytes: bytes)
                        throw ChatGPTError.httpError(httpResponse.statusCode, String(data: errorData, encoding: .utf8) ?? "")
                    }

                    for try await line in bytes.lines {
                        // SSE lines look like: "data: {...}" or "data: [DONE]"
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        if payload == "[DONE]" { break }

                        guard let data = payload.data(using: .utf8),
                              let chunk = try? JSONDecoder().decode(ChatCompletionChunk.self, from: data),
                              let text = chunk.choices.first?.delta.content,
                              !text.isEmpty
                        else { continue }

                        continuation.yield(text)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Non-streaming (single response)

    func send(
        messages: [ChatMessage],
        apiKey: String,
        modelId: String,
        systemPrompt: String,
        maxTokens: Int
    ) async throws -> String {
        let request = try buildRequest(
            messages: messages,
            apiKey: apiKey,
            modelId: modelId,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens,
            stream: false
        )

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw ChatGPTError.httpError(httpResponse.statusCode, String(data: data, encoding: .utf8) ?? "")
        }

        // Non-streaming response: {"choices":[{"message":{"content":"..."}}]}
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        }
        throw ChatGPTError.invalidResponse
    }

    // MARK: - Private helpers

    private func buildRequest(
        messages: [ChatMessage],
        apiKey: String,
        modelId: String,
        systemPrompt: String,
        maxTokens: Int,
        stream: Bool
    ) throws -> URLRequest {
        guard !apiKey.isEmpty else { throw ChatGPTError.missingAPIKey }

        // Build OpenAI message array: system message first, then conversation
        var openAIMessages: [OpenAIMessage] = []
        if !systemPrompt.isEmpty {
            openAIMessages.append(OpenAIMessage(role: "system", content: systemPrompt))
        }
        openAIMessages += messages.compactMap { msg in
            guard msg.role != .system else { return nil }
            return OpenAIMessage(role: msg.role.rawValue, content: msg.content)
        }

        let body = OpenAIRequest(
            model: modelId,
            messages: openAIMessages,
            maxTokens: maxTokens,
            stream: stream
        )

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json",    forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)",    forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)
        request.timeoutInterval = 60
        return request
    }

    private func collectBody(bytes: URLSession.AsyncBytes) async throws -> Data {
        var data = Data()
        for try await byte in bytes { data.append(byte) }
        return data
    }
}

// MARK: - Errors

enum ChatGPTError: LocalizedError {
    case missingAPIKey
    case httpError(Int, String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API key is not set. Go to Settings and paste your key."
        case .httpError(let code, let body):
            if code == 401 { return "Invalid API key (401). Check your key in Settings." }
            if code == 429 { return "Rate limited (429). Try again in a moment." }
            if code == 400 { return "Bad request (400): \(body)" }
            return "HTTP \(code): \(body)"
        case .invalidResponse:
            return "Unexpected response format from OpenAI."
        }
    }
}
