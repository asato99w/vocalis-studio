import Foundation
import VocalisDomain
import OSLog

/// Protocol for audio file analysis
public protocol AudioFileAnalyzerProtocol {
    /// Analyze audio file and return pitch and spectrogram data
    func analyze(fileURL: URL) async throws -> (pitchData: PitchAnalysisData, spectrogramData: SpectrogramData)
}

/// Protocol for analysis result caching
public protocol AnalysisCacheProtocol {
    /// Get cached analysis result
    func get(_ id: RecordingId) -> AnalysisResult?

    /// Set analysis result to cache
    func set(_ id: RecordingId, result: AnalysisResult)

    /// Clear all cache
    func clear()
}

/// Use case for analyzing recorded audio files
/// Analyzes pitch and spectrogram data from audio files
@MainActor
public class AnalyzeRecordingUseCase {
    private let audioFileAnalyzer: AudioFileAnalyzerProtocol
    private let analysisCache: AnalysisCacheProtocol
    private let logger = Logger(subsystem: "com.kazuasato.VocalisStudio", category: "AnalyzeRecordingUseCase")

    public init(
        audioFileAnalyzer: AudioFileAnalyzerProtocol,
        analysisCache: AnalysisCacheProtocol
    ) {
        self.audioFileAnalyzer = audioFileAnalyzer
        self.analysisCache = analysisCache
    }

    /// Analyze recording and return analysis result
    /// - Parameter recording: Recording to analyze
    /// - Returns: Analysis result with pitch and spectrogram data
    /// - Throws: Error if file reading or analysis fails
    public func execute(recording: Recording) async throws -> AnalysisResult {
        logger.info("Starting analysis for recording: \(recording.id.value.uuidString)")

        // Check cache first
        if let cachedResult = analysisCache.get(recording.id) {
            logger.info("Cache hit for recording: \(recording.id.value.uuidString)")
            return cachedResult
        }

        logger.info("Cache miss - analyzing file: \(recording.fileURL.path)")

        // Analyze audio file
        let (pitchData, spectrogramData) = try await audioFileAnalyzer.analyze(fileURL: recording.fileURL)

        // Create analysis result
        let result = AnalysisResult(
            pitchData: pitchData,
            spectrogramData: spectrogramData,
            scaleSettings: recording.scaleSettings
        )

        // Cache the result
        analysisCache.set(recording.id, result: result)

        logger.info("Analysis completed for recording: \(recording.id.value.uuidString)")

        return result
    }
}
