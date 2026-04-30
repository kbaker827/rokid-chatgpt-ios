import SwiftUI

struct GlassesPreviewView: View {
    @EnvironmentObject private var vm: ChatGPTViewModel
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    glassesMockup
                    protocolCard
                    formatCard
                    connectionCard
                }
                .padding()
            }
            .navigationTitle("Glasses Preview")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Glasses mockup

    private var glassesMockup: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black)
                    .aspectRatio(16/4, contentMode: .fit)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(previewLines, id: \.self) { line in
                        Text(line)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(Color(red: 0.4, green: 0.9, blue: 0.4))
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(12)
            }
            .padding(.horizontal)

            Text("Rokid AR Glasses · TCP :8096")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
        }
    }

    private var previewLines: [String] {
        switch vm.inputMode {
        case .idle:
            let last = vm.messages.filter { $0.role == .assistant }.last
            if let msg = last {
                return ["🤖 " + String(msg.content.prefix(120))]
            }
            return ["Waiting for question…"]
        case .listening:
            let transcript = vm.speechManager.transcript
            return ["🎙 " + (transcript.isEmpty ? "Listening…" : transcript)]
        case .thinking:
            return ["⏳ Thinking…"]
        case .responding(let text):
            return [String(text.prefix(200))]
        }
    }

    // MARK: - Protocol card

    private var protocolCard: some View {
        GroupBox("TCP Wire Protocol · Port 8096") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Phone → Glasses (output)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                protocolLine(type: "query",    example: "🧑 What is the capital of France?")
                protocolLine(type: "thinking", example: "⏳ Thinking…")
                protocolLine(type: "chunk",    example: "<token>  ← streaming only")
                protocolLine(type: "response", example: "🤖 The capital of France is Paris.")
                protocolLine(type: "error",    example: "❌ Invalid API key")

                Divider().padding(.vertical, 4)
                Text("Glasses → Phone (input)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("QUERY: What time is it?")
                    .font(.system(.caption2, design: .monospaced))
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 6))
                Text("Plain text lines are also accepted as queries.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func protocolLine(type: String, example: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("{\"type\":\"\(type)\", \"text\":\"...\"}").font(.system(.caption2, design: .monospaced))
            Text(example).font(.caption2).foregroundStyle(.secondary).padding(.leading, 8)
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Format card

    private var formatCard: some View {
        GroupBox("Display Format") {
            VStack(spacing: 0) {
                ForEach(GlassesFormat.allCases) { fmt in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(fmt.displayName).font(.subheadline.weight(.medium))
                            Text(fmt.description).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if settings.glassesFormat == fmt {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        }
                    }
                    .padding(.vertical, 8)
                    if fmt != GlassesFormat.allCases.last {
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: - Connection card

    private var connectionCard: some View {
        GroupBox("Connection") {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Server", systemImage: "antenna.radiowaves.left.and.right")
                    Spacer()
                    Text(vm.glassesServer.isRunning ? "Running" : "Stopped")
                        .foregroundStyle(vm.glassesServer.isRunning ? .green : .red)
                        .font(.subheadline.weight(.medium))
                }
                HStack {
                    Label("Port", systemImage: "network")
                    Spacer()
                    Text("8096").foregroundStyle(.secondary)
                }
                HStack {
                    Label("Clients", systemImage: "display.2")
                    Spacer()
                    Text("\(vm.glassesServer.clientCount)").foregroundStyle(.secondary)
                }
            }
            .font(.subheadline)
        }
    }
}
