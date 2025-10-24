//
//  RecordingLimit.swift
//  VocalisStudio
//
//  Recording limits based on subscription tier
//

import Foundation

/// Recording limits for each subscription tier
public struct RecordingLimit {

    /// Daily recording count limit (nil = unlimited)
    public let dailyCount: Int?

    /// Maximum recording duration in seconds (nil = unlimited)
    public let maxDuration: TimeInterval?

    /// Get recording limit for subscription tier
    public static func forTier(_ tier: SubscriptionTier) -> RecordingLimit {
        switch tier {
        case .free:
            return RecordingLimit(dailyCount: 5, maxDuration: 30) // 5 recordings/day, 30 seconds max
        case .premium:
            return RecordingLimit(dailyCount: nil, maxDuration: 300) // Unlimited recordings, 5 minutes max
        case .premiumPlus:
            return RecordingLimit(dailyCount: nil, maxDuration: nil) // Unlimited
        }
    }

    /// Check if count is within limit
    public func isCountWithinLimit(_ count: Int) -> Bool {
        guard let limit = dailyCount else {
            return true // Unlimited
        }
        return count < limit
    }

    /// Check if duration is within limit
    public func isWithinDurationLimit(_ duration: TimeInterval) -> Bool {
        guard let limit = maxDuration else {
            return true // Unlimited
        }
        return duration <= limit
    }

    /// Get remaining count for display
    public func remainingCount(_ current: Int) -> String {
        guard let limit = dailyCount else {
            return "無制限"
        }
        let remaining = max(0, limit - current)
        return "\(remaining)/\(limit)"
    }

    /// Get duration limit description
    public var durationDescription: String {
        guard let duration = maxDuration else {
            return "無制限"
        }

        if duration >= 60 {
            let minutes = Int(duration / 60)
            return "\(minutes)分"
        } else {
            return "\(Int(duration))秒"
        }
    }
}
