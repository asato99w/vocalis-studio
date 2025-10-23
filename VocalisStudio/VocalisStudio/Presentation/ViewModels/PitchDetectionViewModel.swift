import Foundation
import VocalisDomain
import Combine

/// ViewModel for pitch detection functionality
/// Manages target pitch monitoring and real-time pitch detection during recording/playback
@MainActor
public class PitchDetectionViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published public private(set) var targetPitch: DetectedPitch?
    @Published public private(set) var detectedPitch: DetectedPitch?
    @Published public private(set) var pitchAccuracy: PitchAccuracy = .none

    // MARK: - Dependencies

    private let pitchDetector: PitchDetectorProtocol
    private let scalePlayer: ScalePlayerProtocol
    private let audioPlayer: AudioPlayerProtocol

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var progressMonitorTask: Task<Void, Never>?
    private var pitchDetectionTask: Task<Void, Never>?

    // MARK: - Initialization

    public init(
        pitchDetector: PitchDetectorProtocol,
        scalePlayer: ScalePlayerProtocol,
        audioPlayer: AudioPlayerProtocol
    ) {
        self.pitchDetector = pitchDetector
        self.scalePlayer = scalePlayer
        self.audioPlayer = audioPlayer

        setupPitchDetectorSubscription()
    }

    // MARK: - Setup

    private func setupPitchDetectorSubscription() {
        // Pitch detector updates will be polled during monitoring tasks
        // No publisher subscription needed
    }

    // MARK: - Public Methods

    /// Start monitoring target pitch during recording with scale playback
    public func startTargetPitchMonitoring(settings: ScaleSettings) async throws {
        // Load scale into player
        let scaleElements = settings.generateScaleWithKeyChange()
        try await scalePlayer.loadScaleElements(scaleElements, tempo: settings.tempo)

        // Start monitoring task
        progressMonitorTask = Task { [weak self] in
            guard let self = self else { return }
            while !Task.isCancelled {
                if let currentElement = self.scalePlayer.currentScaleElement {
                    await self.updateTargetPitchFromScaleElement(currentElement)
                } else {
                    await MainActor.run { self.targetPitch = nil }
                }
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
        }
    }

    /// Stop target pitch monitoring
    public func stopTargetPitchMonitoring() async {
        progressMonitorTask?.cancel()
        progressMonitorTask = nil
        targetPitch = nil
    }

    /// Start pitch detection during playback for analysis view
    public func startPlaybackPitchDetection(url: URL) async throws {
        // Start pitch detector
        try pitchDetector.startRealtimeDetection()

        // Monitor audio player progress
        pitchDetectionTask = Task { [weak self] in
            guard let self = self else { return }
            while !Task.isCancelled {
                let isPlaying = await MainActor.run { self.audioPlayer.isPlaying }
                guard isPlaying else { break }

                // Update pitch detection
                if let detected = self.pitchDetector.detectedPitch {
                    self.updateDetectedPitch(detected)
                }

                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            }
        }
    }

    /// Stop playback pitch detection
    public func stopPlaybackPitchDetection() {
        pitchDetectionTask?.cancel()
        pitchDetectionTask = nil
        pitchDetector.stopRealtimeDetection()
    }

    /// Reset all pitch detection state
    public func reset() {
        targetPitch = nil
        detectedPitch = nil
        pitchAccuracy = .none

        progressMonitorTask?.cancel()
        progressMonitorTask = nil
        pitchDetectionTask?.cancel()
        pitchDetectionTask = nil
    }

    // MARK: - Private Methods

    private func updateTargetPitchFromScaleElement(_ element: ScaleElement) {
        switch element {
        case .scaleNote(let note):
            let pitch = DetectedPitch.fromFrequency(
                note.frequency,
                confidence: 1.0
            )
            targetPitch = pitch

        case .chordLong(let notes), .chordShort(let notes):
            // Use root note of chord as target
            if let rootNote = notes.first {
                let pitch = DetectedPitch.fromFrequency(
                    rootNote.frequency,
                    confidence: 1.0
                )
                targetPitch = pitch
            } else {
                targetPitch = nil
            }

        case .silence:
            targetPitch = nil
        }
    }

    private func updateDetectedPitch(_ pitch: DetectedPitch?) {
        guard let pitch = pitch else {
            detectedPitch = nil
            pitchAccuracy = .none
            return
        }

        // Validate frequency is reasonable (avoid NaN/infinite in log calculation)
        guard pitch.frequency > 0 && pitch.frequency < 10000 else {
            detectedPitch = nil
            pitchAccuracy = .none
            return
        }

        // If we have a target pitch, calculate cents difference
        if let target = targetPitch {
            let targetFreq = target.frequency
            let detectedFreq = pitch.frequency

            guard targetFreq > 0 else {
                detectedPitch = pitch
                pitchAccuracy = .none
                return
            }

            let cents = Int(round(1200 * log2(detectedFreq / targetFreq)))

            detectedPitch = DetectedPitch(
                noteName: pitch.noteName,
                frequency: pitch.frequency,
                confidence: pitch.confidence,
                cents: cents
            )

            pitchAccuracy = PitchAccuracy.from(cents: cents)
        } else {
            detectedPitch = pitch
            pitchAccuracy = PitchAccuracy.from(cents: pitch.cents)
        }
    }

    deinit {
        progressMonitorTask?.cancel()
        pitchDetectionTask?.cancel()
    }
}
