import Foundation
import SwiftUI

// MARK: - Voice Profile

struct VoiceProfile: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var createdAt: Date
    var referenceAudioPath: String?
    var duration: TimeInterval
    var isDefault: Bool

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        referenceAudioPath: String? = nil,
        duration: TimeInterval = 0,
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.referenceAudioPath = referenceAudioPath
        self.duration = duration
        self.isDefault = isDefault
    }
}

// MARK: - TTS Generation State

enum TTSState: Equatable {
    case idle
    case recording
    case importing
    case generating(progress: Double)
    case completed(audioPath: String, duration: TimeInterval)
    case playing
    case paused
    case error(String)

    var isIdle: Bool { self == .idle }
    var isBusy: Bool {
        switch self {
        case .idle, .completed, .paused: return false
        default: return true
        }
    }
}

// MARK: - Generation Config

struct GenerationConfig {
    var speed: Float = 1.0
    var seed: Int32 = -1
    var maxReferenceAudioLen: Float = 10.0
    var numSteps: Int32 = 8
    var silenceScale: Float = 0.2
}


