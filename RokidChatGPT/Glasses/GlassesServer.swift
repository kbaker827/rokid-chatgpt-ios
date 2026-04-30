import Foundation
import Network

/// Bidirectional TCP server on port 8096.
/// - Glasses → Phone: plain text or "QUERY: <question>" lines
/// - Phone → Glasses: newline-delimited JSON packets
@MainActor
final class GlassesServer: ObservableObject {

    @Published var isRunning   = false
    @Published var clientCount = 0

    /// Called on the main actor when glasses send a query.
    var onRemoteQuery: ((String) -> Void)?

    private var listener: NWListener?
    private var connections: [ConnectionWrapper] = []
    private let port: NWEndpoint.Port = 8096
    private let queue = DispatchQueue(label: "GlassesServerQ", qos: .userInitiated)

    // MARK: - Start / Stop

    func start() {
        guard !isRunning else { return }
        do {
            listener = try NWListener(using: .tcp, on: port)
        } catch {
            print("GlassesServer: failed to create listener — \(error)")
            return
        }
        listener?.newConnectionHandler = { [weak self] conn in
            Task { @MainActor [weak self] in
                self?.accept(conn)
            }
        }
        listener?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                self?.isRunning = (state == .ready)
            }
        }
        listener?.start(queue: queue)
    }

    func stop() {
        listener?.cancel()
        listener = nil
        connections.forEach { $0.cancel() }
        connections.removeAll()
        clientCount = 0
        isRunning = false
    }

    // MARK: - Broadcast helpers

    func sendQuery(text: String) {
        broadcast(type: "query", text: "🧑 \(text)")
    }

    func sendThinking() {
        broadcast(type: "thinking", text: "⏳ Thinking…")
    }

    func sendChunk(text: String) {
        broadcast(type: "chunk", text: text)
    }

    func sendResponse(text: String, format: GlassesFormat) {
        switch format {
        case .streaming:
            broadcast(type: "response", text: "🤖 \(text)")
        case .summary:
            let sentences = extractSentences(from: text, max: 2)
            broadcast(type: "response", text: "🤖 \(sentences)")
        case .minimal:
            let sentence = extractSentences(from: text, max: 1)
            broadcast(type: "response", text: "🤖 \(sentence)")
        }
    }

    func sendError(text: String) {
        broadcast(type: "error", text: "❌ \(text)")
    }

    func sendClear() {
        broadcast(type: "clear", text: "")
    }

    // MARK: - Private

    private func accept(_ nwConn: NWConnection) {
        let wrapper = ConnectionWrapper(connection: nwConn, queue: queue)
        wrapper.onReceiveLine = { [weak self] line in
            Task { @MainActor [weak self] in
                guard let self, self.isRunning else { return }
                if let query = GlassesPacket.parseQuery(from: line) {
                    self.onRemoteQuery?(query)
                }
            }
        }
        wrapper.onDisconnect = { [weak self] in
            Task { @MainActor [weak self] in
                self?.connections.removeAll { $0 === wrapper }
                self?.clientCount = self?.connections.count ?? 0
            }
        }
        connections.append(wrapper)
        clientCount = connections.count
        wrapper.start()
    }

    private func broadcast(type: String, text: String) {
        let packet = GlassesPacket.make(type: type, text: text)
        connections.forEach { $0.send(packet) }
    }

    private func extractSentences(from text: String, max: Int) -> String {
        var sentences: [String] = []
        text.enumerateSubstrings(in: text.startIndex..., options: .bySentences) { sub, _, _, stop in
            if let s = sub?.trimmingCharacters(in: .whitespaces), !s.isEmpty {
                sentences.append(s)
                if sentences.count >= max { stop = true }
            }
        }
        return sentences.joined(separator: " ")
    }
}

// MARK: - Connection wrapper

private final class ConnectionWrapper {
    let connection: NWConnection
    var onReceiveLine:  ((String) -> Void)?
    var onDisconnect:   (() -> Void)?

    private let queue: DispatchQueue
    private var buffer = Data()

    init(connection: NWConnection, queue: DispatchQueue) {
        self.connection = connection
        self.queue = queue
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled:
                self?.onDisconnect?()
            default: break
            }
        }
        connection.start(queue: queue)
        receiveNext()
    }

    func send(_ data: Data) {
        connection.send(content: data, completion: .contentProcessed { _ in })
    }

    func cancel() {
        connection.cancel()
    }

    private func receiveNext() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                self.buffer.append(data)
                self.processBuffer()
            }
            if isComplete || error != nil {
                self.onDisconnect?()
            } else {
                self.receiveNext()
            }
        }
    }

    private func processBuffer() {
        while let newlineIndex = buffer.firstIndex(of: 0x0A) {
            let lineData = buffer[buffer.startIndex..<newlineIndex]
            buffer.removeSubrange(buffer.startIndex...newlineIndex)
            if let line = String(data: lineData, encoding: .utf8) {
                onReceiveLine?(line)
            }
        }
    }
}
