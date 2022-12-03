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
		protectedRoute.post(use: generateOrder)
		protectedRoute.get(":id", use: getOrder)
		protectedRoute.get(use: getAllOrders)
		protectedRoute.post("delete", ":id", use: deleteOrder)
	}
	
	func generateOrder(_ req: Request) -> EventLoopFuture<HTTPStatus> {
		guard let userID = try? req.auth.require(User.self).requireID() else {
			return req.eventLoop.future(error: AuthenticationError.userNotFound)
		}
		
		guard let input = try? req.content.decode(Order.Input.self) else {
			return req.eventLoop.future(error: OrderError.invalidInput)
		}
		// Remove duplicate ids
		let languageIDs = input.languageIDs.uniqued()

		return languageIDs.map { Language.find($0, on: req.db).unwrap(or: LanguageError.idNotFound(id: $0))
				.guard({ language in
					language.published
				}, else: LanguageError.idNotFound(id: $0))
		}.flatten(on: req.eventLoop).flatMap { languages -> EventLoopFuture<HTTPStatus> in
			let order = Order()
			order.$user.id = userID
			
			// Calculate total payment for the given languages
			let paymentAmount = languages.reduce(0) { partialResult, language in
				partialResult + language.price
			}
			order.paymentAmount = paymentAmount
			
			return order.save(on: req.db).transform(to: order).flatMap { _ in
				// All languages were found by id just now, so force to initialize a cache is safe here, hence the !
				let caches = languages.map { LanguageCache(from: $0, orderID: order.id!)! }
				
				return caches.map { $0.save(on: req.db) }.flatten(on: req.eventLoop).transform(to: .created)
			}
		}
	}
	
	func getAllOrders(req: Request) -> EventLoopFuture<[Order]> {
		guard let user = req.auth.get(User.self) else {
			return req.eventLoop.future(error: AuthenticationError.userNotFound)
		}
		
		return user.$orders.get(on: req.db).flatMap { orders in
			return orders.map { $0.$items.load(on: req.db) }.flatten(on: req.eventLoop)
		}.transform(to: user.orders)
	}
	
	func getOrder(req: Request) throws -> EventLoopFuture<Order> {
		guard let user = try? req.auth.require(User.self) else {
			throw AuthenticationError.userNotFound
		}
		guard let idString = req.parameters.get("id"), let id = Order.IDValue(idString) else {
			throw GeneralInputError.invalidID
		}
		return user.$orders.get(on: req.db).flatMap { orders in
			guard let order = orders.filter({ $0.id! == id }).first else {
				return req.eventLoop.future(error: OrderError.idNotFound(id: id))
			}
			return order.$items.load(on: req.db).transform(to: order)
		}
	}
	
#warning("修改订单状态需要用户还是管理员的身份？用户身份的话确定是拥有订单的用户在做修改")
	func completeOrder(_ req: Request) -> EventLoopFuture<HTTPStatus> {
		
		guard let idString = req.parameters.get("id"), let orderID = Order.IDValue(idString) else {
			return req.eventLoop.future(error: OrderError.invalidInput)
		}
		
		return Order.find(orderID, on: req.db).unwrap(or: OrderError.idNotFound(id: orderID)).flatMap { order in
			guard order.status == .unPaid else { return req.eventLoop.future(error: OrderError.invalidStatus) }
			order.status = .completed
			return order.update(on: req.db).transform(to: .ok)
		}
	}
	
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
