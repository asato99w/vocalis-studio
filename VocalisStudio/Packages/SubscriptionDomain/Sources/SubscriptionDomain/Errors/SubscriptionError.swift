//
//  SubscriptionError.swift
//  VocalisStudio
//
//  Subscription-related errors
//

import Foundation

public enum SubscriptionError: Error, Equatable {
    case productNotFound
    case purchaseFailed(String)
    case noPurchasesToRestore
    case networkError
    case unknown
}
