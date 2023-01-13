//
//  File.swift
//  
//
//  Created by Lei Gao on 2022/12/8.
//

import Vapor
import JWT
import JWTKit
import Fluent

#warning("test the entire route collection")
struct IAPController: RouteCollection {
	func boot(routes: RoutesBuilder) throws {
		let iapProductRoute = routes.grouped("api", "iap")
		iapProductRoute.get(use: getProductIdentifiers)
		
		let notificationRoute = routes.grouped("api", "assn", "v2")
		notificationRoute.on(.POST, body: .collect(maxSize: "512kb"), use: getNotification)
	}
	
	func getProductIdentifiers(_ req: Request) async throws -> [String] {
		let languages = try await Language.query(on: req.db).filter(\.$published == true).all()
		guard !languages.contains(where: { $0.annuallyIAPIdentifier.isEmpty }) else {
			// Send email to admin: at least 1 published language has an empty IAP identifier, although this should never happen since we made sure in langauge validation method, published language should never have an empty identifier.
			throw Abort(.internalServerError)
		}
		var identifiers = languages.map { $0.annuallyIAPIdentifier }
		identifiers.append(vipIAPIdentifier)
		return identifiers
	}
		
	func getNotification(_ req: Request) async -> HTTPStatus {
		// For version 2 notifications, it retries five times; at 1, 12, 24, 48, and 72 hours after the previous attempt.
		//https://developer.apple.com/documentation/appstoreservernotifications/responding_to_app_store_server_notifications
		do {
			let notification = try req.content.decode(SignedPayload.self)
			
			let payload = try req.application.jwt.signers.verifyJWSWithX5C(
				notification.signedPayload,
				as: NotificationPayload.self,
				rootCert: "")
			try await processNotification(req, notification: payload)
			return .ok
		} catch {
			print(error)
			return .internalServerError
		}
	}
	
	func subscribe(_ req: Request, transactionInfo: SignedTransactionInfo, renewalInfo: SignedRenewalInfo, userID: User.IDValue) async throws {
		
		let transactionID = transactionInfo.transactionId
		let productID = transactionInfo.productId

		async let validOrders = ProtectedOrderController().getAllValidOrdersForUser(req, userID: userID)
		async let language = Language.query(on: req.db).group(.and) { group in
			group.filter(\.$annuallyIAPIdentifier == productID)
			group.filter(\.$published == true)
		}.first()
		
		// Make sure payload contains valid data
		guard let expiresMilliSecond = transactionInfo.expiresDate else {
			// Send email, expiration date is missing, this should never happen.
			print("expiresDate missing")
			throw GeneralInputError.invalidDataStructure
		}
		guard transactionInfo.type == "Auto-Renewable Subscription" else {
			// Send email, we are processing a new subscription with the wrong method
			throw GeneralInputError.invalidDataStructure
		}

		// Sometimes we get duplicate notifications. We've checked all possible reasons, it's not because the wrong response we replied to apple server, so maybe a time-out occured while processing the notification, so apple server send the notification again. To avoid duplicate orders created in db due to duplicate notifications, we could check for notification ID but that requires another field in db to store the id, instead we will check for existing transactionId or completeTime(which is SignedTransactionInfo.purchaseDate in essence) or SignedTransactionInfo.expiresDate.
		guard try await !validOrders.contains(where: { $0.transactionID == transactionID }) else {
			// Here means transactionID exists in db, we probably had process the notification, return the created response.
			print("The order has been saved")
			return
		}
		
		// Received time stamp is in milli-second format, so devide it by 1000 to convert it to second
		let expiresDate = Date(timeIntervalSince1970: TimeInterval(expiresMilliSecond / 1000))
		let completeTime = Date(timeIntervalSince1970: .init(transactionInfo.purchaseDate / 1000))
		
		guard Date.now < expiresDate else {
			// Send email, expire time is earlier than current time, this should never happen
			print("expiresDate is earlier than current time")
			throw GeneralInputError.invalidDataStructure
		}
		
		// If VIP membership is being purchased, handle it first, then return.
		if productID == vipIAPIdentifier {
			// Generate the order
			let emptyCache = LanguageCache(languageID: UUID(), name: "vip", description: "", price: 123, iapIdentifier: vipIAPIdentifier)
			let order = Order(status: .completed, languageCaches: [emptyCache], userID: userID, paymentAmount: 123, originalTransactionID: transactionInfo.originalTransactionId, transactionID: transactionInfo.transactionId, iapIdentifier: productID, generateTime: Date.now, completeTime: completeTime, cancelTime: nil, refundTime: nil, expirationTime: expiresDate)
			return try await order.save(on: req.db)
		}
		
		// Here means it's not a vip subscription, so we create language cache from iap identifier, then create order with the cache
		guard let language = try await language else {
			// Send email, either no language is found for the given in app purchase identifier, or the found language is not published
			print("language is not found, or the language is not published")
			throw OrderError.invalidIAPIdentifier(id: productID)
		}
		
		// We have made sure language is published, it's safe here to force try.
		let cache = try! LanguageCache(from: language)
		
		// Generate the order
		let order = Order(status: .completed, languageCaches: [cache], userID: userID, paymentAmount: 123, originalTransactionID: transactionInfo.originalTransactionId, transactionID: transactionInfo.transactionId, iapIdentifier: productID, generateTime: Date.now, completeTime: completeTime, cancelTime: nil, refundTime: nil, expirationTime: expiresDate)
		
		return try await order.create(on: req.db)
	}
	
	func processNotification(_ req: Request, notification: NotificationPayload) async throws {
		// Make sure pre-conditions are met
		guard notification.data.environment == .sandbox else {
			print("enviroment doesn't match")
			throw GeneralInputError.invalidDataStructure
		}
		guard notification.data.bundleId == appleBundleID else {
			print("bundle id doesn't match")
			throw GeneralInputError.invalidDataStructure
		}
		
		print(notification.notificationType)
		print(notification.subtype ?? "")
		
		let data = notification.data
		let signedRenewalInfo = try req.application.jwt.signers.verifyJWSWithX5C(data.signedRenewalInfo, as: SignedRenewalInfo.self, rootCert: "")
		
		let signedTransactionInfo = try req.application.jwt.signers.verifyJWSWithX5C(data.signedTransactionInfo, as:   SignedTransactionInfo.self, rootCert: "")
		
		print(signedRenewalInfo)
		print(signedTransactionInfo)
		guard let userID = signedTransactionInfo.appAccountToken else {
			// send email, no user ID is found for the notification
			print("user id not found")
			throw AuthenticationError.userNotFound
		}
		
		// Make sure userID can be found in db, eg: in case the user has been deleted, no need to process its orders
		guard try await User.find(userID, on: req.db) != nil else {
			print("User can not be found, can not process its orders")
			throw AuthenticationError.userNotFound
		}
		
		switch notification.notificationType {
			case .didRenew:
				try await subscribe(req, transactionInfo: signedTransactionInfo, renewalInfo: signedRenewalInfo, userID: userID)
			case .expired:
				break
			case .gracePeriodExpired:
				break
			case .refund:
				break
			case .renewalExtended:
				break
			case .subscribed:
				try await subscribe(req, transactionInfo: signedTransactionInfo, renewalInfo: signedRenewalInfo, userID: userID)
			default:
				break
		}
	}
	
	
}
