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

struct IAPController: RouteCollection {
	func boot(routes: RoutesBuilder) throws {
		let iapProductRoute = routes.grouped("api", "iap")
		iapProductRoute.get(use: getProductIdentifiers)
		
		let notificationRoute = routes.grouped("api", "assn", "v2")
		notificationRoute.on(.POST, body: .collect(maxSize: "512kb"), use: getNotification)
	}
	
	func getProductIdentifiers(_ req: Request) -> EventLoopFuture<[String]> {
		return Language.query(on: req.db).filter(\.$published == true).all().map { languages in
			guard !languages.contains(where: { $0.annuallyIAPIdentifier.isEmpty } ) else {
				// Send email to admin: at least 1 published language has an empty IAP identifier
				return []
			}
			var identifiers = languages.map { $0.annuallyIAPIdentifier }
			identifiers.append(vipIAPIdentifier)
			return identifiers
		}
	}
	
	func getNotification(_ req: Request) -> EventLoopFuture<HTTPStatus> {
		do {
			let notification = try req.content.decode(SignedPayload.self)
			
			let payload = try req.application.jwt.signers.verifyJWSWithX5C(
				notification.signedPayload,
				as: NotificationPayload.self,
				rootCert: "")
			
			try processNotification(req, notification: payload)
			return req.eventLoop.future(HTTPStatus.ok)
			
		} catch {
			print("error found: \(error)")
			// For version 2 notifications, it retries five times; at 1, 12, 24, 48, and 72 hours after the previous attempt.
			// https://developer.apple.com/documentation/appstoreservernotifications/responding_to_app_store_server_notifications
			return req.eventLoop.future(HTTPStatus.badRequest)
		}
	}
	
	func subscribe(_ req: Request, transactionInfo: SignedTransactionInfo, renewalInfo: SignedRenewalInfo, userID: User.IDValue) throws -> EventLoopFuture<HTTPStatus> {
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
		
		let transactionID = transactionInfo.transactionId
		let productID = transactionInfo.productId

		// Sometimes we get duplicate notifications. We've checked all possible reasons, it's not because the wrong response we replied to apple server, so maybe a time-out occured while processing the notification. To avoid duplicate orders created in db, we could check for notification ID but that requires another field in db to store the id, instead we will check for existing transactionId or completeTime(which is SignedTransactionInfo.purchaseDate in essence) or SignedTransactionInfo.expiresDate.
		return ProtectedOrderController().getAllValidOrders(req: req).flatMapError({ error in
			print(error)
			return req.eventLoop.future( [Order]())
		})
		.flatMap { orders in
			print("orders are: \(orders)")
			guard !orders.contains(where: { $0.transactionID == transactionID }) else {
				// Here means transactionID exists in db, we probably had process the notification, return the created response.
				print("The order has been saved")
				return req.eventLoop.future(HTTPStatus.created)
			}
			
			// Received time stamp is in milli-second format, so devide it by 1000 to convert it to second
			let expiresDate = Date(timeIntervalSince1970: TimeInterval(expiresMilliSecond / 1000))
			let completeTime = Date(timeIntervalSince1970: .init(transactionInfo.purchaseDate / 1000))
			
			guard Date.now < expiresDate else {
				// Send email, expire time is earlier than current time, this should never happen
				print("expiresDate is earlier than current time")
				return req.eventLoop.future(error: GeneralInputError.invalidDataStructure)
			}
			
			// If VIP membership is being purchased, handle it and then return.
			if productID == vipIAPIdentifier {
				
				// Generate the order
				let emptyCache = LanguageCache(languageID: UUID(), name: "vip", description: "", price: 123, iapIdentifier: vipIAPIdentifier)
				let order = Order(status: .completed, languageCaches: [emptyCache], userID: userID, paymentAmount: 123, originalTransactionID: transactionInfo.originalTransactionId, transactionID: transactionInfo.transactionId, iapIdentifier: productID, generateTime: Date.now, completeTime: completeTime, cancelTime: nil, refundTime: nil, expirationTime: expiresDate)
				return order.save(on: req.db).transform(to: HTTPStatus.created)
			}
			
			// Here means it's not a vip subscription, so we create language cache from iap identifier, then create order with the cache
			return Language.query(on: req.db).filter(\.$annuallyIAPIdentifier == productID).first().flatMap { lan in
				guard let lan = lan else {
					// Send email, no language is found for the given in app purchase identifier
					print("language is not found")
					return req.eventLoop.future(error: OrderError.invalidIAPIdentifier(id: productID))
				}
				
				guard lan.published else {
					// Send email, language is not published, admin should check app store connect selling products against languages in db
					print("language is not published")
					return req.eventLoop.future(error: LanguageError.notForSale)
				}
				
				// We have made sure language is published, it's safe here to force try.
				let cache = try! LanguageCache(from: lan)
				
				// Generate the order
				let order = Order(status: .completed, languageCaches: [cache], userID: userID, paymentAmount: 123, originalTransactionID: transactionInfo.originalTransactionId, transactionID: transactionInfo.transactionId, iapIdentifier: productID, generateTime: Date.now, completeTime: completeTime, cancelTime: nil, refundTime: nil, expirationTime: expiresDate)
				
				return order.create(on: req.db).transform(to: HTTPStatus.created)
			}
		}
	}
	
	func processNotification(_ req: Request, notification: NotificationPayload) throws {
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
		
		switch notification.notificationType {
			case .didRenew:
				let _ = try subscribe(req, transactionInfo: signedTransactionInfo, renewalInfo: signedRenewalInfo, userID: userID)
			case .expired:
				break
			case .gracePeriodExpired:
				break
			case .refund:
				break
			case .renewalExtended:
				break
			case .subscribed:
				let _ = try subscribe(req, transactionInfo: signedTransactionInfo, renewalInfo: signedRenewalInfo, userID: userID)
			default:
				break
		}
	}
	
	
}
