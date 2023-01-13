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

		protectedRoute.get(":id", use: getOrder)
		protectedRoute.get(use: getAllOrders)
		protectedRoute.get("valid", use: getAllValidOrders)
		protectedRoute.post("delete", ":id", use: deleteOrder)
	}
	
	func getAllOrders(_ req: Request) async throws -> [Order] {
		let user = try req.auth.require(User.self)
		return try await user.$orders.get(on: req.db)
	}
	
	func getAllValidOrders(_ req: Request) async throws -> [Order] {
		let allOrders = try await getAllOrders(req)
		// First, filter out orders that have expirationTime, since expirationTime is optional
		let subscriptionOrders = allOrders.filter {
			$0.expirationTime != nil
		}
		let validOrders = subscriptionOrders.filter {
			$0.status == .completed && $0.expirationTime! > Date.now
		}
		return validOrders
	}
	
	func getAllOrdersForUser(_ req: Request, userID: User.IDValue) async throws -> [Order] {
		guard let user = try await User.find(userID, on: req.db) else {
			throw AuthenticationError.userNotFound
		}
		return try await user.$orders.get(on: req.db)
	}
	
	func getAllValidOrdersForUser(_ req: Request, userID: User.IDValue) async throws -> [Order] {
		let allOrders = try await getAllOrdersForUser(req, userID: userID)
		// First, filter out orders that have expirationTime, since expirationTime is optional
		let subscriptionOrders = allOrders.filter {
			$0.expirationTime != nil
		}
		let validOrders = subscriptionOrders.filter {
			$0.status == .completed && $0.expirationTime! > Date.now
		}
		return validOrders
	}
	
	func getOrder(_ req: Request) async throws -> Order {
		let user = try req.auth.require(User.self)
		guard let idString = req.parameters.get("id"), let id = Order.IDValue(idString) else {
			throw GeneralInputError.invalidID
		}
		// Make sure the given orderID belongs to the user
		let orders = try await user.$orders.get(on: req.db)
		guard let order = orders.filter({ $0.id! == id }).first else {
			throw OrderError.idNotFound(id: id)
		}
		return order
	}
	
	// completeOrder should NOT be directly exposed via API endpoint, otherwise a user can access that endpoint and change the order status to completed. Instead, this should be called inside the payment's handler's callback function
	func completeOrder(_ req: Request) async throws -> HTTPStatus {
		let order = try await getOrder(req)
		guard order.status == .unPaid else {
			throw OrderError.invalidStatus
		}
		order.status = .completed
		order.completeTime = Date.now
		try await order.update(on: req.db)
		return .ok
	}
	
	#warning("How should this be called?")
	func refundOrder(_ req: Request) async throws -> HTTPStatus {
		let order = try await getOrder(req)
		guard order.status == .completed else {
			throw OrderError.invalidStatus
		}
		
		order.status = .refunded
		order.refundTime = Date.now
		try await order.update(on: req.db)
		return .ok
	}
		
	func cancelOrder(_ req: Request) async throws -> HTTPStatus {
		let order = try await getOrder(req)
		guard order.status == .unPaid else {
			throw OrderError.invalidStatus
		}
		
		order.status = .canceled
		order.cancelTime = Date.now
		try await order.update(on: req.db)
		return .ok
	}

	func deleteOrder(_ req: Request) async throws -> HTTPStatus {
		let order = try await getOrder(req)
		guard order.status == .unPaid || order.status == .canceled else {
			throw OrderError.invalidStatus
		}
		
		try await order.delete(on: req.db)
		return .ok
	}
}
