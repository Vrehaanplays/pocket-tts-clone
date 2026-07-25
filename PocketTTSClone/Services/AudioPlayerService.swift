import Foundation
import AVFoundation

final class AudioPlayerService: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentDuration: TimeInterval = 0
    @Published var currentTime: TimeInterval = 0
    @Published var playbackProgress: Double = 0

    private(set) var currentFileURL: URL?
    private var audioPlayer: AVAudioPlayer?
    private var progressTimer: Timer?

    /// Play a WAV audio file
    func play(url: URL) throws {
        stop()

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)

        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.delegate = self
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()

        isPlaying = true
        currentFileURL = url
        currentDuration = audioPlayer?.duration ?? 0
        currentTime = 0

        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            self.currentTime = player.currentTime
            self.playbackProgress = player.duration > 0 ? player.currentTime / player.duration : 0
        }
    }

    /// Pause playback
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
    }

    /// Resume playback
    func resume() {
        audioPlayer?.play()
        isPlaying = true
    }

    /// Stop playback and clean up
    func stop() {
        progressTimer?.invalidate()
        progressTimer = nil
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentTime = 0
        playbackProgress = 0
    }

    /// Seek to a specific position (0.0 - 1.0)
    func seek(to progress: Double) {
        guard let player = audioPlayer, player.duration > 0 else { return }
        let time = progress * player.duration
        player.currentTime = time
        currentTime = time
        playbackProgress = progress
    }

    var isPaused: Bool {
        return !isPlaying && audioPlayer != nil
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioPlayerService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stop()
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let error = error {
            print("Audio player decode error: \(error.localizedDescription)")
        }
        stop()
    }
}
