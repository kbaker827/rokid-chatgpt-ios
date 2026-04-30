import Foundation
import Combine

@MainActor
final class ChatGPTViewModel: ObservableObject {

    // MARK: - Published state
    @Published var messages:      [ChatMessage] = []
    @Published var draft:         String        = ""
    @Published var isResponding:  Bool          = false
    @Published var errorMessage:  String?       = nil
    @Published var inputMode:     InputMode     = .idle

    // MARK: - Sub-objects
    let speechManager = SpeechManager()
    let glassesServer = GlassesServer()

    // MARK: - Private
    private let apiClient = ChatGPTAPIClient()
    private var streamTask: Task<Void, Never>?

    var settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
        glassesServer.onRemoteQuery = { [weak self] query in
            Task { @MainActor [weak self] in
                guard let self, self.settings.glassesQueryEnabled else { return }
                await self.send(text: query, fromGlasses: true)
            }
        }
        speechManager.onSilence = { [weak self] transcript in
            guard let self, self.settings.autoSendVoice, !transcript.isEmpty else { return }
            Task { await self.send(text: transcript, fromGlasses: false) }
        }
        glassesServer.start()
    }

    // MARK: - Send

    func sendDraft() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        await send(text: text, fromGlasses: false)
    }

    func send(text: String, fromGlasses: Bool) async {
        guard !isResponding else { return }

        errorMessage = nil

        // Add user message
        let userMsg = ChatMessage(role: .user, content: text)
        messages.append(userMsg)

        // Notify glasses of incoming query
        glassesServer.sendQuery(text: text)
        glassesServer.sendThinking()

        // Placeholder assistant message
        let assistantId = UUID()
        var assistantMsg = ChatMessage(id: assistantId, role: .assistant, content: "")
        messages.append(assistantMsg)
        let assistantIdx = messages.count - 1

        isResponding = true
        inputMode    = .thinking

        streamTask = Task {
            defer {
                self.isResponding = false
                self.inputMode    = .idle
            }

            let history = trimmedHistory(excluding: assistantId)

            do {
                var fullText = ""
                let stream = await apiClient.stream(
                    messages:     history,
                    apiKey:       settings.apiKey,
                    modelId:      settings.modelId,
                    systemPrompt: settings.systemPrompt,
                    maxTokens:    settings.maxTokens
                )

                for try await chunk in stream {
                    guard !Task.isCancelled else { break }
                    fullText += chunk
                    messages[assistantIdx].content = fullText
                    inputMode = .responding(fullText)

                    // Stream chunks to glasses in streaming mode
                    if settings.glassesFormat == .streaming {
                        glassesServer.sendChunk(text: chunk)
                    }
                }

                // Send final response to glasses
                if !fullText.isEmpty {
                    glassesServer.sendResponse(text: fullText, format: settings.glassesFormat)
                }

            } catch {
                let errText = error.localizedDescription
                errorMessage = errText
                messages[assistantIdx].content = "⚠️ \(errText)"
                glassesServer.sendError(text: errText)
            }
        }
        await streamTask?.value
    }

    // MARK: - Stream control

    func stopStream() {
        streamTask?.cancel()
        streamTask = nil
        isResponding = false
        inputMode    = .idle
    }

    // MARK: - Voice

    func startVoice() {
        guard settings.voiceEnabled else { return }
        speechManager.startListening()
        inputMode = .listening
    }

    func stopVoice() async {
        let transcript = speechManager.stopListening()
        inputMode = .idle
        if !transcript.isEmpty {
            await send(text: transcript, fromGlasses: false)
        }
    }

    func cancelVoice() {
        speechManager.cancelListening()
        inputMode = .idle
    }

    // MARK: - Conversation

    func clearConversation() {
        stopStream()
        messages.removeAll()
        glassesServer.sendClear()
    }

    // MARK: - Suggested prompts

    var suggestedPrompts: [String] {
        [
            "What's the weather like today?",
            "Set a timer for 10 minutes",
            "Translate 'hello' to French",
            "What time is sunset today?",
            "How do I tie a bowline knot?",
            "Give me a quick workout idea"
        ]
    }

    // MARK: - Helpers

    private func trimmedHistory(excluding excludeId: UUID) -> [ChatMessage] {
        let relevant = messages.filter { $0.id != excludeId && $0.role != .system }
        // Keep last N pairs (user + assistant = 2 messages per pair)
        let maxMessages = settings.maxHistory * 2
        return Array(relevant.suffix(maxMessages))
    }
}
