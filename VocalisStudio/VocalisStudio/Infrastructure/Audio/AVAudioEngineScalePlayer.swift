import Foundation
import VocalisDomain
import AVFoundation
import OSLog

/// Scale player implementation using AVAudioEngine and AVAudioUnitSampler
/// Now supports ScaleElement for chord playback
public class AVAudioEngineScalePlayer: ScalePlayerProtocol {
    private let engine: AVAudioEngine
    private let sampler: AVAudioUnitSampler
    private var scale: [MIDINote] = []  // Legacy support
    private var scaleElements: [ScaleElement] = []  // New chord-enabled playback
    private var tempo: Tempo?
    private var playbackTask: Task<Void, Error>?
    private var _currentNoteIndex: Int = 0
    private var _isPlaying: Bool = false

    public var isPlaying: Bool {
        _isPlaying
    }

    public var currentNoteIndex: Int {
        _currentNoteIndex
    }

    public var progress: Double {
        let totalCount = scaleElements.isEmpty ? scale.count : scaleElements.count
        guard totalCount > 0 else { return 0.0 }
        // Progress is 0.0 at start, 1.0 at completion
        // During playback: currentNoteIndex ranges from 0 to totalCount-1
        // After completion: currentNoteIndex = totalCount
        return min(1.0, Double(_currentNoteIndex) / Double(totalCount))
    }

    public var currentScaleElement: ScaleElement? {
        Logger.scalePlayer.info("[currentScaleElement] Called: _isPlaying=\(self._isPlaying), _currentNoteIndex=\(self._currentNoteIndex), scaleElements.count=\(self.scaleElements.count)")

        guard _isPlaying else {
            Logger.scalePlayer.info("[currentScaleElement] Return nil: _isPlaying is false")
            return nil
        }
        guard _currentNoteIndex >= 0 else {
            Logger.scalePlayer.info("[currentScaleElement] Return nil: _currentNoteIndex < 0")
            return nil
        }

        if !scaleElements.isEmpty {
            guard _currentNoteIndex < scaleElements.count else {
                Logger.scalePlayer.info("[currentScaleElement] Return nil: _currentNoteIndex >= scaleElements.count")
                return nil
            }
            let element = scaleElements[_currentNoteIndex]
            Logger.scalePlayer.info("[currentScaleElement] Return element at index \(self._currentNoteIndex)")
            return element
        } else if !scale.isEmpty {
            guard _currentNoteIndex < scale.count else {
                Logger.scalePlayer.info("[currentScaleElement] Return nil: _currentNoteIndex >= scale.count")
                return nil
            }
            let element = ScaleElement.scaleNote(scale[_currentNoteIndex])
            Logger.scalePlayer.info("[currentScaleElement] Return legacy element at index \(self._currentNoteIndex)")
            return element
        }
        Logger.scalePlayer.info("[currentScaleElement] Return nil: both scaleElements and scale are empty")
        return nil
    }

    public init() {
        engine = AVAudioEngine()
        sampler = AVAudioUnitSampler()

        // Connect sampler to engine's main mixer
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)

        // Set volume to maximum for playback
        engine.mainMixerNode.outputVolume = 1.0
    }

    public func loadScale(_ notes: [MIDINote], tempo: Tempo) async throws {
        self.scale = notes
        self.scaleElements = []  // Clear new format
        self.tempo = tempo
        self._currentNoteIndex = 0

        try await loadSoundBank()
    }

    /// Load scale elements with chord support (new format)
    public func loadScaleElements(_ elements: [ScaleElement], tempo: Tempo) async throws {
        self.scaleElements = elements
        self.scale = []  // Clear legacy format
        self.tempo = tempo
        self._currentNoteIndex = 0

        try await loadSoundBank()
    }

    /// Load audio unit preset for piano sound
    private func loadSoundBank() async throws {
        do {
            #if targetEnvironment(simulator)
            // iOS Simulator: use DLS sound bank (like macOS)
            // Simulator doesn't have factory presets but can access DLS files
            try sampler.loadSoundBankInstrument(
                at: URL(fileURLWithPath: "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls"),
                program: 0,
                bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                bankLSB: UInt8(kAUSampler_DefaultBankLSB)
            )
            #elseif os(iOS)
            // Real iOS device: use AUAudioUnit factory presets
            if let pianoPreset = sampler.auAudioUnit.factoryPresets?.first(where: { $0.name.contains("Piano") }) {
                sampler.auAudioUnit.currentPreset = pianoPreset
            } else if let firstPreset = sampler.auAudioUnit.factoryPresets?.first {
                sampler.auAudioUnit.currentPreset = firstPreset
            }
            #else
            // macOS: load DLS sound bank
            try sampler.loadSoundBankInstrument(
                at: URL(fileURLWithPath: "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls"),
                program: 0,
                bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                bankLSB: UInt8(kAUSampler_DefaultBankLSB)
            )
            #endif
        } catch {
            // Continue anyway - sampler will use default sound
        }
    }

    public func play(muted: Bool = false) async throws {
        guard tempo != nil else {
            throw ScalePlayerError.notLoaded
        }

        guard !_isPlaying else {
            throw ScalePlayerError.alreadyPlaying
        }

        // Set output volume based on muted parameter
        engine.mainMixerNode.outputVolume = muted ? 0.0 : 1.0

        // Choose playback mode based on what's loaded
        if !scaleElements.isEmpty {
            try await playScaleElements()
        } else if !scale.isEmpty {
            try await playLegacyScale()
        } else {
            // Empty scale completes immediately
            _currentNoteIndex = 0
            return
        }
    }

    /// Play scale elements with chord support (new format)
    private func playScaleElements() async throws {
        _isPlaying = true
        Logger.scalePlayer.info("[playScaleElements] Set _isPlaying=true, scaleElements.count=\(self.scaleElements.count)")

        do {
            // Ensure audio session is active before starting engine
            try AudioSessionManager.shared.activateIfNeeded()

            try engine.start()
            Logger.scalePlayer.info("[playScaleElements] Engine started successfully")

            playbackTask = Task { [weak self] in
                guard let self = self else {
                    Logger.scalePlayer.info("[playScaleElements] Task: self is nil")
                    return
                }
                Logger.scalePlayer.info("[playScaleElements] Task: Started, scaleElements.count=\(scaleElements.count)")
                do {
                    for (index, element) in scaleElements.enumerated() {
                        try Task.checkCancellation()
                        Logger.scalePlayer.info("[playScaleElements] Task: Setting _currentNoteIndex=\(index)")
                        self._currentNoteIndex = index

                        switch element {
                        case .chordShort(let notes):
                            // Play chord for 0.3s
                            try await self.playChord(notes, duration: 0.3)

                        case .chordLong(let notes):
                            // Play chord for 1.0s
                            try await self.playChord(notes, duration: 1.0)

                        case .scaleNote(let note):
                            // Play single note with tempo duration
                            try await self.playNote(note, duration: self.tempo!.secondsPerNote)

                        case .silence(let duration):
                            // Silent gap
                            try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                        }
                    }

                    // Playback completed
                    self._currentNoteIndex = scaleElements.count
                    self._isPlaying = false
                    self.engine.stop()
                } catch {
                    // Task cancelled or other error
                    self._isPlaying = false
                    self.engine.stop()
                }
            }

            // Don't wait for playback to complete - return immediately
        } catch is CancellationError {
            _isPlaying = false
        } catch {
            _isPlaying = false
            throw ScalePlayerError.playbackFailed(error.localizedDescription)
        }
    }

    /// Play legacy scale format (single notes only)
    private func playLegacyScale() async throws {
        _isPlaying = true

        do {
            // Ensure audio session is active before starting engine
            try AudioSessionManager.shared.activateIfNeeded()

            try engine.start()

            playbackTask = Task { [weak self] in
                guard let self = self else { return }
                do {
                    for (index, note) in scale.enumerated() {
                        try Task.checkCancellation()
                        self._currentNoteIndex = index

                        // Play note (legato: stop previous note just before next one plays)
                        self.sampler.startNote(note.value, withVelocity: 64, onChannel: 0)

                        // Most of the note duration
                        try await Task.sleep(nanoseconds: UInt64(self.tempo!.secondsPerNote * 0.9 * 1_000_000_000))

                        self.sampler.stopNote(note.value, onChannel: 0)

                        // Small gap between notes
                        try await Task.sleep(nanoseconds: UInt64(self.tempo!.secondsPerNote * 0.1 * 1_000_000_000))
                    }

                    // Playback completed
                    self._currentNoteIndex = scale.count
                    self._isPlaying = false
                    self.engine.stop()
                } catch {
                    // Task cancelled or other error
                    self._isPlaying = false
                    self.engine.stop()
                }
            }

            // Don't wait for playback to complete - return immediately
        } catch is CancellationError {
            _isPlaying = false
        } catch {
            _isPlaying = false
            throw ScalePlayerError.playbackFailed(error.localizedDescription)
        }
    }

    /// Play a single note with specified duration
    private func playNote(_ note: MIDINote, duration: TimeInterval) async throws {
        // Start note
        sampler.startNote(note.value, withVelocity: 64, onChannel: 0)

        // Play for most of the duration (90%)
        try await Task.sleep(nanoseconds: UInt64(duration * 0.9 * 1_000_000_000))

        // Stop note
        sampler.stopNote(note.value, onChannel: 0)

        // Small gap (10%)
        try await Task.sleep(nanoseconds: UInt64(duration * 0.1 * 1_000_000_000))
    }

    /// Play multiple notes simultaneously (chord)
    private func playChord(_ notes: [MIDINote], duration: TimeInterval) async throws {
        // Start all notes simultaneously
        for note in notes {
            sampler.startNote(note.value, withVelocity: 64, onChannel: 0)
        }

        // Play for most of the duration (90%)
        try await Task.sleep(nanoseconds: UInt64(duration * 0.9 * 1_000_000_000))

        // Stop all notes simultaneously
        for note in notes {
            sampler.stopNote(note.value, onChannel: 0)
        }

        // Small gap (10%)
        try await Task.sleep(nanoseconds: UInt64(duration * 0.1 * 1_000_000_000))
    }

    public func stop() async {
        playbackTask?.cancel()
        playbackTask = nil
        _isPlaying = false
        engine.stop()

        // Stop all notes
        for channel in 0..<16 {
            for note in 0..<128 {
                sampler.stopNote(UInt8(note), onChannel: UInt8(channel))
            }
        }
    }
}
