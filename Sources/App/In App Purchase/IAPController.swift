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
		let courses = try await Course.query(on: req.db).filter(\.$published == true).all()
		guard !courses.contains(where: { $0.annuallyIAPIdentifier.isEmpty }) else {
			let error = Abort(.internalServerError, reason: "At least 1 published course has an empty IAP identifier")
			Email.alertAdmin(error: error, client: req.client)
			throw error
		}
		var identifiers = courses.map { $0.annuallyIAPIdentifier }
		identifiers.append(vipIAPIdentifier)
		return identifiers
	}
		
	func getNotification(_ req: Request) async throws -> HTTPStatus {
		// For version 2 notifications, it retries five times; at 1, 12, 24, 48, and 72 hours after the previous attempt.
		//https://developer.apple.com/documentation/appstoreservernotifications/responding_to_app_store_server_notifications
//		do {
			let notification = try req.content.decode(SignedPayload.self)
			
			let payload = try req.application.jwt.signers.verifyJWSWithX5C(
				notification.signedPayload,
				as: NotificationPayload.self,
				rootCert: "")
			try await processNotification(req, notification: payload)
			return .ok
//		} catch {
//			print(error)
//			return .internalServerError
//		}
	}
	
	func subscribe(_ req: Request, transactionInfo: SignedTransactionInfo, renewalInfo: SignedRenewalInfo, userID: User.IDValue) async throws {
		
		let transactionID = transactionInfo.transactionId
		let productID = transactionInfo.productId

//		async let validOrders = ProtectedOrderController().getAllValidOrders(req, userID: userID).content.decode([Order].self)
		guard let user = try await User.find(userID, on: req.db) else { throw AuthenticationError.userNotFound }
		async let orders = OrderController.getAllOrders(req, for: user)
		async let course = Course.query(on: req.db).group(.and) { group in
			group.filter(\.$annuallyIAPIdentifier == productID)
			group.filter(\.$published == true)
		}.first()
		
		// Make sure payload contains valid data
		guard let expiresMilliSecond = transactionInfo.expiresDate else {
			// Send email, expiration date is missing, this should never happen.
			throw GeneralInputError.invalidDataStructure
		}
		guard transactionInfo.type == "Auto-Renewable Subscription" else {
			// Send email, we are processing a new subscription with the wrong method
			throw GeneralInputError.invalidDataStructure
		}
		
		let validOrders = try await OrderController.filterAllValidOrders(orders: orders)
		
		// Sometimes we get duplicate notifications. We've checked all possible reasons, it's not because the wrong response we replied to apple server, so maybe a time-out occured while processing the notification, so apple server send the notification again. To avoid duplicate orders created in db due to duplicate notifications, we could check for notification ID but that requires another field in db to store the id, instead we will check for existing transactionId or completeTime(which is SignedTransactionInfo.purchaseDate in essence) or SignedTransactionInfo.expiresDate.
		guard !validOrders.contains(where: { $0.transactionID == transactionID }) else {
			// Here means transactionID exists in db, we probably had process the notification, return the created response.
			return
		}
		
		// Received time stamp is in milli-second format, so devide it by 1000 to convert it to second
		let expiresDate = Date(timeIntervalSince1970: TimeInterval(expiresMilliSecond / 1000))
		let completeTime = Date(timeIntervalSince1970: TimeInterval(transactionInfo.purchaseDate / 1000))
		
		guard Date.now < expiresDate else {
			// Send email, expire time is earlier than current time, this should never happen
			throw GeneralInputError.invalidDataStructure
		}
		
		// If VIP membership is being purchased, handle it first, then return.
		if productID == vipIAPIdentifier {
			// Generate the order
			let emptyCache = CourseCache(id: UUID(), name: "vip", description: "", price: 123, iapIdentifier: vipIAPIdentifier)
			let order = Order(status: .completed, courseCaches: [emptyCache], userID: userID, paymentAmount: 123, originalTransactionID: transactionInfo.originalTransactionId, transactionID: transactionInfo.transactionId, iapIdentifier: productID, generateTime: Date.now, completeTime: completeTime, cancelTime: nil, refundTime: nil, expirationTime: expiresDate)
			return try await order.save(on: req.db)
		}
		
		// Here means it's not a vip subscription, so we create course cache from iap identifier, then create order with the cache
		guard let course = try await course else {
			// Send email, either no course is found for the given in app purchase identifier, or the found course is not published
			throw OrderError.invalidIAPIdentifier(id: productID)
		}
		
		// We have made sure course is published, it's safe here to force try.
		let cache = try! CourseCache(from: course)
		
		// Generate the order
		let order = Order(status: .completed, courseCaches: [cache], userID: userID, paymentAmount: 123, originalTransactionID: transactionInfo.originalTransactionId, transactionID: transactionInfo.transactionId, iapIdentifier: productID, generateTime: Date.now, completeTime: completeTime, cancelTime: nil, refundTime: nil, expirationTime: expiresDate)
		
		return try await order.create(on: req.db)
	}
	
	func processNotification(_ req: Request, notification: NotificationPayload) async throws {
		#warning("Make sure pre-conditions are met")
		guard notification.data.environment == .sandbox else {
			throw GeneralInputError.invalidDataStructure
		}
		guard notification.data.bundleId == appleBundleID else {
			throw GeneralInputError.invalidDataStructure
		}
		
		print(notification.notificationType)
		print(notification.subtype ?? "unknown notification subtype")
		
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
		guard let user = try await User.find(userID, on: req.db) else {
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
