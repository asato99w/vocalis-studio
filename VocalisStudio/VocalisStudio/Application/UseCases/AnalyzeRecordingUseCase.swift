import Foundation
import VocalisDomain

/// Protocol for audio file analysis
public protocol AudioFileAnalyzerProtocol {
    /// Analyze audio file and return pitch and spectrogram data
    /// - Parameters:
    ///   - fileURL: URL of audio file to analyze
    ///   - progress: Callback for progress updates (0.0 to 1.0), called on MainActor
    func analyze(fileURL: URL, progress: @escaping @MainActor (Double) async -> Void) async throws -> (pitchData: PitchAnalysisData, spectrogramData: SpectrogramData)
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
    private let logger: LoggerProtocol

    public init(
        audioFileAnalyzer: AudioFileAnalyzerProtocol,
        analysisCache: AnalysisCacheProtocol,
        logger: LoggerProtocol
    ) {
        self.audioFileAnalyzer = audioFileAnalyzer
        self.analysisCache = analysisCache
        self.logger = logger
    }

    /// Analyze recording and return analysis result
    /// - Parameters:
    ///   - recording: Recording to analyze
    ///   - progress: Callback for progress updates (0.0 to 1.0), called on MainActor
    /// - Returns: Analysis result with pitch and spectrogram data
    /// - Throws: Error if file reading or analysis fails
    public func execute(recording: Recording, progress: @escaping @MainActor (Double) -> Void = { _ in }) async throws -> AnalysisResult {
        logger.info("Starting analysis for recording: \(recording.id.value.uuidString)", category: "useCase")

        // Check cache first
        if let cachedResult = analysisCache.get(recording.id) {
            logger.info("Cache hit for recording: \(recording.id.value.uuidString)", category: "useCase")
            // Report 100% progress for cached results
            await progress(1.0)
            return cachedResult
        }

        logger.info("Cache miss - analyzing file: \(recording.fileURL.path)", category: "useCase")

        // Analyze audio file with progress reporting
        let (pitchData, spectrogramData) = try await audioFileAnalyzer.analyze(fileURL: recording.fileURL, progress: progress)

        // Create analysis result
        let result = AnalysisResult(
            pitchData: pitchData,
            spectrogramData: spectrogramData,
            scaleSettings: recording.scaleSettings
        )

        // Cache the result
        analysisCache.set(recording.id, result: result)

        logger.info("Analysis completed for recording: \(recording.id.value.uuidString)", category: "useCase")

        return result
    }
}
