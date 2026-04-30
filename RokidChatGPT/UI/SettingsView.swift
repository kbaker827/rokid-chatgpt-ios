import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var vm: ChatGPTViewModel
    @EnvironmentObject private var settings: SettingsStore
    @State private var showAPIKey = false

    var body: some View {
        NavigationStack {
            Form {
                // API Key
                Section("OpenAI API Key") {
                    LabeledContent("API Key") {
                        if showAPIKey {
                            TextField("sk-…", text: $settings.apiKey)
                                .multilineTextAlignment(.trailing)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        } else {
                            Text(settings.apiKey.isEmpty ? "Not set" : "sk-••••••")
                                .foregroundStyle(settings.apiKey.isEmpty ? .red : .secondary)
                        }
                    }
                    .onTapGesture { showAPIKey.toggle() }

                    Link("Get an API key at platform.openai.com",
                         destination: URL(string: "https://platform.openai.com/api-keys")!)
                        .font(.footnote)
                }

                // Model
                Section("Model") {
                    ForEach(GPTModel.all) { model in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(model.displayName).font(.subheadline.weight(.medium))
                                Text(model.description).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if settings.modelId == model.id {
                                Image(systemName: "checkmark").foregroundStyle(.green)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { settings.modelId = model.id }
                    }
                }

                // System prompt
                Section {
                    TextEditor(text: $settings.systemPrompt)
                        .frame(minHeight: 100)
                        .font(.footnote)
                } header: {
                    Text("System Prompt")
                } footer: {
                    Text("Customize ChatGPT's persona and response style.")
                }

                // Response settings
                Section("Response") {
                    HStack {
                        Text("Max tokens")
                        Spacer()
                        Text("\(settings.maxTokens)").foregroundStyle(.secondary)
                    }
                    Slider(value: Binding(
                        get: { Double(settings.maxTokens) },
                        set: { settings.maxTokens = Int($0) }
                    ), in: 128...2048, step: 128) {
                        Text("Max tokens")
                    } minimumValueLabel: { Text("128").font(.caption) }
                      maximumValueLabel: { Text("2048").font(.caption) }

                    HStack {
                        Text("Memory (message pairs)")
                        Spacer()
                        Text("\(settings.maxHistory)").foregroundStyle(.secondary)
                    }
                    Slider(value: Binding(
                        get: { Double(settings.maxHistory) },
                        set: { settings.maxHistory = Int($0) }
                    ), in: 1...20, step: 1)
                }

                // Voice
                Section("Voice Input") {
                    Toggle("Enable voice input", isOn: $settings.voiceEnabled)
                    if settings.voiceEnabled {
                        Toggle("Auto-send after silence", isOn: $settings.autoSendVoice)
                        HStack {
                            Image(systemName: vm.speechManager.isAvailable ? "mic.fill" : "mic.slash")
                                .foregroundStyle(vm.speechManager.isAvailable ? .green : .red)
                            Text(vm.speechManager.isAvailable ? "Microphone authorized" : "Microphone not authorized")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Glasses
                Section("Glasses Integration") {
                    Toggle("Accept queries from glasses", isOn: $settings.glassesQueryEnabled)

                    Picker("Display format", selection: $settings.glassesFormat) {
                        ForEach(GlassesFormat.allCases) { fmt in
                            Text(fmt.displayName).tag(fmt)
                        }
                    }

                    LabeledContent("TCP port", value: "8096").foregroundStyle(.secondary)
                    Text("Glasses can send plain text or \"QUERY: <question>\" lines to this port to ask ChatGPT directly.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                // About
                Section("About") {
                    LabeledContent("App",     value: "Rokid ChatGPT HUD")
                    LabeledContent("Version", value: "1.0")
                    LabeledContent("iOS",     value: "17.0+")
                    Link("OpenAI API docs",
                         destination: URL(string: "https://platform.openai.com/docs")!)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
