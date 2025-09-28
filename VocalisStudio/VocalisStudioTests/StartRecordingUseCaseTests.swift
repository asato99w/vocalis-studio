import XCTest
@testable import VocalisStudio

final class StartRecordingUseCaseTests: XCTestCase {
    var useCase: StartRecordingUseCase!
    var mockRepository: MockRecordingRepository!
    var mockAudioRecorder: MockAudioRecorder!
    
    override func setUp() {
        super.setUp()
        mockRepository = MockRecordingRepository()
        mockAudioRecorder = MockAudioRecorder()
        useCase = StartRecordingUseCase(
            recordingRepository: mockRepository,
            audioRecorder: mockAudioRecorder
        )
    }
    
    func testStartRecordingSuccess() async throws {
        // Given
        let expectedUrl = URL(fileURLWithPath: "/test/audio.m4a")
        mockAudioRecorder.stubbedStartRecordingResult = expectedUrl
        
        // When
        let recording = try await useCase.execute()
        
        // Then
        XCTAssertNotNil(recording)
        XCTAssertEqual(recording.audioFileUrl, expectedUrl)
        XCTAssertTrue(recording.isInProgress)
        XCTAssertTrue(mockAudioRecorder.startRecordingCalled)
        XCTAssertTrue(mockRepository.saveCalled)
    }
    
    func testStartRecordingFailure() async {
        // Given
        mockAudioRecorder.stubbedStartRecordingError = AudioRecorderError.microphoneAccessDenied
        
        // When/Then
        do {
            _ = try await useCase.execute()
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertTrue(error is AudioRecorderError)
        }
    }
}

// Mock implementations
class MockRecordingRepository: RecordingRepository {
    var saveCalled = false
    var savedRecording: Recording?
    
    func save(_ recording: Recording) async throws {
        saveCalled = true
        savedRecording = recording
    }
    
    func findById(_ id: RecordingId) async throws -> Recording? {
        return nil
    }
    
    func findAll() async throws -> [Recording] {
        return []
    }
    
    func delete(_ id: RecordingId) async throws {
    }
}

class MockAudioRecorder: AudioRecording {
    var startRecordingCalled = false
    var stubbedStartRecordingResult: URL?
    var stubbedStartRecordingError: Error?
    
    func startRecording() async throws -> URL {
        startRecordingCalled = true
        if let error = stubbedStartRecordingError {
            throw error
        }
        return stubbedStartRecordingResult ?? URL(fileURLWithPath: "/default.m4a")
    }
    
    func stopRecording() async throws {
    }
    
    func pauseRecording() {
    }
    
    func resumeRecording() {
    }
    
    var isRecording: Bool = false
    var currentTime: TimeInterval = 0
}