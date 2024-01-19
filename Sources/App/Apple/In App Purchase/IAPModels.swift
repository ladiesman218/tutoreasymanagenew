//
//  File.swift
//  
//
//  Created by Lei Gao on 2022/12/23.
//

import Foundation
import JWT


struct SignedPayload: Decodable {
	let signedPayload: String
}

enum NotificationType: String, Codable {
	case consumptionRequest = "CONSUMPTION_REQUEST"		// A refund request for a consumable in-app purchase
	case didChangeRenewalPref = "DID_CHANGE_RENEWAL_PREF"	// the user made a change to their subscription plan, upgrade or downgrad
	case didChangeRenewalStatus = "DID_CHANGE_RENEWAL_STATUS"	// Disable or re-enabled auto-renewal
	case didfailToRenew = "DID_FAIL_TO_RENEW"
	case didRenew = "DID_RENEW"
	case expired = "EXPIRED"
	case gracePeriodExpired = "GRACE_PERIOD_EXPIRED"
	case offeredRedeemed = "OFFER_REDEEMED"
	case priceIncrease = "PRICE_INCREASE"
	case refund = "REFUND"
	case refundDeclined = "REFUND_DECLINED"
	case renewalExtended = "RENEWAL_EXTENDED"
	case revoke = "REVOKE"		// No longer available through Family Sharing
	case subscribed = "SUBSCRIBED"
	case test = "TEST"
}

enum NotificationSubtype: String, Codable {
	case initialBuy = "INITIAL_BUY"		// Only for subscribed
	case resubscribe = "RESUBSCRIBE"	// Only for subscribed, the user resubscribed or received access through Family Sharing to the same subscription or to another subscription within the same subscription group.
	case downgrade = "DOWNGRADE"
	case upgrade = "UPGRADE"
	case autoRenewEnabled = "AUTO_RENEW_ENABLED"
	case autoRenewDisabled = "AUTO_RENEW_DISABLED"
	case voluntary = "VOLUNTARY"
	case billingRetry = "BILLING_RETRY"
	case priceIncrease = "PRICE_INCREASE"
	case gracePeriod = "GRACE_PERIOD"
	case billingRecovery = "BILLING_RECOVERY"
	case pending = "PENDING"	// Applies to the PRICE_INCREASE notificationType. A notification with this subtype indicates that the system informed the user of the subscription price increase, but the user hasn’t yet accepted it.
	case accepted = "ACCEPTED"	// Applies to the PRICE_INCREASE notificationType. A notification with this subtype indicates that the user accepted the subscription price increase.
}

struct NotificationData: Codable {
	let appAppleId: String?
	let bundleId: String
	let bundleVersion: String?
	let environment: Env
	// Both SignedRenewalInfo and SignedTransactionInfo are strictly tailored for auto-renew products ONLY, if other types of in-app-purchase are added, change the optionality of properties accordingly.
	let signedRenewalInfo: String
	let signedTransactionInfo: String

	// Signed renewal info
	// https://developer.apple.com/documentation/appstoreservernotifications/jwsrenewalinfodecodedpayload

	// Signed transaction info
	// https://developer.apple.com/documentation/appstoreservernotifications/jwstransactiondecodedpayload
}

struct SignedRenewalInfo: JWTPayload {
	func verify(using signer: JWTSigner) throws {
		
	}
	
	let autoRenewProductId: String
	let autoRenewStatus: Int32
	let environment: String
	let expirationIntent: Int32?
	let gracePeriodExpiresDate: Date?
	let isInBillingRetryPeriod: Bool?
	let offerIdentifier: String?
	let offerType: Int32?
	let originalTransactionId: String
	let priceIncreaseStatus: Int32?
	let productId: String
	let recentSubscriptionStartDate: Int
	let signedDate: Int
}

struct SignedTransactionInfo: JWTPayload {
	func verify(using signer: JWTSigner) throws {
		
	}
	
	let appAccountToken: UUID?
	let bundleId: String
	let environment: String
	let expiresDate: Int?
	let inAppOwnershipType: String
	let isUpgraded: Bool?
	let offerIdentifier: String?
	let offerType: Int32?
	let originalPurchaseDate: Int
	let originalTransactionId: String
	let productId: String
	let purchaseDate: Int
	let quantity: Int
	let revocationDate: Int?
	let revocationReason: String?
	let signedDate: Int
	let subscriptionGroupIdentifier: String
	let transactionId: String
	let type: String
	let webOrderLineItemId: String
}

enum Env: String, Codable {
	case sandbox = "Sandbox"
	case production = "Production"
}

struct NotificationPayload: JWTPayload {
	let notificationType: NotificationType
	let subtype: NotificationSubtype?
	let notificationUUID: String
	let data: NotificationData
	let version: String
	let signedDate: Int
	
	func verify(using signer: JWTSigner) throws {
//		signer.verify(<#T##token: String##String#>)
	}
	
}
