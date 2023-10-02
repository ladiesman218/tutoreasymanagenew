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
		
		protectedRoute.post("create", use: createOrder)
		protectedRoute.get(use: getAllOrders)
		protectedRoute.get(":\(OrderController.idParaName)", use: getOrder)
		protectedRoute.get("valid", use: getAllValidOrders)
		protectedRoute.post("cancel", ":\(OrderController.idParaName)", use: cancelOrder)
		protectedRoute.post("delete", ":\(OrderController.idParaName)", use: deleteOrder)
	}
	
	func createOrder(_ req: Request) async throws -> HTTPStatus {
		let user = try req.auth.require(User.self)
		return try await OrderController.createOrder(req, user: user)
	}
	
	func getAllOrders(_ req: Request) async throws -> Response {
		let user = try req.auth.require(User.self)
		let orders = try await OrderController.getAllOrders(req, for: user)
		return try await req.response(of: orders, cacheControl: noCache)
	}
	
	func getOrder(_ req: Request) async throws -> Response {
		let user = try req.auth.require(User.self)
		let order = try await OrderController.getOrder(req)
		// Make sure the given orderID belongs to the user
		guard order.$user.id == user.id else { throw OrderError.invalidInput }
		
		return try await req.response(of: order, cacheControl: noCache)
	}
	
	func getAllValidOrders(_ req: Request) async throws -> Response {
		let user = try req.auth.require(User.self)
		let allOrders = try await OrderController.getAllOrders(req, for: user)
		let validOrders = OrderController.filterAllValidOrders(orders: allOrders)
		
		return try await req.response(of: validOrders, cacheControl: noCache)
	}

	func cancelOrder(_ req: Request) async throws -> HTTPStatus {
		let user = try req.auth.require(User.self)
		return try await OrderController.cancelOrder(req, for: user)
	}
	
	func deleteOrder(_ req: Request) async throws -> HTTPStatus {
		let user = try req.auth.require(User.self)
		return try await OrderController.deleteOrder(req, for: user)
	}
}
