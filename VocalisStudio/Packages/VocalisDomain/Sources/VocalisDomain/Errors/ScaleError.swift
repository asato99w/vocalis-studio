import Foundation

/// Errors related to scale settings and configuration
public enum ScaleError: Error, Equatable {
    /// Invalid note specified (out of valid MIDI range or unsuitable for scales)
    case invalidNote(String)

    /// Invalid range specified (e.g., start note higher than end note)
    case invalidRange(String)

    /// Invalid ascending count (outside allowed range)
    case invalidAscendingCount(String)

    /// Invalid tempo specified
    case invalidTempo(String)
}

// MARK: - LocalizedError

extension ScaleError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidNote(let message):
            return "無効な音符: \(message)"
        case .invalidRange(let message):
            return "無効な音域: \(message)"
        case .invalidAscendingCount(let message):
            return "無効な上昇回数: \(message)"
        case .invalidTempo(let message):
            return "無効なテンポ: \(message)"
        }
    }

    public var failureReason: String? {
        switch self {
        case .invalidNote:
            return "指定された音符がスケール練習に適していません"
        case .invalidRange:
            return "開始音が終了音より高く設定されています"
        case .invalidAscendingCount:
            return "上昇回数は1〜24の範囲で指定してください"
        case .invalidTempo:
            return "テンポの設定値が範囲外です"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .invalidNote:
            return "C3〜C6の範囲内の音符を選択してください"
        case .invalidRange:
            return "開始音を終了音より低く設定してください"
        case .invalidAscendingCount:
            return "1回（半音上昇）から24回（2オクターブ上昇）の範囲で設定してください"
        case .invalidTempo:
            return "1秒〜3秒の範囲で設定してください"
        }
    }
}
