//
//  File.swift
//  
//
//  Created by Lei Gao on 2022/11/22.
//

import Vapor
import Fluent

struct ProtectedOrderController: RouteCollection {
	func boot(routes: RoutesBuilder) throws {
		let protectedRoute = routes.grouped("api", "order").grouped(Token.authenticator(), User.guardMiddleware())
//		protectedRoute.post(use: createOrderFromLanIDs)
		protectedRoute.get(":id", use: getOrder)
		protectedRoute.get(use: getAllOrders)
		protectedRoute.get("valid", use: getAllValidOrders)
		protectedRoute.post("delete", ":id", use: deleteOrder)
	}
	
//	func createOrderFromLanIDs(_ req: Request) -> EventLoopFuture<HTTPStatus> {
//		guard let userID = try? req.auth.require(User.self).requireID() else {
//			return req.eventLoop.future(error: AuthenticationError.userNotFound)
//		}
//
//		guard let input = try? req.content.decode(Order.Input.self) else {
//			return req.eventLoop.future(error: OrderError.invalidInput)
//		}
//
//		// Remove duplicate ids
//		let languageIDs = input.languageIDs.uniqued()
//
//		return languageIDs.map { Language.find($0, on: req.db).unwrap(or: LanguageError.idNotFound(id: $0))
//				.guard({ language in
//					language.published
//				}, else: LanguageError.idNotFound(id: $0))
//		}.flatten(on: req.eventLoop).flatMap { languages -> EventLoopFuture<HTTPStatus> in
//
//			guard !languages.isEmpty else { return req.eventLoop.future(HTTPStatus.badRequest) }
//			// We have made sure all languages are published when quering, it's safe here to use !
//			let caches = languages.compactMap { try! LanguageCache(from: $0) }
//
//			// Calculate total payment for the given languages
//			let paymentAmount = caches.reduce(0) { partialResult, cache in
//				partialResult + cache.price
//			}
//
//			let iapIdentifier: String? = (caches.count == 1) ? caches.first!.iapIdentifier : nil
//
//			let order = Order(status: .unPaid, languageCaches: caches, userID: userID, paymentAmount: paymentAmount, originalTransactionID: nil, transactionID: "", iapIdentifier: iapIdentifier, generateTime: Date.now, completeTime: nil, cancelTime: nil, refundTime: nil, expirationTime: nil)
//			order.$user.id = userID
//
//			return order.save(on: req.db).transform(to: .ok)
//		}
//	}
	
	func getAllOrders(req: Request) -> EventLoopFuture<[Order]> {
		guard let user = req.auth.get(User.self) else {
			return req.eventLoop.future(error: AuthenticationError.userNotFound)
		}
		
		return user.$orders.get(on: req.db)
	}
	
	func getAllValidOrders(req: Request) -> EventLoopFuture<[Order]> {
		return getAllOrders(req: req).map { orders in
			// First, filter out orders that have expirationTime, since expirationTime can be nil.
			let subscriptionOrders = orders.filter {
				$0.expirationTime != nil
			}
			let validOrders = subscriptionOrders.filter {
				$0.status == .completed && $0.expirationTime! > Date.now
			}
			return validOrders
		}
	}
	
	func getOrder(req: Request) -> EventLoopFuture<Order> {
		guard let user = try? req.auth.require(User.self) else {
			return req.eventLoop.future(error: AuthenticationError.userNotFound)
		}
		guard let idString = req.parameters.get("id"), let id = Order.IDValue(idString) else {
			return req.eventLoop.future(error: GeneralInputError.invalidID)
		}
		// Make sure the given orderID belongs to the user
		return user.$orders.get(on: req.db).flatMap { orders in
			guard let order = orders.filter({ $0.id! == id }).first else {
				return req.eventLoop.future(error: OrderError.idNotFound(id: id))
			}
			return req.eventLoop.future(order)
		}
	}
	
	// completeOrder should NOT be directly exposed via API endpoint, otherwise a user can access that endpoint and change the order status to completed. Instead, this should be called inside the payment's handler's callback function
	func completeOrder(_ req: Request) -> EventLoopFuture<HTTPStatus> {
		guard let user = try? req.auth.require(User.self) else {
			return req.eventLoop.future(error: AuthenticationError.userNotFound)
		}
		guard let idString = req.parameters.get("id"), let orderID = Order.IDValue(idString) else {
			return req.eventLoop.future(error: OrderError.invalidInput)
		}
		
		return user.$orders.get(on: req.db).flatMap { orders in
			guard let order = orders.filter({ $0.id! == orderID }).first else {
				return req.eventLoop.future(error: OrderError.idNotFound(id: orderID))
			}
			guard order.status == .unPaid else {
				return req.eventLoop.future(error: OrderError.invalidStatus)
			}

			order.status = .completed
			order.completeTime = Date.now
			return order.update(on: req.db).transform(to: HTTPStatus.ok)
		}
	}
	#warning("How should this be called?")
	func refundOrder(_ req: Request) -> EventLoopFuture<HTTPStatus> {
		
		guard let idString = req.parameters.get("id"), let orderID = Order.IDValue(idString) else {
			return req.eventLoop.future(error: OrderError.invalidInput)
		}
		
		return Order.find(orderID, on: req.db).unwrap(or: OrderError.idNotFound(id: orderID)).flatMap { order in
			guard order.status == .completed else { return req.eventLoop.future(error: OrderError.invalidStatus) }
			order.status = .refunded
			return order.update(on: req.db).transform(to: .ok)
		}
	}
	
	func cancelOrder(_ req: Request) -> EventLoopFuture<HTTPStatus> {
		
		guard let idString = req.parameters.get("id"), let orderID = Order.IDValue(idString) else {
			return req.eventLoop.future(error: OrderError.invalidInput)
		}
		
		return Order.find(orderID, on: req.db).unwrap(or: OrderError.idNotFound(id: orderID)).flatMap { order in
			guard order.status == .unPaid else { return req.eventLoop.future(error: OrderError.invalidStatus) }
			order.status = .canceled
			return order.update(on: req.db).transform(to: .ok)
		}
	}
	
	func deleteOrder(_ req: Request) -> EventLoopFuture<HTTPStatus> {
		guard let user = try? req.auth.require(User.self) else {
			return req.eventLoop.future(error: AuthenticationError.userNotFound)
		}
		
		guard let idString = req.parameters.get("id"), let orderID = Order.IDValue(idString) else {
			return req.eventLoop.future(error: OrderError.invalidInput)
		}
		
		return user.$orders.get(on: req.db).flatMap { orders in
			guard let order = orders.filter({ $0.id! == orderID }).first else {
				return req.eventLoop.future(error: OrderError.idNotFound(id: orderID))
			}
			
			guard order.status == .unPaid || order.status == .canceled else {
				return req.eventLoop.future(error: OrderError.invalidStatus)
			}
			
			return order.delete(on: req.db).transform(to: .ok)
		}
	}
}
