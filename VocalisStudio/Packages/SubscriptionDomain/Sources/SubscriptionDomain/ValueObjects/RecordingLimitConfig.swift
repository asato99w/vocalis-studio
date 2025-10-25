//
//  RecordingLimitConfig.swift
//  VocalisStudio
//
//  Recording limit configuration protocol and implementations
//

import Foundation

/// Protocol for configuring recording limits based on subscription tier
public protocol RecordingLimitConfigProtocol {
    /// Get recording limit for the specified subscription tier
    func limitForTier(_ tier: SubscriptionTier) -> RecordingLimit
}

/// Production recording limit configuration with actual time limits
public class ProductionRecordingLimitConfig: RecordingLimitConfigProtocol {
    public init() {}

    public func limitForTier(_ tier: SubscriptionTier) -> RecordingLimit {
        switch tier {
        case .free:
            return RecordingLimit(dailyCount: 5, maxDuration: 30) // 5 recordings/day, 30 seconds max
        case .premium:
            return RecordingLimit(dailyCount: nil, maxDuration: 300) // Unlimited recordings, 5 minutes max
        case .premiumPlus:
            return RecordingLimit(dailyCount: nil, maxDuration: nil) // Unlimited
        }
    }
}

/// Test recording limit configuration with shorter durations for faster testing
public class TestRecordingLimitConfig: RecordingLimitConfigProtocol {
    public init() {}

    public func limitForTier(_ tier: SubscriptionTier) -> RecordingLimit {
        switch tier {
        case .free:
            return RecordingLimit(dailyCount: 5, maxDuration: 2) // 5 recordings/day, 2 seconds for testing
        case .premium:
            return RecordingLimit(dailyCount: nil, maxDuration: 4) // Unlimited recordings, 4 seconds for testing
        case .premiumPlus:
            return RecordingLimit(dailyCount: nil, maxDuration: nil) // Unlimited
        }
    }
}
