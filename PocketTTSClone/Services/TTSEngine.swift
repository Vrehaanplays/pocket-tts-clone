import Foundation
import AVFoundation

// MARK: - Swift wrapper for sherpa-onnx Pocket TTS C API
//
// This wraps the C API functions from PocketTTS-Bridging-Header.h
// into a clean Swift interface.

// MARK: - Model Configuration

struct PocketTTSModelConfig {
    let lmFlow: String
    let lmMain: String
    let encoder: String
    let decoder: String
    let textConditioner: String
    let vocabJson: String
    let tokenScoresJson: String

    var isValid: Bool {
        let paths = [lmFlow, lmMain, encoder, decoder, textConditioner, vocabJson, tokenScoresJson]
        return paths.allSatisfy { FileManager.default.fileExists(atPath: $0) }
    }

    static var defaultModelPath: String {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documents.appendingPathComponent("models/sherpa-onnx-pocket-tts-int8-2026-01-26").path
    }

    static func defaultConfig(modelPath: String) -> PocketTTSModelConfig {
        PocketTTSModelConfig(
            lmFlow: "\(modelPath)/lm_flow.int8.onnx",
            lmMain: "\(modelPath)/lm_main.int8.onnx",
            encoder: "\(modelPath)/encoder.onnx",
            decoder: "\(modelPath)/decoder.int8.onnx",
            textConditioner: "\(modelPath)/text_conditioner.onnx",
            vocabJson: "\(modelPath)/vocab.json",
            tokenScoresJson: "\(modelPath)/token_scores.json"
        )
    }
}

// MARK: - TTS Engine

final class TTSEngine {
    private var tts: OpaquePointer?
    private let config: PocketTTSModelConfig
    private let queue = DispatchQueue(label: "com.pockettts.engine", qos: .userInitiated)

    init(config: PocketTTSModelConfig) throws {
        self.config = config
        try initialize()
    }

    deinit {
        destroy()
    }

    // MARK: - Engine Lifecycle

    private func initialize() throws {
        guard config.isValid else {
            throw AppError.modelNotFound(
                "One or more Pocket TTS model files are missing at: \(PocketTTSModelConfig.defaultModelPath)"
            )
        }

        var pocketConfig = SherpaOnnxOfflineTtsPocketModelConfig()
        // Retain copies so they stay alive
        let lmFlowC = (config.lmFlow as NSString).utf8String.map { UnsafePointer(strdup($0)) }
        let lmMainC = (config.lmMain as NSString).utf8String.map { UnsafePointer(strdup($0)) }
        let encoderC = (config.encoder as NSString).utf8String.map { UnsafePointer(strdup($0)) }
        let decoderC = (config.decoder as NSString).utf8String.map { UnsafePointer(strdup($0)) }
        let textCondC = (config.textConditioner as NSString).utf8String.map { UnsafePointer(strdup($0)) }
        let vocabC = (config.vocabJson as NSString).utf8String.map { UnsafePointer(strdup($0)) }
        let tokenC = (config.tokenScoresJson as NSString).utf8String.map { UnsafePointer(strdup($0)) }

        pocketConfig.lm_flow = lmFlowC?.pointee
        pocketConfig.lm_main = lmMainC?.pointee
        pocketConfig.encoder = encoderC?.pointee
        pocketConfig.decoder = decoderC?.pointee
        pocketConfig.text_conditioner = textCondC?.pointee
        pocketConfig.vocab_json = vocabC?.pointee
        pocketConfig.token_scores_json = tokenC?.pointee
        pocketConfig.voice_embedding_cache_capacity = 50

        var modelConfig = SherpaOnnxOfflineTtsModelConfig()
        modelConfig.pocket = pocketConfig
        modelConfig.num_threads = 2
        modelConfig.debug = 0

        let providerC = ("cpu" as NSString).utf8String.map { UnsafePointer(strdup($0)) }
        modelConfig.provider = providerC?.pointee

        var ttsConfig = SherpaOnnxOfflineTtsConfig()
        ttsConfig.model = modelConfig
        ttsConfig.max_num_sentences = 1
        ttsConfig.silence_scale = 0.2

        guard let engine = SherpaOnnxCreateOfflineTts(&ttsConfig) else {
            // Clean up allocated strings on failure
            [lmFlowC, lmMainC, encoderC, decoderC, textCondC, vocabC, tokenC, providerC].compactMap { $0 }.forEach {
                free(UnsafeMutablePointer(mutating: $0.pointee))
            }
            throw AppError.engine("SherpaOnnxCreateOfflineTts returned nil")
        }

        self.tts = engine

        // We can free the duplicated strings now since the engine copies internally
        [lmFlowC, lmMainC, encoderC, decoderC, textCondC, vocabC, tokenC, providerC].compactMap { $0 }.forEach {
            free(UnsafeMutablePointer(mutating: $0.pointee))
        }

        print("Pocket TTS engine initialized successfully")
    }

    private func destroy() {
        guard let tts = tts else { return }
        SherpaOnnxDestroyOfflineTts(tts)
        self.tts = nil
        retainedStrings.removeAll()
        print("Pocket TTS engine destroyed")
    }

    // MARK: - Voice Cloning Generation

    func generate(
        text: String,
        referenceAudioURL: URL,
        config: GenerationConfig = GenerationConfig(),
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> URL {
        guard let tts = tts else {
            throw AppError.engine("Engine not initialized")
        }

        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: AppError.engine("Engine deallocated"))
                    return
                }

                // Read reference audio
                guard let wave = SherpaOnnxReadWave(referenceAudioURL.path) else {
                    continuation.resume(throwing: AppError.audioRead(
                        "Could not read \(referenceAudioURL.lastPathComponent). Ensure it is a 16-bit 16-48kHz mono WAV."
                    ))
                    return
                }

                // MUST clean up wave before exiting
                defer { SherpaOnnxFreeWave(UnsafeMutablePointer(mutating: wave)) }

                var genConfig = SherpaOnnxGenerationConfig()
                genConfig.speed = config.speed
                genConfig.silence_scale = config.silence_scale
                genConfig.num_steps = config.numSteps
                genConfig.reference_audio = wave.pointee.samples
                genConfig.reference_audio_len = wave.pointee.num_samples
                genConfig.reference_sample_rate = wave.pointee.sample_rate

                let extraJSON = """
                {"max_reference_audio_len": \(config.maxReferenceAudioLen), "seed": \(config.seed)}
                """
                let extraC = (extraJSON as NSString).utf8String.map { UnsafePointer(strdup($0)) }
                genConfig.extra = extraC?.pointee

                // The C API callback is: int32_t callback(const float*, int32_t, float, void*)
                // The 4th argument is the combined callback, 5th is user data
                let callback: SherpaOnnxGeneratedAudioProgressCallbackWithArg = { _, _, progress, _ in
                    if let handler = progressHandler {
                        DispatchQueue.main.async {
                            handler(Double(progress))
                        }
                    }
                    return 1 // continue
                }

                // SherpaOnnxOfflineTtsGenerateWithConfig takes 5 arguments:
                // (tts, text, &config, callback, user_data)
                guard let audio = SherpaOnnxOfflineTtsGenerateWithConfig(
                    tts,
                    text,
                    &genConfig,
                    callback,
                    nil
                ) else {
                    if let cPtr = extraC { free(UnsafeMutablePointer(mutating: cPtr.pointee)) }
                    continuation.resume(throwing: AppError.generation("Generation returned nil"))
                    return
                }

                if let cPtr = extraC { free(UnsafeMutablePointer(mutating: cPtr.pointee)) }

                let outputDir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("com.pockettts.generated", isDirectory: true)
                try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

                let outputURL = outputDir
                    .appendingPathComponent("\(UUID().uuidString).wav")

                let result = SherpaOnnxWriteWave(
                    audio.pointee.samples,
                    audio.pointee.n,
                    audio.pointee.sample_rate,
                    outputURL.path
                )

                // Free the generated audio
                let mutableAudio = UnsafeMutablePointer(mutating: audio)
                SherpaOnnxDestroyOfflineTtsGeneratedAudio(mutableAudio)

                if result == 0 {
                    continuation.resume(returning: outputURL)
                } else {
                    continuation.resume(throwing: AppError.generation("Failed to write output WAV (code: \(result))"))
                }
            }
        }
    }

    // MARK: - Direct Generation (without voice cloning)

    func generateDefault(text: String, speed: Float = 1.0) async throws -> URL {
        guard let tts = tts else {
            throw AppError.engine("Engine not initialized")
        }

        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                var genConfig = SherpaOnnxGenerationConfig()
                genConfig.speed = speed
                genConfig.silence_scale = 0.2

                guard let audio = SherpaOnnxOfflineTtsGenerateWithConfig(
                    tts, text, &genConfig, nil, nil
                ) else {
                    continuation.resume(throwing: AppError.generation("Generation returned nil"))
                    return
                }

                let outputDir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("com.pockettts.generated", isDirectory: true)
                try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

                let outputURL = outputDir
                    .appendingPathComponent("\(UUID().uuidString).wav")

                SherpaOnnxWriteWave(
                    audio.pointee.samples,
                    audio.pointee.n,
                    audio.pointee.sample_rate,
                    outputURL.path
                )

                let mutableAudio = UnsafeMutablePointer(mutating: audio)
                SherpaOnnxDestroyOfflineTtsGeneratedAudio(mutableAudio)

                continuation.resume(returning: outputURL)
            }
        }
    }
}
