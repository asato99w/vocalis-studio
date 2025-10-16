import Foundation
import VocalisDomain
@testable import VocalisStudio

final class MockStartRecordingWithScaleUseCase: StartRecordingWithScaleUseCaseProtocol {
    var executeCalled = false
    var executeCallCount = 0
    var executeSettings: ScaleSettings?
    var executeResult: RecordingSession?
    var executeShouldFail = false

    func execute(settings: ScaleSettings) async throws -> RecordingSession {
        executeCalled = true
        executeCallCount += 1
        executeSettings = settings

        if executeShouldFail {
            throw ScalePlayerError.playbackFailed("Mock use case error")
        }

        guard let result = executeResult else {
            throw ScalePlayerError.notLoaded
        }

        return result
    }

    func reset() {
        executeCalled = false
        executeCallCount = 0
        executeSettings = nil
        executeResult = nil
        executeShouldFail = false
    }
}
