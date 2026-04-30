import Foundation
import Speech
import AVFoundation

@MainActor
final class SpeechManager: ObservableObject {
    @Published var transcript: String = ""
    @Published var isListening: Bool  = false
    @Published var isAvailable: Bool  = false
    @Published var error: String?     = nil

    /// Called with the final transcript after 1.8 s of silence (when autoSend is on).
    var onSilence: ((String) -> Void)?

    private var recognizer: SFSpeechRecognizer?
    private var request:    SFSpeechAudioBufferRecognitionRequest?
    private var task:       SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    private var silenceTimer: Timer?
    private let silenceThreshold: TimeInterval = 1.8

    init() {
        recognizer = SFSpeechRecognizer(locale: .current)
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor [weak self] in
                self?.isAvailable = (status == .authorized)
            }
        }
    }

    // MARK: - Public API

    func startListening() {
        guard isAvailable, !isListening else { return }
        error = nil
        transcript = ""
        do {
            try beginSession()
            isListening = true
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Stops listening and returns the final transcript.
    func stopListening() -> String {
        let result = transcript
        tearDown()
        return result
    }

    func cancelListening() {
        tearDown()
        transcript = ""
    }

    // MARK: - Private

    private func beginSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request else { throw SpeechError.requestFailed }
        request.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }
        audioEngine.prepare()
        try audioEngine.start()

        task = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    self.resetSilenceTimer()
                }
                if let error {
                    self.error = error.localizedDescription
                    self.tearDown()
                }
            }
        }
    }

    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceThreshold, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isListening, !self.transcript.isEmpty else { return }
                let final = self.transcript
                self.tearDown()
                self.onSilence?(final)
            }
        }
    }

    private func tearDown() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        task?.cancel()
        task = nil
        request?.endAudio()
        request = nil
        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        isListening = false
    }
}

enum SpeechError: Error {
    case requestFailed
}
