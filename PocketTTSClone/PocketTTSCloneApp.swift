import SwiftUI
import AVFoundation

@main
struct PocketTTSCloneApp: App {
    @StateObject private var ttsViewModel = TTSViewModel()
    @Environment(\.colorScheme) private var colorScheme

    init() {
        configureAudioSession()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(ttsViewModel)
                .preferredColorScheme(.automatic)
                .onAppear {
                    // Request microphone permission early
                    AVAudioSession.sharedInstance().requestRecordPermission { granted in
                        if granted {
                            print("Microphone access granted")
                        } else {
                            print("Microphone access denied")
                        }
                    }
                }
        }
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers]
            )
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to configure audio session: \(error.localizedDescription)")
        }
    }
}
