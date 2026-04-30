import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var vm: ChatGPTViewModel
    @EnvironmentObject private var settings: SettingsStore
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messageList
                Divider()
                inputBar
            }
            .navigationTitle("ChatGPT HUD")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(role: .destructive) { vm.clearConversation() } label: {
                        Label("Clear", systemImage: "trash")
                    }
                    .disabled(vm.messages.isEmpty)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    serverStatusDot
                }
            }
        }
    }

    // MARK: - Message list

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if vm.messages.isEmpty {
                        suggestedPromptsGrid
                    } else {
                        ForEach(vm.messages) { msg in
                            MessageBubble(message: msg)
                                .id(msg.id)
                        }
                        if vm.isResponding {
                            statusBar
                                .id("status")
                        }
                        Color.clear.frame(height: 8).id("bottom")
                    }
                }
                .padding()
            }
            .onChange(of: vm.messages.count) { _, _ in
                withAnimation { proxy.scrollTo("bottom") }
            }
            .onChange(of: vm.messages.last?.content) { _, _ in
                proxy.scrollTo("bottom")
            }
        }
    }

    // MARK: - Suggested prompts

    private var suggestedPromptsGrid: some View {
        VStack(spacing: 24) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green.opacity(0.7))
                .padding(.top, 40)
            Text("Ask ChatGPT")
                .font(.title2.weight(.semibold))
            Text("Type, speak, or ask from your Rokid glasses")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(vm.suggestedPrompts, id: \.self) { prompt in
                    Button {
                        Task { await vm.send(text: prompt, fromGlasses: false) }
                    } label: {
                        Text(prompt)
                            .font(.caption)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.primary)
                    }
                    .disabled(vm.isResponding)
                }
            }
            .padding(.top, 8)
        }
        .padding(.horizontal)
    }

    // MARK: - Status bar (while responding)

    private var statusBar: some View {
        HStack(spacing: 8) {
            ProgressView().scaleEffect(0.8)
            Text("ChatGPT is responding…")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Stop") { vm.stopStream() }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.red)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Message ChatGPT…", text: $vm.draft, axis: .vertical)
                .lineLimit(1...4)
                .padding(10)
                .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                .focused($inputFocused)
                .onSubmit { Task { await vm.sendDraft() } }

            // Voice button
            if settings.voiceEnabled {
                voiceButton
            }

            // Send button
            Button {
                Task { await vm.sendDraft() }
                inputFocused = false
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(vm.draft.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary : .green)
            }
            .disabled(vm.draft.trimmingCharacters(in: .whitespaces).isEmpty || vm.isResponding)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var voiceButton: some View {
        Button {
            if vm.speechManager.isListening {
                Task { await vm.stopVoice() }
            } else {
                vm.startVoice()
            }
        } label: {
            Image(systemName: vm.speechManager.isListening ? "mic.fill" : "mic")
                .font(.title2)
                .foregroundStyle(vm.speechManager.isListening ? .red : .secondary)
                .symbolEffect(.pulse, isActive: vm.speechManager.isListening)
        }
        .disabled(vm.isResponding)
    }

    // MARK: - Glasses server status dot

    private var serverStatusDot: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(vm.glassesServer.isRunning ? .green : .red)
                .frame(width: 8, height: 8)
            Text("\(vm.glassesServer.clientCount)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Message bubble

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .assistant {
                avatarView
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content.isEmpty ? "▌" : message.content)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        message.role == .user
                            ? Color.green.opacity(0.85)
                            : Color(.secondarySystemBackground)
                        , in: RoundedRectangle(cornerRadius: 18)
                    )
                    .foregroundStyle(message.role == .user ? .white : .primary)

                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.72,
                   alignment: message.role == .user ? .trailing : .leading)

            if message.role == .user { Spacer() }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }

    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(Color(.systemGreen).opacity(0.2))
                .frame(width: 32, height: 32)
            Text("G")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.green)
        }
    }
}
