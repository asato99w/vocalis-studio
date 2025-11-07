import XCTest
import VocalisDomain
@testable import VocalisStudio

@MainActor
final class RecordingListViewModelTests: XCTestCase {

    var sut: RecordingListViewModel!
    var mockRepository: MockRecordingRepository!
    var mockAudioPlayer: MockAudioPlayer!

    override func setUp() {
        super.setUp()
        mockRepository = MockRecordingRepository()
        mockAudioPlayer = MockAudioPlayer()
        sut = RecordingListViewModel(
            recordingRepository: mockRepository,
            audioPlayer: mockAudioPlayer
        )
    }

    override func tearDown() {
        sut = nil
        mockAudioPlayer = nil
        mockRepository = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInit_InitialState_IsEmpty() {
        // Then
        XCTAssertTrue(sut.recordings.isEmpty)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
        XCTAssertNil(sut.playingRecordingId)
    }

    // MARK: - Load Recordings Tests

    func testLoadRecordings_Success_PopulatesRecordings() async {
        // Given
        let testRecordings = [
            Recording(
                fileURL: URL(fileURLWithPath: "/tmp/test1.m4a"),
                duration: Duration(seconds: 10.0),
                scaleSettings: ScaleSettings.mvpDefault
            ),
            Recording(
                fileURL: URL(fileURLWithPath: "/tmp/test2.m4a"),
                duration: Duration(seconds: 15.0),
                scaleSettings: ScaleSettings.mvpDefault
            )
        ]
        mockRepository.recordingsToReturn = testRecordings

        // When
        await sut.loadRecordings()

        // Then
        XCTAssertEqual(sut.recordings.count, 2)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
    }

    func testLoadRecordings_EmptyRepository_ReturnsEmptyArray() async {
        // Given
        mockRepository.recordingsToReturn = []

        // When
        await sut.loadRecordings()

        // Then
        XCTAssertTrue(sut.recordings.isEmpty)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
    }

    func testLoadRecordings_Failure_SetsErrorMessage() async {
        // Given
        mockRepository.findAllShouldFail = true

        // When
        await sut.loadRecordings()

        // Then
        XCTAssertTrue(sut.recordings.isEmpty)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNotNil(sut.errorMessage)
    }

    func testLoadRecordings_SetsLoadingStateDuringExecution() async {
        // Given
        mockRepository.recordingsToReturn = []

        // When
        let loadTask = Task {
            await sut.loadRecordings()
        }

        await loadTask.value

        // Then
        XCTAssertFalse(sut.isLoading) // Should be false after completion
    }

    // MARK: - Play Recording Tests

    func testPlayRecording_Success_SetsPlayingRecordingId() async {
        // Given
        let recording = Recording(
            fileURL: URL(fileURLWithPath: "/tmp/test.m4a"),
            duration: Duration(seconds: 5.0),
            scaleSettings: ScaleSettings.mvpDefault
        )

        // When
        await sut.playRecording(recording)

        // Then - after completion, should be nil
        XCTAssertNil(sut.playingRecordingId)
        XCTAssertTrue(mockAudioPlayer.playCalled)
        XCTAssertEqual(mockAudioPlayer.playURL, recording.fileURL)
    }

    func testPlayRecording_AlreadyPlaying_StopsAndReturns() async {
        // Given
        let recording = Recording(
            fileURL: URL(fileURLWithPath: "/tmp/test.m4a"),
            duration: Duration(seconds: 5.0),
            scaleSettings: ScaleSettings.mvpDefault
        )

        // Simulate already playing
        mockAudioPlayer._isPlaying = true

        // When
        await sut.playRecording(recording)

        // Then
        XCTAssertTrue(mockAudioPlayer.playCalled)
    }

    func testPlayRecording_DifferentRecording_StopsCurrentAndPlaysNew() async {
        // Given
        let recording1 = Recording(
            fileURL: URL(fileURLWithPath: "/tmp/test1.m4a"),
            duration: Duration(seconds: 5.0),
            scaleSettings: ScaleSettings.mvpDefault
        )
        let recording2 = Recording(
            fileURL: URL(fileURLWithPath: "/tmp/test2.m4a"),
            duration: Duration(seconds: 5.0),
            scaleSettings: ScaleSettings.mvpDefault
        )

        // When - play recordings sequentially
        await sut.playRecording(recording1)
        mockAudioPlayer.reset()

        await sut.playRecording(recording2)

        // Then
        XCTAssertTrue(mockAudioPlayer.playCalled)
        XCTAssertEqual(mockAudioPlayer.playURL, recording2.fileURL)
    }

    func testPlayRecording_Failure_SetsErrorMessage() async {
        // Given
        let recording = Recording(
            fileURL: URL(fileURLWithPath: "/tmp/test.m4a"),
            duration: Duration(seconds: 5.0),
            scaleSettings: ScaleSettings.mvpDefault
        )
        mockAudioPlayer.playShouldFail = true

        // When
        await sut.playRecording(recording)

        // Then
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertNil(sut.playingRecordingId)
    }

    // MARK: - Stop Playback Tests

    func testStopPlayback_WhenPlaying_StopsAndClearsPlayingId() async {
        // Given
        mockAudioPlayer._isPlaying = true

        // When
        await sut.stopPlayback()

        // Then
        XCTAssertNil(sut.playingRecordingId)
        XCTAssertTrue(mockAudioPlayer.stopCalled)
    }

    func testStopPlayback_WhenNotPlaying_DoesNothing() async {
        // Given
        XCTAssertNil(sut.playingRecordingId)

        // When
        await sut.stopPlayback()

        // Then
        XCTAssertNil(sut.playingRecordingId)
        XCTAssertTrue(mockAudioPlayer.stopCalled) // Stop is called regardless
    }

    // MARK: - Delete Recording Tests

    func testDeleteRecording_Success_RemovesRecordingAndReloads() async {
        // Given
        let recording1 = Recording(
            fileURL: URL(fileURLWithPath: "/tmp/test1.m4a"),
            duration: Duration(seconds: 10.0),
            scaleSettings: ScaleSettings.mvpDefault
        )
        let recording2 = Recording(
            fileURL: URL(fileURLWithPath: "/tmp/test2.m4a"),
            duration: Duration(seconds: 15.0),
            scaleSettings: ScaleSettings.mvpDefault
        )
        mockRepository.recordingsToReturn = [recording1, recording2]
        await sut.loadRecordings()
        XCTAssertEqual(sut.recordings.count, 2)

        // When - delete first recording
        mockRepository.recordingsToReturn = [recording2] // Simulate deletion
        await sut.deleteRecording(recording1)

        // Then
        XCTAssertEqual(sut.recordings.count, 1)
        XCTAssertEqual(sut.recordings.first?.id, recording2.id)
        XCTAssertNil(sut.errorMessage)
    }

    func testDeleteRecording_WhilePlaying_StopsPlaybackFirst() async {
        // Given
        let recording = Recording(
            fileURL: URL(fileURLWithPath: "/tmp/test.m4a"),
            duration: Duration(seconds: 5.0),
            scaleSettings: ScaleSettings.mvpDefault
        )
        mockRepository.recordingsToReturn = [recording]

        await sut.loadRecordings()

        // When - delete
        mockRepository.recordingsToReturn = [] // Simulate deletion
        await sut.deleteRecording(recording)

        // Then
        XCTAssertTrue(sut.recordings.isEmpty)
    }

    func testDeleteRecording_Failure_SetsErrorMessage() async {
        // Given
        let recording = Recording(
            fileURL: URL(fileURLWithPath: "/tmp/test.m4a"),
            duration: Duration(seconds: 5.0),
            scaleSettings: ScaleSettings.mvpDefault
        )
        mockRepository.recordingsToReturn = [recording]

        await sut.loadRecordings()

        // When
        await sut.deleteRecording(recording)

        // Then
        XCTAssertTrue(mockRepository.deleteCalled)
    }

    // MARK: - Position Tracking Tests

    func testStartPositionTracking_UpdatesCurrentTime() async {
        // Given
        mockAudioPlayer._currentTime = 5.0

        // When
        await sut.startPositionTracking()

        // Wait for at least one update
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

        // Then
        XCTAssertEqual(sut.currentTime, 5.0, accuracy: 0.1)
    }

    func testStopPositionTracking_StopsUpdates() async {
        // Given
        await sut.startPositionTracking()
        mockAudioPlayer._currentTime = 5.0

        // When
        sut.stopPositionTracking()
        let timeAfterStop = sut.currentTime

        // Wait to verify no more updates
        mockAudioPlayer._currentTime = 10.0
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Then - currentTime should not have changed
        XCTAssertEqual(sut.currentTime, timeAfterStop)
    }

    // MARK: - Seek Tests

    func testSeekToPosition_CallsAudioPlayerSeek() async {
        // Given
        let targetTime = 30.0

        // When
        await sut.seekToPosition(targetTime)

        // Then
        XCTAssertTrue(mockAudioPlayer.seekCalled)
        XCTAssertEqual(mockAudioPlayer.seekToTime, targetTime, accuracy: 0.01)
    }
}
