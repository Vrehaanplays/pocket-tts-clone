import Foundation

// MARK: - Shared App Errors

enum AppError: LocalizedError {
    case engine(String)
    case generation(String)
    case audioRead(String)
    case audioWrite(String)
    case modelNotFound(String)
    case noReferenceAudio
    case recording(String)
    case conversion(String)
    case download(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .engine(let msg): return "Engine error: \(msg)"
        case .generation(let msg): return "Generation failed: \(msg)"
        case .audioRead(let msg): return "Could not read audio: \(msg)"
        case .audioWrite(let msg): return "Could not write audio: \(msg)"
        case .modelNotFound(let path): return "Model file not found at: \(path)"
        case .noReferenceAudio: return "No reference audio provided for voice cloning"
        case .recording(let msg): return "Recording error: \(msg)"
        case .conversion(let msg): return "Audio conversion error: \(msg)"
        case .download(let msg): return "Download error: \(msg)"
        case .unknown(let msg): return "Error: \(msg)"
        }
    }
}
