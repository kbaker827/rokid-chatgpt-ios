import Foundation
import Combine

final class SettingsStore: ObservableObject {
    // MARK: - API
    @Published var apiKey: String {
        didSet { UserDefaults.standard.set(apiKey, forKey: "openai_api_key") }
    }

    // MARK: - Model
    @Published var modelId: String {
        didSet { UserDefaults.standard.set(modelId, forKey: "openai_model_id") }
    }

    // MARK: - System prompt
    @Published var systemPrompt: String {
        didSet { UserDefaults.standard.set(systemPrompt, forKey: "openai_system_prompt") }
    }

    // MARK: - Response settings
    @Published var maxTokens: Int {
        didSet { UserDefaults.standard.set(maxTokens, forKey: "openai_max_tokens") }
    }
    @Published var maxHistory: Int {
        didSet { UserDefaults.standard.set(maxHistory, forKey: "openai_max_history") }
    }

    // MARK: - Voice
    @Published var voiceEnabled: Bool {
        didSet { UserDefaults.standard.set(voiceEnabled, forKey: "openai_voice_enabled") }
    }
    @Published var autoSendVoice: Bool {
        didSet { UserDefaults.standard.set(autoSendVoice, forKey: "openai_auto_send_voice") }
    }

    // MARK: - Glasses
    @Published var glassesQueryEnabled: Bool {
        didSet { UserDefaults.standard.set(glassesQueryEnabled, forKey: "openai_glasses_query_enabled") }
    }
    @Published var glassesFormat: GlassesFormat {
        didSet { UserDefaults.standard.set(glassesFormat.rawValue, forKey: "openai_glasses_format") }
    }

    // MARK: - Init
    init() {
        let ud = UserDefaults.standard
        apiKey             = ud.string(forKey: "openai_api_key") ?? ""
        modelId            = ud.string(forKey: "openai_model_id") ?? "gpt-4o-mini"
        systemPrompt       = ud.string(forKey: "openai_system_prompt")
            ?? "You are a helpful AI assistant displayed on Rokid AR glasses. Keep answers concise and clear — ideally 1-3 sentences. Avoid markdown formatting, bullet points, or special characters. Speak naturally as if the user is reading your response on a heads-up display."
        maxTokens          = ud.integer(forKey: "openai_max_tokens").nonZero ?? 512
        maxHistory         = ud.integer(forKey: "openai_max_history").nonZero ?? 6
        voiceEnabled       = ud.object(forKey: "openai_voice_enabled") as? Bool ?? true
        autoSendVoice      = ud.object(forKey: "openai_auto_send_voice") as? Bool ?? true
        glassesQueryEnabled = ud.object(forKey: "openai_glasses_query_enabled") as? Bool ?? true
        glassesFormat      = GlassesFormat(rawValue: ud.string(forKey: "openai_glasses_format") ?? "") ?? .streaming
    }
}

private extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}
