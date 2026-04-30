import Foundation

// MARK: - Chat Message

struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let role: MessageRole
    var content: String
    let timestamp: Date

    init(id: UUID = UUID(), role: MessageRole, content: String, timestamp: Date = .now) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

enum MessageRole: String, Codable {
    case user, assistant, system
}

// MARK: - OpenAI API Request / Response

struct OpenAIRequest: Encodable {
    let model: String
    let messages: [OpenAIMessage]
    let maxTokens: Int
    let stream: Bool

    enum CodingKeys: String, CodingKey {
        case model, messages, stream
        case maxTokens = "max_tokens"
    }
}

struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

// MARK: - SSE chunk decoding

struct ChatCompletionChunk: Decodable {
    let choices: [ChunkChoice]
}

struct ChunkChoice: Decodable {
    let delta: DeltaContent
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case delta
        case finishReason = "finish_reason"
    }
}

struct DeltaContent: Decodable {
    let content: String?
    let role: String?
}

// MARK: - GPT Model catalogue

struct GPTModel: Identifiable {
    let id: String
    let displayName: String
    let description: String

    static let all: [GPTModel] = [
        GPTModel(id: "gpt-4o-mini",    displayName: "GPT-4o mini",    description: "Fastest · lowest cost · great for AR"),
        GPTModel(id: "gpt-4o",         displayName: "GPT-4o",         description: "Balanced speed & intelligence"),
        GPTModel(id: "gpt-4-turbo",    displayName: "GPT-4 Turbo",    description: "High intelligence, 128K context"),
        GPTModel(id: "gpt-3.5-turbo",  displayName: "GPT-3.5 Turbo",  description: "Legacy · very fast")
    ]
}

// MARK: - Glasses display format

enum GlassesFormat: String, CaseIterable, Identifiable {
    case streaming, summary, minimal
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .streaming: return "Streaming"
        case .summary:   return "Summary"
        case .minimal:   return "Minimal"
        }
    }
    var description: String {
        switch self {
        case .streaming: return "Every token streamed live"
        case .summary:   return "First 2 sentences after complete"
        case .minimal:   return "First sentence only"
        }
    }
}

// MARK: - Glasses wire packets

struct GlassesPacket {
    static func make(type: String, text: String) -> Data {
        let dict: [String: String] = ["type": type, "text": text]
        let data = (try? JSONSerialization.data(withJSONObject: dict)) ?? Data()
        return data + Data([0x0A]) // newline-delimited
    }

    /// Parses an incoming line from the glasses into a query string.
    /// Accepts "QUERY: <text>" or plain text.
    static func parseQuery(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.uppercased().hasPrefix("QUERY:") {
            let query = trimmed.dropFirst("QUERY:".count).trimmingCharacters(in: .whitespaces)
            return query.isEmpty ? nil : query
        }
        return trimmed
    }
}

// MARK: - View model input state

enum InputMode {
    case idle
    case listening
    case thinking
    case responding(String)
}
