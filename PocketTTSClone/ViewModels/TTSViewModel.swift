import Foundation
import SwiftUI
import AVFoundation

/// Main ViewModel coordinating all TTS operations
@MainActor
final class TTSViewModel: ObservableObject {
    // MARK: - Published State

    @Published var state: TTSState = .idle
    @Published var selectedVoice: VoiceProfile?
    @Published var textInput = ""
    @Published var generatedAudioURL: URL?
    @Published var referenceAudioURL: URL?
    @Published var isModelReady = false
    @Published var modelDownloadProgress: Double = 0
    @Published var modelDownloadStatus = ""
    @Published var showSettings = false
    @Published var settings = GenerationConfig()
    @Published var savedVoices: [VoiceProfile] = []

    // MARK: - Services

    let recorder = AudioRecorderService()
    let player = AudioPlayerService()
    let modelDownloader = ModelDownloader()
    private var ttsEngine: TTSEngine?

    // MARK: - Initialization

    init() {
        loadSavedVoices()
        checkModelStatus()
    }

    // MARK: - Model Management

    func checkModelStatus() {
        isModelReady = modelDownloader.isModelDownloaded || ttsEngine != nil
        if isModelReady {
            initializeEngine()
        }
    }

    func downloadModels() async {
        do {
            let modelPath = try await modelDownloader.downloadModels { [weak self] progress, status in
                Task { @MainActor in
                    self?.modelDownloadProgress = progress
                    self?.modelDownloadStatus = status
                }
            }
            await MainActor.run {
                isModelReady = true
                modelDownloadStatus = "Models ready"
                initializeEngine()
            }
        } catch {
            await MainActor.run {
                state = .error("Download failed: \(error.localizedDescription)")
                modelDownloadStatus = "Download failed"
            }
        }
    }

    private func initializeEngine() {
        let modelPath = modelDownloader.modelsDirectory.path
        let config = PocketTTSModelConfig.defaultConfig(modelPath: modelPath)

        do {
            ttsEngine = try TTSEngine(config: config)
            isModelReady = true
        } catch {
            print("Engine init failed: \(error.localizedDescription)")
            // Engine will be initialized when first generate is called
        }
    }

    // MARK: - Voice Management

    func saveCurrentVoice(name: String) {
        guard let url = referenceAudioURL else { return }
        let profile = VoiceProfile(
            name: name,
            referenceAudioPath: url.path,
            duration: recorder.recordingDuration
        )
        savedVoices.append(profile)
        selectedVoice = profile
        saveVoices()
    }

    func selectVoice(_ profile: VoiceProfile) {
        selectedVoice = profile
        if let path = profile.referenceAudioPath {
            referenceAudioURL = URL(fileURLWithPath: path)
        }
    }

    func deleteVoice(_ profile: VoiceProfile) {
        savedVoices.removeAll { $0.id == profile.id }
        if let path = profile.referenceAudioPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        if selectedVoice?.id == profile.id {
            selectedVoice = nil
            referenceAudioURL = nil
        }
        saveVoices()
    }

    // MARK: - Recording

    func startRecording() {
        guard state.isIdle else { return }
        do {
            let url = try recorder.startRecording()
            state = .recording
            referenceAudioURL = url
        } catch {
            state = .error("Recording failed: \(error.localizedDescription)")
        }
    }

    func stopRecording() {
        guard let url = recorder.stopRecording() else {
            state = .error("Recording failed - no audio captured")
            return
        }
        referenceAudioURL = url
        state = .idle
    }

    // MARK: - Import Audio

    func importAudio(url: URL) {
        state = .importing
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let voicesDir = documents.appendingPathComponent("voices")
        try? FileManager.default.createDirectory(at: voicesDir, withIntermediateDirectories: true)

        let destURL = voicesDir.appendingPathComponent("imported_\(Date().timeIntervalSince1970).wav")

        do {
            if url.pathExtension.lowercased() == "wav" {
                try FileManager.default.copyItem(at: url, to: destURL)
            } else {
                // Non-WAV conversion requires AudioRecorderService.convertToMonoWAV
                // which uses AVAssetReader + ExtAudioFile.
                // For now, copy the file and let the TTS engine handle it.
                try FileManager.default.copyItem(at: url, to: destURL)
            }
            referenceAudioURL = destURL
            state = .idle
        } catch {
            state = .error("Import failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Text-to-Speech Generation

    func generate() {
        guard !textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            state = .error("Please enter some text to speak")
            return
        }

        guard let referenceURL = referenceAudioURL else {
            state = .error("Please record or import a reference voice first")
            return
        }

        guard FileManager.default.fileExists(atPath: referenceURL.path) else {
            state = .error("Reference audio file not found")
            return
        }

        state = .generating(progress: 0)

        // Initialize engine if needed
        if ttsEngine == nil {
            let modelPath = modelDownloader.modelsDirectory.path
            let config = PocketTTSModelConfig.defaultConfig(modelPath: modelPath)
            do {
                ttsEngine = try TTSEngine(config: config)
            } catch {
                state = .error("Failed to initialize TTS: \(error.localizedDescription)")
                return
            }
        }

        Task {
            do {
                guard let engine = ttsEngine else {
                    state = .error("TTS engine not available")
                    return
                }

                let outputURL = try await engine.generate(
                    text: textInput,
                    referenceAudioURL: referenceURL,
                    config: settings
                ) { [weak self] progress in
                    Task { @MainActor in
                        self?.state = .generating(progress: progress)
                    }
                }

                let duration = await getAudioDuration(url: outputURL)
                generatedAudioURL = outputURL
                state = .completed(audioPath: outputURL.path, duration: duration)

            } catch {
                state = .error("Generation failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Playback

    func playGenerated() {
        guard let url = generatedAudioURL else { return }
        do {
            try player.play(url: url)
            state = .playing
        } catch {
            state = .error("Playback failed: \(error.localizedDescription)")
        }
    }

    func stopPlayback() {
        player.stop()
        if case .playing = state {
            state = .completed(audioPath: generatedAudioURL?.path ?? "", duration: 0)
        }
    }

    // MARK: - Export

    func exportToDocuments() -> URL? {
        guard let url = generatedAudioURL else { return nil }
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let exportsDir = documents.appendingPathComponent("exports")
        try? FileManager.default.createDirectory(at: exportsDir, withIntermediateDirectories: true)

        let exportURL = exportsDir.appendingPathComponent("PocketTTS_\(Date().timeIntervalSince1970).wav")
        try? FileManager.default.copyItem(at: url, to: exportURL)
        return exportURL
    }

    // MARK: - Reset

    func reset() {
        state = .idle
        generatedAudioURL = nil
        player.stop()
    }

    // MARK: - Private Helpers

    private func getAudioDuration(url: URL) async -> TimeInterval {
        let asset = AVAsset(url: url)
        return (try? await asset.load(.duration).seconds) ?? 0
    }

    private func loadSavedVoices() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url = documents.appendingPathComponent("voices.json")
        guard let data = try? Data(contentsOf: url),
              let voices = try? JSONDecoder().decode([VoiceProfile].self, from: data) else {
            return
        }
        savedVoices = voices
    }

    private func saveVoices() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url = documents.appendingPathComponent("voices.json")
        guard let data = try? JSONEncoder().encode(savedVoices) else { return }
        try? data.write(to: url)
    }
}
