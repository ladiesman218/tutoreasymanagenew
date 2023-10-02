//
//  File.swift
//  
//
//  Created by Lei Gao on 2023/9/15.
//

import Vapor
import Fluent

struct AdminOrderController: RouteCollection {
	struct OrderInput: Codable {
		let expirationTime: Date?
		let paymentAmount: Float?
		let refundTime: Date?
		let refundAmount: Float?
	}
	
	static func getUser(_ req: Request) async throws -> User {
		guard let idString = req.parameters.get("userID"), let id = User.IDValue(uuidString: idString) else {
			throw OrderError.invalidInput
		}
		
		guard let user = try await User.find(id, on: req.db) else { throw AuthenticationError.userNotFound }
		return user
	}
		
	func boot(routes: RoutesBuilder) throws {
		let orderAPI = routes.grouped([AdminUser.sessionAuthenticator(), AdminUser.guardMiddleware()]).grouped("api", "admin", "order")
		orderAPI.post("create", ":userID", use: createOrder)
		orderAPI.get("user", ":userID", use: getAllOrders)
		orderAPI.get(":\(OrderController.idParaName)", use: getOrder)
		orderAPI.get("valid", ":userID", use: getValidOrders)
		orderAPI.post("cancel", ":userID", ":\(OrderController.idParaName)", use: cancelOrder)
		orderAPI.post("delete", ":userID", ":\(OrderController.idParaName)", use: deleteOrder)
		
		orderAPI.post("complete", ":userID", ":\(OrderController.idParaName)", use: completeOrder)
		orderAPI.post("refund", ":userID", ":\(OrderController.idParaName)", use: refundOrder)
		
		orderAPI.get(use: getOrdersForAllUsers)
		orderAPI.get("valid", use: getValidOrdersForAllUsers)
	}
	
	func createOrder(_ req: Request) async throws -> HTTPStatus {
		let user = try await Self.getUser(req)
		return try await OrderController.createOrder(req, user: user)
	}
	
	func getAllOrders(_ req: Request) async throws -> Response {
		let user = try await Self.getUser(req)
		let orders = try await OrderController.getAllOrders(req, for: user)
		return try await req.response(of: orders, cacheControl: noCache)
	}
	
	func getOrder(_ req: Request) async throws -> Response {
		let order = try await OrderController.getOrder(req)
		return try await req.response(of: order, cacheControl: noCache)
	}
	
	func getValidOrders(_ req: Request) async throws -> Response {
		let user = try await Self.getUser(req)
		let allOrders = try await OrderController.getAllOrders(req, for: user)
		let validOrders = OrderController.filterAllValidOrders(orders: allOrders)
		
		return try await req.response(of: validOrders, cacheControl: noCache)
	}
	
	func cancelOrder(_ req: Request) async throws -> HTTPStatus {
		let user = try await Self.getUser(req)
		return try await OrderController.cancelOrder(req, for: user)
	}
	
	func deleteOrder(_ req: Request) async throws -> HTTPStatus {
		let user = try await Self.getUser(req)
		return try await OrderController.deleteOrder(req, for: user)
	}
	
	// This function is only needed for admin authorization
	func completeOrder(_ req: Request) async throws -> HTTPStatus {
		let user = try await Self.getUser(req)
		let order = try await OrderController.getOrder(req)
		guard order.status == .unPaid else { throw OrderError.invalidStatus }
		guard order.$user.id == user.id else { throw OrderError.invalidInput }
		order.status = .completed
		let completeTime = Date.now
		order.completeTime = completeTime
		
		let content = try req.content.decode(OrderInput.self)
		// Give it a one year later expiration time, if not presented
		order.expirationTime = content.expirationTime ?? Date(timeInterval: 60 * 60 * 24 * 365, since: completeTime)
		// If payment amount is found, change it, otherwise leave it untouched
		if let paymentAmount = content.paymentAmount { order.paymentAmount = paymentAmount }
		
		try await order.save(on: req.db)
		return .ok
	}
	
	// This function is only needed for admin authorization
	func refundOrder(_ req: Request) async throws -> HTTPStatus {
		let order = try await OrderController.getOrder(req)
		guard order.status == .completed else { throw OrderError.invalidStatus }
		
		let content = try req.content.decode(OrderInput.self)
		guard let refundAmount = content.refundAmount else { throw OrderError.invalidInput }
		order.refundAmount = refundAmount
		order.refundTime = content.refundTime ?? Date.now
		order.status = .refunded
		
		try await order.save(on: req.db)
		return .ok
	}
	
	func getValidOrdersForAllUsers(_ req: Request) async throws -> Response {
		let allOrders = try await Order.query(on: req.db).all()
		
		let validOrders = OrderController.filterAllValidOrders(orders: allOrders)
		return try await req.response(of: validOrders, cacheControl: noCache)
	}
	
	func getOrdersForAllUsers(_ req: Request) async throws -> Response {
		let orders = try await Order.query(on: req.db).all()
		return try await req.response(of: orders, cacheControl: noCache)
	}
}
