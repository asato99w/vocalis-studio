# MVPアーキテクチャ設計 - Vocalis Studio

## ドキュメント情報
- **作成日**: 2025年10月4日
- **バージョン**: 1.0
- **対象**: MVP v0.1.0

## 1. アーキテクチャ概要

### 1.1 基本方針
- **Clean Architecture**: 依存関係の方向を外側→内側に厳格に制御
- **Domain-Driven Design**: ビジネスロジックをドメイン層で表現
- **Test-Driven Development**: テストファーストで実装
- **SOLID原則**: 保守性・拡張性の高い設計

### 1.2 レイヤー構成

```
┌─────────────────────────────────────┐
│      Presentation Layer             │  ← SwiftUI Views, ViewModels
│  (UI, User Interaction)             │
└──────────────┬──────────────────────┘
               │ depends on
┌──────────────▼──────────────────────┐
│      Application Layer              │  ← Use Cases
│  (Business Logic Orchestration)     │
└──────────────┬──────────────────────┘
               │ depends on
┌──────────────▼──────────────────────┐
│      Domain Layer                   │  ← Entities, Value Objects,
│  (Business Logic, Rules)            │     Repository Interfaces
└──────────────▲──────────────────────┘
               │ implements
┌──────────────┴──────────────────────┐
│      Infrastructure Layer           │  ← AVFoundation, FileManager
│  (External Systems, Frameworks)     │     Repository Implementations
└─────────────────────────────────────┘
```

## 2. Domain Layer（ドメイン層）

### 2.1 概要
ビジネスロジックの中核。フレームワークに依存せず、純粋なSwiftコードで記述。

### 2.2 Entities（エンティティ）

#### Recording（録音）
```swift
public struct Recording: Equatable, Identifiable {
    public let id: RecordingId
    public let fileURL: URL
    public let createdAt: Date
    public let duration: Duration
    public let scaleSettings: ScaleSettings

    public init(
        id: RecordingId = RecordingId(),
        fileURL: URL,
        createdAt: Date = Date(),
        duration: Duration,
        scaleSettings: ScaleSettings
    )
}
```

**責務**:
- 録音データの識別
- 録音メタデータの保持
- ビジネスルールの検証

#### ScaleSettings（スケール設定）
```swift
public struct ScaleSettings: Equatable {
    public let startNote: MIDINote
    public let endNote: MIDINote
    public let notePattern: NotePattern
    public let tempo: Tempo

    public init(
        startNote: MIDINote,
        endNote: MIDINote,
        notePattern: NotePattern,
        tempo: Tempo
    )

    // ビジネスロジック
    public func generateScale() -> [MIDINote]
    public var totalDuration: Duration { get }
}
```

**責務**:
- スケールパラメータの管理
- スケール音階の生成ロジック
- 総再生時間の計算

### 2.3 Value Objects（値オブジェクト）

#### RecordingId
```swift
public struct RecordingId: Equatable, Hashable {
    public let value: UUID
    public init(value: UUID = UUID())
}
```

#### MIDINote
```swift
public struct MIDINote: Equatable, Comparable {
    public let value: UInt8  // 0-127

    public init(_ value: UInt8) throws {
        guard value <= 127 else {
            throw MIDINoteError.outOfRange
        }
        self.value = value
    }

    public static let middleC = try! MIDINote(60)
    public static let hiC = try! MIDINote(72)
}
```

#### NotePattern
```swift
public enum NotePattern: Equatable {
    case fiveToneScale  // ドレミファソ (Root, +2, +4, +5, +7)

    public var intervals: [Int] {
        switch self {
        case .fiveToneScale:
            return [0, 2, 4, 5, 7]
        }
    }

    public func ascendingDescending() -> [Int] {
        // [0, 2, 4, 5, 7, 5, 4, 2, 0]
        let ascending = intervals
        let descending = intervals.dropFirst().dropLast().reversed()
        return ascending + descending
    }
}
```

#### Tempo
```swift
public struct Tempo: Equatable {
    public let secondsPerNote: Double

    public init(secondsPerNote: Double) throws {
        guard secondsPerNote > 0 else {
            throw TempoError.invalidValue
        }
        self.secondsPerNote = secondsPerNote
    }

    public static let standard = try! Tempo(secondsPerNote: 1.0)
}
```

#### Duration
```swift
public struct Duration: Equatable, Comparable {
    public let seconds: Double

    public init(seconds: Double) {
        self.seconds = max(0, seconds)
    }

    public var formatted: String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}
```

### 2.4 Repository Interfaces（リポジトリインターフェース）

#### RecordingRepositoryProtocol
```swift
public protocol RecordingRepositoryProtocol {
    func save(_ recording: Recording) async throws
    func findAll() async throws -> [Recording]
    func findById(_ id: RecordingId) async throws -> Recording?
    func delete(_ id: RecordingId) async throws
}
```

#### AudioFileRepositoryProtocol
```swift
public protocol AudioFileRepositoryProtocol {
    func saveAudioFile(from sourceURL: URL, recordingId: RecordingId) async throws -> URL
    func deleteAudioFile(at url: URL) async throws
    func audioFileExists(at url: URL) -> Bool
}
```

### 2.5 Domain Services（ドメインサービス）

#### ScaleGenerator（スケール生成サービス）
```swift
public protocol ScaleGeneratorProtocol {
    func generateScale(settings: ScaleSettings) -> [MIDINote]
}

public class ScaleGenerator: ScaleGeneratorProtocol {
    public func generateScale(settings: ScaleSettings) -> [MIDINote] {
        let pattern = settings.notePattern.ascendingDescending()
        var allNotes: [MIDINote] = []

        var currentRoot = settings.startNote.value
        while currentRoot <= settings.endNote.value {
            let scaleNotes = pattern.compactMap { interval in
                try? MIDINote(currentRoot + UInt8(interval))
            }
            allNotes.append(contentsOf: scaleNotes)
            currentRoot += 1  // 半音上昇
        }

        return allNotes
    }
}
```

## 3. Application Layer（アプリケーション層）

### 3.1 概要
ユースケースを実装。ドメインオブジェクトを組み合わせてビジネスフローを実現。

### 3.2 Use Cases

#### StartRecordingWithScaleUseCase
```swift
public protocol StartRecordingWithScaleUseCaseProtocol {
    func execute(settings: ScaleSettings) async throws -> RecordingSession
}

public class StartRecordingWithScaleUseCase: StartRecordingWithScaleUseCaseProtocol {
    private let scalePlayer: ScalePlayerProtocol
    private let audioRecorder: AudioRecorderProtocol

    public init(
        scalePlayer: ScalePlayerProtocol,
        audioRecorder: AudioRecorderProtocol
    ) {
        self.scalePlayer = scalePlayer
        self.audioRecorder = audioRecorder
    }

    public func execute(settings: ScaleSettings) async throws -> RecordingSession {
        // 1. スケール音階を生成
        let scale = ScaleGenerator().generateScale(settings: settings)

        // 2. 録音準備
        let recordingURL = try await audioRecorder.prepareRecording()

        // 3. スケール再生と録音を同時開始
        try await scalePlayer.loadScale(scale, tempo: settings.tempo)
        try await audioRecorder.startRecording()
        try await scalePlayer.play()

        // 4. セッション情報を返す
        return RecordingSession(
            recordingURL: recordingURL,
            settings: settings,
            startedAt: Date()
        )
    }
}
```

#### StopRecordingUseCase
```swift
public protocol StopRecordingUseCaseProtocol {
    func execute(session: RecordingSession) async throws -> Recording
}

public class StopRecordingUseCase: StopRecordingUseCaseProtocol {
    private let scalePlayer: ScalePlayerProtocol
    private let audioRecorder: AudioRecorderProtocol
    private let recordingRepository: RecordingRepositoryProtocol
    private let audioFileRepository: AudioFileRepositoryProtocol

    public func execute(session: RecordingSession) async throws -> Recording {
        // 1. 再生停止
        await scalePlayer.stop()

        // 2. 録音停止
        let duration = try await audioRecorder.stopRecording()

        // 3. 録音エンティティを作成
        let recording = Recording(
            fileURL: session.recordingURL,
            createdAt: session.startedAt,
            duration: Duration(seconds: duration),
            scaleSettings: session.settings
        )

        // 4. 永続化
        try await recordingRepository.save(recording)

        return recording
    }
}
```

#### GetAllRecordingsUseCase
```swift
public protocol GetAllRecordingsUseCaseProtocol {
    func execute() async throws -> [Recording]
}

public class GetAllRecordingsUseCase: GetAllRecordingsUseCaseProtocol {
    private let repository: RecordingRepositoryProtocol

    public init(repository: RecordingRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() async throws -> [Recording] {
        let recordings = try await repository.findAll()
        // 新しい順にソート
        return recordings.sorted { $0.createdAt > $1.createdAt }
    }
}
```

#### DeleteRecordingUseCase
```swift
public protocol DeleteRecordingUseCaseProtocol {
    func execute(recordingId: RecordingId) async throws
}

public class DeleteRecordingUseCase: DeleteRecordingUseCaseProtocol {
    private let recordingRepository: RecordingRepositoryProtocol
    private let audioFileRepository: AudioFileRepositoryProtocol

    public func execute(recordingId: RecordingId) async throws {
        // 1. 録音情報を取得
        guard let recording = try await recordingRepository.findById(recordingId) else {
            throw RecordingError.notFound
        }

        // 2. オーディオファイル削除
        try await audioFileRepository.deleteAudioFile(at: recording.fileURL)

        // 3. メタデータ削除
        try await recordingRepository.delete(recordingId)
    }
}
```

#### PlayRecordingUseCase
```swift
public protocol PlayRecordingUseCaseProtocol {
    func execute(recording: Recording) async throws
}

public class PlayRecordingUseCase: PlayRecordingUseCaseProtocol {
    private let audioPlayer: AudioPlayerProtocol

    public func execute(recording: Recording) async throws {
        guard audioFileRepository.audioFileExists(at: recording.fileURL) else {
            throw RecordingError.fileNotFound
        }

        try await audioPlayer.play(fileURL: recording.fileURL)
    }
}
```

### 3.3 Supporting Types

#### RecordingSession
```swift
public struct RecordingSession {
    public let recordingURL: URL
    public let settings: ScaleSettings
    public let startedAt: Date
}
```

## 4. Infrastructure Layer（インフラストラクチャ層）

### 4.1 概要
外部フレームワーク・システムとの連携を担当。ドメイン層のインターフェースを実装。

### 4.2 Audio Components

#### ScalePlayer（スケール再生）
```swift
public protocol ScalePlayerProtocol {
    func loadScale(_ notes: [MIDINote], tempo: Tempo) async throws
    func play() async throws
    func stop() async
    var isPlaying: Bool { get }
    var currentNoteIndex: Int { get }
    var progress: Double { get }  // 0.0 - 1.0
}

public class AVAudioEngineScalePlayer: ScalePlayerProtocol {
    private let engine: AVAudioEngine
    private let sampler: AVAudioUnitSampler
    private var scale: [MIDINote] = []
    private var tempo: Tempo = .standard
    private var playbackTask: Task<Void, Error>?

    public func loadScale(_ notes: [MIDINote], tempo: Tempo) async throws {
        self.scale = notes
        self.tempo = tempo

        // AVAudioUnitSamplerにピアノ音源を読み込み
        try sampler.loadSoundBankInstrument(
            at: URL(fileURLWithPath: "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls"),
            program: 0,
            bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
            bankLSB: UInt8(kAUSampler_DefaultBankLSB)
        )
    }

    public func play() async throws {
        try engine.start()

        playbackTask = Task {
            for (index, note) in scale.enumerated() {
                currentNoteIndex = index

                // ノート再生（レガート: 次の音が鳴る直前に前の音を止める）
                sampler.startNote(note.value, withVelocity: 64, onChannel: 0)

                try await Task.sleep(nanoseconds: UInt64(tempo.secondsPerNote * 0.9 * 1_000_000_000))

                sampler.stopNote(note.value, onChannel: 0)

                try await Task.sleep(nanoseconds: UInt64(tempo.secondsPerNote * 0.1 * 1_000_000_000))
            }
        }

        try await playbackTask?.value
    }

    public func stop() async {
        playbackTask?.cancel()
        engine.stop()
    }
}
```

#### AudioRecorder（録音）
```swift
public protocol AudioRecorderProtocol {
    func prepareRecording() async throws -> URL
    func startRecording() async throws
    func stopRecording() async throws -> TimeInterval
    var isRecording: Bool { get }
}

public class AVAudioRecorderWrapper: AudioRecorderProtocol {
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?

    public func prepareRecording() async throws -> URL {
        // 録音ファイルURLを生成
        let fileName = "recording_\(DateFormatter.fileNameFormatter.string(from: Date())).m4a"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        // 録音設定
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 128000
        ]

        // AVAudioRecorder初期化
        recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder?.prepareToRecord()

        recordingURL = url
        return url
    }

    public func startRecording() async throws {
        guard let recorder = recorder else {
            throw AudioRecorderError.notPrepared
        }

        // オーディオセッション設定
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, options: [.defaultToSpeaker])
        try session.setActive(true)

        guard recorder.record() else {
            throw AudioRecorderError.recordingFailed
        }
    }

    public func stopRecording() async throws -> TimeInterval {
        guard let recorder = recorder else {
            throw AudioRecorderError.notRecording
        }

        recorder.stop()
        let duration = recorder.currentTime

        return duration
    }
}
```

#### AudioPlayer（再生）
```swift
public protocol AudioPlayerProtocol {
    func play(fileURL: URL) async throws
    func stop() async
    var isPlaying: Bool { get }
}

public class AVAudioPlayerWrapper: AudioPlayerProtocol {
    private var player: AVAudioPlayer?

    public func play(fileURL: URL) async throws {
        player = try AVAudioPlayer(contentsOf: fileURL)
        player?.play()
    }

    public func stop() async {
        player?.stop()
    }

    public var isPlaying: Bool {
        player?.isPlaying ?? false
    }
}
```

### 4.3 Repository Implementations

#### RecordingRepository
```swift
public class RecordingRepository: RecordingRepositoryProtocol {
    private let userDefaults: UserDefaults
    private let key = "recordings"

    public func save(_ recording: Recording) async throws {
        var recordings = try await findAll()
        recordings.append(recording)

        let data = try JSONEncoder().encode(recordings)
        userDefaults.set(data, forKey: key)
    }

    public func findAll() async throws -> [Recording] {
        guard let data = userDefaults.data(forKey: key) else {
            return []
        }
        return try JSONDecoder().decode([Recording].self, from: data)
    }

    public func findById(_ id: RecordingId) async throws -> Recording? {
        let recordings = try await findAll()
        return recordings.first { $0.id == id }
    }

    public func delete(_ id: RecordingId) async throws {
        var recordings = try await findAll()
        recordings.removeAll { $0.id == id }

        let data = try JSONEncoder().encode(recordings)
        userDefaults.set(data, forKey: key)
    }
}
```

#### AudioFileRepository
```swift
public class AudioFileRepository: AudioFileRepositoryProtocol {
    private let fileManager: FileManager
    private let recordingsDirectory: URL

    public init(fileManager: FileManager = .default) throws {
        self.fileManager = fileManager

        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.recordingsDirectory = documentsURL.appendingPathComponent("Recordings")

        // ディレクトリ作成
        try fileManager.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)
    }

    public func saveAudioFile(from sourceURL: URL, recordingId: RecordingId) async throws -> URL {
        let fileName = "\(recordingId.value.uuidString).m4a"
        let destinationURL = recordingsDirectory.appendingPathComponent(fileName)

        try fileManager.copyItem(at: sourceURL, to: destinationURL)

        return destinationURL
    }

    public func deleteAudioFile(at url: URL) async throws {
        try fileManager.removeItem(at: url)
    }

    public func audioFileExists(at url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }
}
```

## 5. Presentation Layer（プレゼンテーション層）

### 5.1 概要
SwiftUIベースのMVVMパターン。ViewModelがユースケースを呼び出し、Viewを更新。

### 5.2 ViewModels

#### RecordingViewModel
```swift
@MainActor
public class RecordingViewModel: ObservableObject {
    // Published Properties
    @Published public var state: RecordingState = .idle
    @Published public var currentPitch: Int = 0
    @Published public var totalPitches: Int = 13
    @Published public var elapsedTime: Duration = Duration(seconds: 0)
    @Published public var errorMessage: String?

    // Dependencies (Use Cases)
    private let startRecordingUseCase: StartRecordingWithScaleUseCaseProtocol
    private let stopRecordingUseCase: StopRecordingUseCaseProtocol

    private var session: RecordingSession?
    private var timer: Timer?

    public init(
        startRecordingUseCase: StartRecordingWithScaleUseCaseProtocol,
        stopRecordingUseCase: StopRecordingUseCaseProtocol
    ) {
        self.startRecordingUseCase = startRecordingUseCase
        self.stopRecordingUseCase = stopRecordingUseCase
    }

    public func startRecording() {
        Task {
            do {
                // カウントダウン
                state = .countdown(3)
                try await Task.sleep(nanoseconds: 1_000_000_000)
                state = .countdown(2)
                try await Task.sleep(nanoseconds: 1_000_000_000)
                state = .countdown(1)
                try await Task.sleep(nanoseconds: 1_000_000_000)

                // 録音開始
                let settings = ScaleSettings(
                    startNote: .middleC,
                    endNote: .hiC,
                    notePattern: .fiveToneScale,
                    tempo: .standard
                )

                session = try await startRecordingUseCase.execute(settings: settings)
                state = .recording

                // タイマー開始
                startTimer()
            } catch {
                errorMessage = error.localizedDescription
                state = .idle
            }
        }
    }

    public func stopRecording() {
        Task {
            guard let session = session else { return }

            do {
                let recording = try await stopRecordingUseCase.execute(session: session)
                state = .completed(recording)
                stopTimer()
            } catch {
                errorMessage = error.localizedDescription
                state = .idle
            }
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let session = self.session else { return }
            let elapsed = Date().timeIntervalSince(session.startedAt)
            self.elapsedTime = Duration(seconds: elapsed)

            // 進捗計算
            let totalDuration = session.settings.totalDuration.seconds
            self.currentPitch = Int((elapsed / totalDuration) * Double(self.totalPitches))
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

public enum RecordingState: Equatable {
    case idle
    case countdown(Int)
    case recording
    case completed(Recording)
}
```

#### RecordingListViewModel
```swift
@MainActor
public class RecordingListViewModel: ObservableObject {
    @Published public var recordings: [Recording] = []
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    @Published public var playingRecordingId: RecordingId?

    private let getAllRecordingsUseCase: GetAllRecordingsUseCaseProtocol
    private let deleteRecordingUseCase: DeleteRecordingUseCaseProtocol
    private let playRecordingUseCase: PlayRecordingUseCaseProtocol

    public func loadRecordings() {
        Task {
            isLoading = true
            defer { isLoading = false }

            do {
                recordings = try await getAllRecordingsUseCase.execute()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    public func deleteRecording(_ id: RecordingId) {
        Task {
            do {
                try await deleteRecordingUseCase.execute(recordingId: id)
                await loadRecordings()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    public func playRecording(_ recording: Recording) {
        Task {
            do {
                playingRecordingId = recording.id
                try await playRecordingUseCase.execute(recording: recording)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
```

### 5.3 Views

#### RecordingView
```swift
public struct RecordingView: View {
    @StateObject private var viewModel: RecordingViewModel

    public var body: some View {
        VStack(spacing: 20) {
            switch viewModel.state {
            case .idle:
                IdleStateView(onStart: viewModel.startRecording)

            case .countdown(let count):
                CountdownView(count: count)

            case .recording:
                RecordingStateView(
                    currentPitch: viewModel.currentPitch,
                    totalPitches: viewModel.totalPitches,
                    elapsedTime: viewModel.elapsedTime,
                    onStop: viewModel.stopRecording
                )

            case .completed(let recording):
                CompletedStateView(
                    recording: recording,
                    onRecordAgain: { viewModel.state = .idle }
                )
            }
        }
        .navigationTitle("ボイストレーニング")
        .alert(item: $viewModel.errorMessage) { message in
            Alert(title: Text("エラー"), message: Text(message))
        }
    }
}
```

#### RecordingListView
```swift
public struct RecordingListView: View {
    @StateObject private var viewModel: RecordingListViewModel

    public var body: some View {
        List {
            ForEach(viewModel.recordings) { recording in
                RecordingRow(
                    recording: recording,
                    isPlaying: viewModel.playingRecordingId == recording.id,
                    onPlay: { viewModel.playRecording(recording) }
                )
                .swipeActions {
                    Button(role: .destructive) {
                        viewModel.deleteRecording(recording.id)
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("録音リスト")
        .onAppear {
            viewModel.loadRecordings()
        }
    }
}
```

## 6. Dependency Injection

### 6.1 DependencyContainer
```swift
public class DependencyContainer {
    public static let shared = DependencyContainer()

    private init() {}

    // Infrastructure
    public lazy var scalePlayer: ScalePlayerProtocol = {
        AVAudioEngineScalePlayer()
    }()

    public lazy var audioRecorder: AudioRecorderProtocol = {
        AVAudioRecorderWrapper()
    }()

    public lazy var audioPlayer: AudioPlayerProtocol = {
        AVAudioPlayerWrapper()
    }()

    public lazy var recordingRepository: RecordingRepositoryProtocol = {
        RecordingRepository(userDefaults: .standard)
    }()

    public lazy var audioFileRepository: AudioFileRepositoryProtocol = {
        try! AudioFileRepository()
    }()

    // Use Cases
    public lazy var startRecordingUseCase: StartRecordingWithScaleUseCaseProtocol = {
        StartRecordingWithScaleUseCase(
            scalePlayer: scalePlayer,
            audioRecorder: audioRecorder
        )
    }()

    public lazy var stopRecordingUseCase: StopRecordingUseCaseProtocol = {
        StopRecordingUseCase(
            scalePlayer: scalePlayer,
            audioRecorder: audioRecorder,
            recordingRepository: recordingRepository,
            audioFileRepository: audioFileRepository
        )
    }()

    public lazy var getAllRecordingsUseCase: GetAllRecordingsUseCaseProtocol = {
        GetAllRecordingsUseCase(repository: recordingRepository)
    }()

    public lazy var deleteRecordingUseCase: DeleteRecordingUseCaseProtocol = {
        DeleteRecordingUseCase(
            recordingRepository: recordingRepository,
            audioFileRepository: audioFileRepository
        )
    }()

    public lazy var playRecordingUseCase: PlayRecordingUseCaseProtocol = {
        PlayRecordingUseCase(audioPlayer: audioPlayer)
    }()

    // ViewModels
    @MainActor
    public lazy var recordingViewModel: RecordingViewModel = {
        RecordingViewModel(
            startRecordingUseCase: startRecordingUseCase,
            stopRecordingUseCase: stopRecordingUseCase
        )
    }()

    @MainActor
    public lazy var recordingListViewModel: RecordingListViewModel = {
        RecordingListViewModel(
            getAllRecordingsUseCase: getAllRecordingsUseCase,
            deleteRecordingUseCase: deleteRecordingUseCase,
            playRecordingUseCase: playRecordingUseCase
        )
    }()
}
```

## 7. Testing Strategy

### 7.1 テストピラミッド
```
        ╱╲
       ╱UI╲          10% - UI Tests (重要なフローのみ)
      ╱────╲
     ╱ Intg ╲        20% - Integration Tests (Repository, AVFoundation連携)
    ╱────────╲
   ╱   Unit   ╲      70% - Unit Tests (Domain, Use Cases, ViewModels)
  ╱────────────╲
```

### 7.2 Unit Tests

#### Domain Layer
- エンティティのビジネスロジック
- 値オブジェクトのバリデーション
- ドメインサービスのロジック

```swift
final class ScaleSettingsTests: XCTestCase {
    func testGenerateScale_FiveTonePattern() {
        let settings = ScaleSettings(
            startNote: try! MIDINote(60),
            endNote: try! MIDINote(60),
            notePattern: .fiveToneScale,
            tempo: .standard
        )

        let scale = settings.generateScale()

        XCTAssertEqual(scale.count, 9)
        XCTAssertEqual(scale[0].value, 60)  // C
        XCTAssertEqual(scale[4].value, 67)  // G
        XCTAssertEqual(scale[8].value, 60)  // C
    }
}
```

#### Application Layer
- ユースケースのフロー
- モックを使った依存関係のテスト

```swift
final class StartRecordingUseCaseTests: XCTestCase {
    func testExecute_Success() async throws {
        let mockPlayer = MockScalePlayer()
        let mockRecorder = MockAudioRecorder()
        let useCase = StartRecordingWithScaleUseCase(
            scalePlayer: mockPlayer,
            audioRecorder: mockRecorder
        )

        let settings = ScaleSettings(...)
        let session = try await useCase.execute(settings: settings)

        XCTAssertTrue(mockPlayer.loadScaleCalled)
        XCTAssertTrue(mockRecorder.startRecordingCalled)
        XCTAssertEqual(session.settings, settings)
    }
}
```

### 7.3 Integration Tests

#### Infrastructure Layer
- AVFoundationとの実際の連携
- ファイルシステムとの連携

```swift
final class AVAudioEngineScalePlayerTests: XCTestCase {
    func testPlayScale_ActualAudio() async throws {
        let player = AVAudioEngineScalePlayer()
        let notes = [try! MIDINote(60), try! MIDINote(62), try! MIDINote(64)]

        try await player.loadScale(notes, tempo: .standard)
        try await player.play()

        XCTAssertTrue(player.isPlaying)
    }
}
```

## 8. ディレクトリ構成

```
VocalisStudio/
├── App/
│   ├── VocalisStudioApp.swift
│   └── DependencyContainer.swift
├── Domain/
│   ├── Entities/
│   │   ├── Recording.swift
│   │   └── ScaleSettings.swift
│   ├── ValueObjects/
│   │   ├── RecordingId.swift
│   │   ├── MIDINote.swift
│   │   ├── NotePattern.swift
│   │   ├── Tempo.swift
│   │   └── Duration.swift
│   ├── RepositoryInterfaces/
│   │   ├── RecordingRepositoryProtocol.swift
│   │   └── AudioFileRepositoryProtocol.swift
│   └── Services/
│       └── ScaleGenerator.swift
├── Application/
│   ├── UseCases/
│   │   ├── StartRecordingWithScaleUseCase.swift
│   │   ├── StopRecordingUseCase.swift
│   │   ├── GetAllRecordingsUseCase.swift
│   │   ├── DeleteRecordingUseCase.swift
│   │   └── PlayRecordingUseCase.swift
│   └── DTOs/
│       └── RecordingSession.swift
├── Infrastructure/
│   ├── Audio/
│   │   ├── ScalePlayer/
│   │   │   ├── ScalePlayerProtocol.swift
│   │   │   └── AVAudioEngineScalePlayer.swift
│   │   ├── Recorder/
│   │   │   ├── AudioRecorderProtocol.swift
│   │   │   └── AVAudioRecorderWrapper.swift
│   │   └── Player/
│   │       ├── AudioPlayerProtocol.swift
│   │       └── AVAudioPlayerWrapper.swift
│   └── Repositories/
│       ├── RecordingRepository.swift
│       └── AudioFileRepository.swift
├── Presentation/
│   ├── ViewModels/
│   │   ├── RecordingViewModel.swift
│   │   └── RecordingListViewModel.swift
│   └── Views/
│       ├── RecordingView.swift
│       ├── RecordingListView.swift
│       └── Components/
│           ├── IdleStateView.swift
│           ├── CountdownView.swift
│           ├── RecordingStateView.swift
│           ├── CompletedStateView.swift
│           └── RecordingRow.swift
└── Resources/
    ├── en.lproj/
    │   └── Localizable.strings
    └── ja.lproj/
        └── Localizable.strings

VocalisStudioTests/
├── Domain/
│   ├── Entities/
│   ├── ValueObjects/
│   └── Services/
├── Application/
│   └── UseCases/
├── Infrastructure/
│   ├── Audio/
│   └── Repositories/
├── Presentation/
│   └── ViewModels/
└── Mocks/
    ├── MockScalePlayer.swift
    ├── MockAudioRecorder.swift
    ├── MockAudioPlayer.swift
    └── MockRepositories.swift
```

## 9. 実装順序（推奨）

### Phase 1: ドメイン層の実装
1. 値オブジェクト（MIDINote, Tempo, Duration, etc.）
2. エンティティ（Recording, ScaleSettings）
3. リポジトリインターフェース
4. ドメインサービス（ScaleGenerator）

### Phase 2: インフラストラクチャ層の実装
5. ScalePlayer実装
6. AudioRecorder実装
7. AudioPlayer実装
8. Repository実装

### Phase 3: アプリケーション層の実装
9. StartRecordingWithScaleUseCase
10. StopRecordingUseCase
11. GetAllRecordingsUseCase
12. DeleteRecordingUseCase
13. PlayRecordingUseCase

### Phase 4: プレゼンテーション層の実装
14. RecordingViewModel
15. RecordingListViewModel
16. RecordingView（各状態のサブビュー含む）
17. RecordingListView

### Phase 5: 統合とテスト
18. DIコンテナ設定
19. ナビゲーション実装
20. 統合テスト
21. UIテスト

## 10. まとめ

このアーキテクチャにより：
- **テスタビリティ**: 各層が独立してテスト可能
- **保守性**: 責務が明確で変更の影響範囲が限定的
- **拡張性**: 新機能追加が既存コードに影響しにくい
- **ビジネスロジックの明確性**: ドメイン層で表現
- **フレームワーク非依存**: AVFoundation入れ替えが容易

TDD + Clean Architecture + DDDの組み合わせで、品質の高いMVPを実現します。
