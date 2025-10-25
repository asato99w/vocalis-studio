import XCTest
import VocalisDomain
import SubscriptionDomain
@testable import VocalisStudio

final class RecordingLimitTests: XCTestCase {

    // MARK: - Duration Limit Tests

    func testIsWithinDurationLimit_FreeTier_Under30Seconds_ReturnsTrue() {
        // Given
        let limit = RecordingLimit.forTier(.free)
        let duration: TimeInterval = 25.0

        // When
        let result = limit.isWithinDurationLimit(duration)

        // Then
        XCTAssertTrue(result)
    }

    func testIsWithinDurationLimit_FreeTier_Exactly30Seconds_ReturnsTrue() {
        // Given
        let limit = RecordingLimit.forTier(.free)
        let duration: TimeInterval = 30.0

        // When
        let result = limit.isWithinDurationLimit(duration)

        // Then
        XCTAssertTrue(result)
    }

    func testIsWithinDurationLimit_FreeTier_Over30Seconds_ReturnsFalse() {
        // Given
        let limit = RecordingLimit.forTier(.free)
        let duration: TimeInterval = 31.0

        // When
        let result = limit.isWithinDurationLimit(duration)

        // Then
        XCTAssertFalse(result)
    }

    func testIsWithinDurationLimit_PremiumTier_Under5Minutes_ReturnsTrue() {
        // Given
        let limit = RecordingLimit.forTier(.premium)
        let duration: TimeInterval = 250.0

        // When
        let result = limit.isWithinDurationLimit(duration)

        // Then
        XCTAssertTrue(result)
    }

    func testIsWithinDurationLimit_PremiumTier_Exactly5Minutes_ReturnsTrue() {
        // Given
        let limit = RecordingLimit.forTier(.premium)
        let duration: TimeInterval = 300.0

        // When
        let result = limit.isWithinDurationLimit(duration)

        // Then
        XCTAssertTrue(result)
    }

    func testIsWithinDurationLimit_PremiumTier_Over5Minutes_ReturnsFalse() {
        // Given
        let limit = RecordingLimit.forTier(.premium)
        let duration: TimeInterval = 301.0

        // When
        let result = limit.isWithinDurationLimit(duration)

        // Then
        XCTAssertFalse(result)
    }

    func testIsWithinDurationLimit_PremiumPlusTier_AnyDuration_ReturnsTrue() {
        // Given
        let limit = RecordingLimit.forTier(.premiumPlus)
        let duration: TimeInterval = 10000.0

        // When
        let result = limit.isWithinDurationLimit(duration)

        // Then
        XCTAssertTrue(result)
    }
}
