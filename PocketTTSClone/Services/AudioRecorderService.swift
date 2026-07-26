import Foundation
import AVFoundation

final class AudioRecorderService: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var recordedFileURL: URL?

    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?

    private let settings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatLinearPCM),
        AVSampleRateKey: 44100.0,
        AVNumberOfChannelsKey: 1,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false
    ]

    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    // MARK: - Recording

    func startRecording() throws -> URL {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        let voicesDir = documentsDirectory.appendingPathComponent("voices")
        try FileManager.default.createDirectory(at: voicesDir, withIntermediateDirectories: true)

        let recordingURL = voicesDir
            .appendingPathComponent("reference_\(Int(Date().timeIntervalSince1970)).wav")

        audioRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
        audioRecorder?.delegate = self
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.record()

        isRecording = true
        recordedFileURL = recordingURL
        recordingDuration = 0

        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let recorder = self.audioRecorder else { return }
            self.recordingDuration = recorder.currentTime
        }

        return recordingURL
    }

    func stopRecording() -> URL? {
        recordingTimer?.invalidate()
        recordingTimer = nil
        audioRecorder?.stop()
        isRecording = false
        guard let url = recordedFileURL,
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    func deleteRecording(at url: URL) {
        try? FileManager.default.removeItem(at: url)
        if recordedFileURL == url { recordedFileURL = nil }
    }

    // MARK: - Audio Conversion (for imported non-WAV files)

    /// Convert any audio to 16-bit mono WAV at 44100 Hz using ExtAudioFile
    static func convertToMonoWAV(sourceURL: URL) async throws -> URL {
        let asset = AVAsset(url: sourceURL)
        guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw AppError.audioRead("No audio track found in source file")
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("converted_\(UUID().uuidString).wav")

        // Set up WAV output format
        var audioFormat = AudioStreamBasicDescription(
            mSampleRate: 44100,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 2,
            mFramesPerPacket: 1,
            mBytesPerFrame: 2,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 16,
            mReserved: 0
        )

        // Create ExtAudioFile for WAV output
        var extAudioFile: ExtAudioFileRef?
        let urlCF = outputURL as CFURL
        let createStatus = ExtAudioFileCreateWithURL(
            urlCF,
            kAudioFileWAVEType,
            &audioFormat,
            nil,
            AudioFileFlags.eraseFile.rawValue,
            &extAudioFile
        )

        guard createStatus == noErr, let file = extAudioFile else {
            throw AppError.conversion("Could not create output WAV file (error: \(createStatus))")
        }

        defer { ExtAudioFileDispose(file) }

        // Set client format matching our target
        var clientFormat = audioFormat
        ExtAudioFileSetProperty(
            file,
            kExtAudioFileProperty_ClientDataFormat,
            UInt32(MemoryLayout<AudioStreamBasicDescription>.size),
            &clientFormat
        )

        // Set up AVAssetReader to read source audio
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false
        ])
        reader.add(output)
        reader.startReading()

        guard reader.status == .reading else {
            throw AppError.conversion("Failed to read audio (status: \(reader.status.rawValue))")
        }

        // Read and write in chunks

        while true {
            guard let sampleBuffer = output.copyNextSampleBuffer() else { break }

            guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
                CMSampleBufferInvalidate(sampleBuffer)
                break
            }

            var dataPointer: UnsafeMutablePointer<Int8>?
            var dataLength: Int = 0
            CMBlockBufferGetDataPointer(
                blockBuffer, atOffset: 0,
                lengthAtOffsetOut: nil,
                totalLengthOut: &dataLength,
                dataPointerOut: &dataPointer
            )

            if let data = dataPointer, dataLength > 0 {
                let frameCount = UInt32(dataLength) / 2 // 16-bit = 2 bytes per frame
                let audioBuffer = AudioBuffer(
                    mNumberChannels: 1,
                    mDataByteSize: UInt32(dataLength),
                    mData: UnsafeMutableRawPointer(data)
                )
                var bufferList = AudioBufferList(
                    mNumberBuffers: 1,
                    mBuffers: audioBuffer
                )

                ExtAudioFileWrite(file, frameCount, &bufferList)
            }

            CMSampleBufferInvalidate(sampleBuffer)
        }

        if reader.status == .reading {
            reader.cancelReading()
        }

        return outputURL
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioRecorderService: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag { print("Recording finished with errors"); isRecording = false }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error { print("Recording encode error: \(error.localizedDescription)") }
        isRecording = false
    }
}
