import Foundation
import VocalisDomain
@testable import VocalisStudio

final class MockStartRecordingUseCase: StartRecordingUseCaseProtocol {
    var executeCalled = false
    var executeCallCount = 0
    var executeResult: RecordingSession?
    var executeShouldFail = false

    func execute() async throws -> RecordingSession {
        executeCalled = true
        executeCallCount += 1

        if executeShouldFail {
            throw AudioRecorderError.recordingFailed("Mock use case error")
        }

        guard let result = executeResult else {
            throw AudioRecorderError.recordingFailed("No mock result provided")
        }

        return result
    }

    func reset() {
        executeCalled = false
        executeCallCount = 0
        executeResult = nil
        executeShouldFail = false
    }
}
