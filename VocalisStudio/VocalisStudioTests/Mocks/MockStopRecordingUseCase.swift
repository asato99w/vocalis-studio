import Foundation
import VocalisDomain
@testable import VocalisStudio

final class MockStopRecordingUseCase: StopRecordingUseCaseProtocol {
    var executeCalled = false
    var executeResult: StopRecordingResult?
    var executeShouldFail = false

    func execute() async throws -> StopRecordingResult {
        executeCalled = true

        if executeShouldFail {
            throw AudioRecorderError.notRecording
        }

        guard let result = executeResult else {
            return StopRecordingResult(duration: 0.0)
        }

        return result
    }

    func reset() {
        executeCalled = false
        executeResult = nil
        executeShouldFail = false
    }
}

// Note: This mock doesn't need scalePlayer because it's a mock of the entire use case
// The actual StopRecordingUseCase handles scalePlayer internally
