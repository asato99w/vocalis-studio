//
//  RecordingLimitIntegrationTests.swift
//  VocalisStudioTests
//
//  Integration tests for recording duration limits enforcement
//

import XCTest
import VocalisDomain
@testable import VocalisStudio

@MainActor
final class RecordingLimitIntegrationTests: XCTestCase {

    var subscriptionViewModel: SubscriptionViewModel!
    var recordingViewModel: RecordingViewModel!
    var mockStartUseCase: MockStartRecordingUseCase!
    var mockStartWithScaleUseCase: MockStartRecordingWithScaleUseCase!
    var mockStopUseCase: MockStopRecordingUseCase!

    override func setUp() async throws {
        // Create mock recording dependencies using existing mock classes from Mocks/
        mockStartUseCase = MockStartRecordingUseCase()
        mockStartWithScaleUseCase = MockStartRecordingWithScaleUseCase()
        mockStopUseCase = MockStopRecordingUseCase()
        let mockAudioPlayer = MockAudioPlayer()
        let mockPitchDetector = RealtimePitchDetector() // Use real class for simplicity
        let mockScalePlayer = MockScalePlayer()
        let mockUsageTracker = RecordingUsageTracker()

        // Create subscription view model with inline mock dependencies
        let mockGetStatusUseCase = TestGetSubscriptionStatusUseCase()
        let mockPurchaseUseCase = TestPurchaseSubscriptionUseCase()
        let mockRestoreUseCase = TestRestorePurchasesUseCase()

        subscriptionViewModel = SubscriptionViewModel(
            getStatusUseCase: mockGetStatusUseCase,
            purchaseUseCase: mockPurchaseUseCase,
            restoreUseCase: mockRestoreUseCase
        )

        // Set to Free tier
        subscriptionViewModel.setDebugTier(.free)

        recordingViewModel = RecordingViewModel(
            startRecordingUseCase: mockStartUseCase,
            startRecordingWithScaleUseCase: mockStartWithScaleUseCase,
            stopRecordingUseCase: mockStopUseCase,
            audioPlayer: mockAudioPlayer,
            pitchDetector: mockPitchDetector,
            scalePlayer: mockScalePlayer,
            subscriptionViewModel: subscriptionViewModel,
            usageTracker: mockUsageTracker,
            limitConfig: TestRecordingLimitConfig() // Use test config with shorter durations
        )
    }

    // MARK: - Duration Limit Tests

    func testFreeTierHas30SecondDurationLimit() async throws {
        // Given: Free tier
        subscriptionViewModel.setDebugTier(.free)

        // Wait for subscription status to update
        try await Task.sleep(nanoseconds: 100_000_000)

        // Then: Free tier should have 2 second limit (test config)
        XCTAssertEqual(recordingViewModel.recordingLimit.maxDuration, 2)
        XCTAssertEqual(recordingViewModel.recordingLimit.durationDescription, "2秒")
    }

    func testPremiumTierHas5MinuteDurationLimit() async throws {
        // Given: Premium tier
        subscriptionViewModel.setDebugTier(.premium)

        // Wait for subscription status to update
        try await Task.sleep(nanoseconds: 100_000_000)

        // Then: Premium tier should have 4 second limit (test config)
        XCTAssertEqual(recordingViewModel.recordingLimit.maxDuration, 4)
        XCTAssertEqual(recordingViewModel.recordingLimit.durationDescription, "4秒")
    }

    func testPremiumPlusTierHasUnlimitedDuration() async throws {
        // Given: Premium Plus tier
        subscriptionViewModel.setDebugTier(.premiumPlus)

        // Wait for subscription status to update
        try await Task.sleep(nanoseconds: 100_000_000)

        // Then: Premium Plus tier should have unlimited duration
        XCTAssertNil(recordingViewModel.recordingLimit.maxDuration)
        XCTAssertEqual(recordingViewModel.recordingLimit.durationDescription, "無制限")
    }

    func testDurationLimitEnforcementDuringRecording() async throws {
        // Given: Free tier with 2 second limit (test config)
        subscriptionViewModel.setDebugTier(.free)

        // Wait for subscription status to update
        try await Task.sleep(nanoseconds: 100_000_000)

        // Set up mock recording session
        let mockRecordingURL = URL(fileURLWithPath: "/tmp/test_recording.m4a")
        let mockRecordingSession = RecordingSession(recordingURL: mockRecordingURL)
        mockStartUseCase.executeResult = mockRecordingSession

        // When: Start recording
        await recordingViewModel.startRecording()

        // Wait for countdown to complete
        try await Task.sleep(nanoseconds: 3_500_000_000)

        // Then: Recording should start
        XCTAssertEqual(recordingViewModel.recordingState, .recording)

        // Wait for recording duration limit to be reached (2 seconds + buffer)
        // Using 3 seconds to ensure the monitoring task has time to detect and stop
        try await Task.sleep(nanoseconds: 3_000_000_000)

        // Then: Recording should have stopped automatically
        XCTAssertEqual(recordingViewModel.recordingState, .idle, "Recording should auto-stop after 2 seconds")

        // And: Error message should be set
        XCTAssertNotNil(recordingViewModel.errorMessage, "Error message should be set when limit reached")
        XCTAssertTrue(recordingViewModel.errorMessage?.contains("録音時間の上限に達しました") == true, "Error message should indicate duration limit")
    }

    // MARK: - Count Limit Tests

    func testFreeTierHas5RecordingsPerDayLimit() async throws {
        // Given: Free tier
        subscriptionViewModel.setDebugTier(.free)

        // Wait for subscription status to update
        try await Task.sleep(nanoseconds: 100_000_000)

        // Then: Free tier should have 5 recordings/day limit
        XCTAssertEqual(recordingViewModel.recordingLimit.dailyCount, 5)
    }

    func testPremiumTierHasUnlimitedRecordings() async throws {
        // Given: Premium tier
        subscriptionViewModel.setDebugTier(.premium)

        // Wait for subscription status to update
        try await Task.sleep(nanoseconds: 100_000_000)

        // Then: Premium tier should have unlimited recordings
        XCTAssertNil(recordingViewModel.recordingLimit.dailyCount)
    }
}

// MARK: - Test-specific Mock Subscription Use Cases
// Note: Using unique names to avoid conflicts with existing mocks in other files

private class TestGetSubscriptionStatusUseCase: GetSubscriptionStatusUseCaseProtocol {
    func execute() async throws -> SubscriptionStatus {
        return SubscriptionStatus(
            tier: .free,
            cohort: .v2_0,
            isActive: false,
            expirationDate: nil,
            purchaseDate: nil,
            willAutoRenew: false
        )
    }
}

private class TestPurchaseSubscriptionUseCase: PurchaseSubscriptionUseCaseProtocol {
    func execute(tier: SubscriptionTier) async throws {
        // Mock implementation
    }
}

private class TestRestorePurchasesUseCase: RestorePurchasesUseCaseProtocol {
    func execute() async throws {
        // Mock implementation
    }
}
