import Foundation

final class ModelDownloader: ObservableObject {
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0
    @Published var downloadStatus = ""

    private let modelBaseURL = "https://huggingface.co/csukuangfj2/sherpa-onnx-pocket-tts-int8-2026-01-26/resolve/main"
    private let session: URLSession

    // All model files needed for Pocket TTS
    private let modelFiles = [
        "lm_flow.int8.onnx",
        "lm_main.int8.onnx",
        "encoder.onnx",
        "decoder.int8.onnx",
        "text_conditioner.onnx",
        "vocab.json",
        "token_scores.json"
    ]

    // Test reference audio for voice cloning
    private let testWavFiles = [
        "test_wavs/bria.wav"
    ]

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 3600
        self.session = URLSession(configuration: config)
    }

    /// Local directory for storing models
    var modelsDirectory: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documents.appendingPathComponent("models/sherpa-onnx-pocket-tts-int8-2026-01-26")
    }

    var testWavsDirectory: URL {
        return modelsDirectory.appendingPathComponent("test_wavs")
    }

    /// Check if models are already downloaded
    var isModelDownloaded: Bool {
        let modelPath = modelsDirectory.path
        return modelFiles.allSatisfy { FileManager.default.fileExists(atPath: "\(modelPath)/\($0)") }
    }

    /// Download all model files
    func downloadModels(progressHandler: @escaping (Double, String) -> Void) async throws -> String {
        await MainActor.run {
            isDownloading = true
            downloadProgress = 0
            downloadStatus = "Starting download..."
        }

        let fileManager = FileManager.default
        let modelPath = modelsDirectory.path
        let wavPath = testWavsDirectory.path

        try fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: testWavsDirectory, withIntermediateDirectories: true)

        let allFiles = modelFiles.map { ("", $0) } + testWavFiles.map { ("test_wavs", $0) }
        let totalFiles = Double(allFiles.count)
        var completedFiles = 0.0

        for (subdir, filename) in allFiles {
            let url = URL(string: "\(modelBaseURL)/\(subdir)\(subdir.isEmpty ? "" : "/")\(filename)")!
            let destDir = subdir.isEmpty ? modelPath : "\(modelPath)/\(subdir)"
            let destURL = URL(fileURLWithPath: "\(destDir)/\(filename)")

            if fileManager.fileExists(atPath: destURL.path) {
                completedFiles += 1
                let progress = completedFiles / totalFiles
                await MainActor.run {
                    downloadProgress = progress
                    downloadStatus = "\(filename) already exists"
                }
                continue
            }

            await MainActor.run {
                downloadStatus = "Downloading \(filename)..."
            }

            try await downloadFile(url: url, to: destURL) { bytesWritten, totalBytes in
                let fileProgress = totalBytes > 0 ? Double(bytesWritten) / Double(totalBytes) : 0
                let overallProgress = (completedFiles + fileProgress) / totalFiles
                DispatchQueue.main.async {
                    self.downloadProgress = overallProgress
                }
            }

            completedFiles += 1
            let progress = completedFiles / totalFiles
            await MainActor.run {
                downloadProgress = progress
                downloadStatus = "Downloaded \(filename)"
            }
        }

        await MainActor.run {
            isDownloading = false
            downloadStatus = "All models downloaded successfully"
        }

        return modelPath
    }

    private func downloadFile(
        url: URL,
        to destination: URL,
        progressHandler: @escaping (Int64, Int64) -> Void
    ) async throws {
        let request = URLRequest(url: url)
        let (tempURL, response) = try await session.download(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let totalBytes = httpResponse.expectedContentLength
        let fileHandle = try FileHandle(forReadingFrom: tempURL)
        defer { try? fileHandle.close() }

        // Copy with progress
        let bufferSize = 1024 * 1024 // 1MB chunks
        var bytesRead: Int64 = 0

        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }

        FileManager.default.createFile(atPath: destination.path, contents: nil)
        let outputHandle = try FileHandle(forWritingTo: destination)
        defer { try? outputHandle.close() }

        while true {
            let data = try fileHandle.read(upToCount: bufferSize)
            guard let chunk = data, !chunk.isEmpty else { break }
            try outputHandle.write(contentsOf: chunk)
            bytesRead += Int64(chunk.count)
            if totalBytes > 0 {
                progressHandler(bytesRead, totalBytes)
            }
        }
    }
}
