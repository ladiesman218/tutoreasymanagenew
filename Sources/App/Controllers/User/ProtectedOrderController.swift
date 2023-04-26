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

		protectedRoute.get("create", use: createOrder)
		protectedRoute.get(":id", use: getOrder)
		protectedRoute.get(use: getAllOrders)
		protectedRoute.get("valid", use: getAllValidOrders)
		protectedRoute.post("delete", ":id", use: deleteOrder)
	}
	
	func getAllOrders(_ req: Request) async throws -> Response {
		let user = try req.auth.require(User.self)
		let orders = try await user.$orders.get(on: req.db)
		var headers = HTTPHeaders()
		headers.add(name: .eTag, value: orders.hashValue.description)
		return try await orders.encodeResponse(status: .ok, headers: headers, for: req)
	}
	
	#warning("this and the following are duplicates")
	func getAllValidOrders(_ req: Request) async throws -> Response {
		let allOrders = try await getAllOrders(req).content.decode([Order].self)
		print(allOrders)
		// First, filter out orders that have expirationTime, since expirationTime is optional
		let subscriptionOrders = allOrders.filter {
			$0.expirationTime != nil
		}
		let validOrders = subscriptionOrders.filter {
			$0.status == .completed && $0.expirationTime! > Date.now
		}
		var headers = HTTPHeaders()
		headers.add(name: .eTag, value: validOrders.hashValue.description)
		return try await validOrders.encodeResponse(status: .ok, headers: headers, for: req)
	}
	
	// This is only called from IAPController
	func getAllValidOrdersForUser(_ req: Request, userID: User.IDValue) async throws -> Response {
		let allOrders = try await getAllOrders(req).content.decode([Order].self)
		// First, filter out orders that have expirationTime, since expirationTime is optional
		let subscriptionOrders = allOrders.filter {
			$0.expirationTime != nil
		}
		let validOrders = subscriptionOrders.filter {
			$0.status == .completed && $0.expirationTime! > Date.now
		}
		var headers = HTTPHeaders()
		headers.add(name: .eTag, value: validOrders.hashValue.description)
		return try await validOrders.encodeResponse(status: .ok, headers: headers, for: req)
	}
	
	func getOrder(_ req: Request) async throws -> Response {
		let user = try req.auth.require(User.self)
		guard let idString = req.parameters.get("id"), let id = Order.IDValue(idString) else {
			throw GeneralInputError.invalidID
		}
		// Make sure the given orderID belongs to the user
		let orders = try await user.$orders.get(on: req.db)
		guard let order = orders.filter({ $0.id! == id }).first else {
			throw OrderError.idNotFound(id: id)
		}
		
		var headers = HTTPHeaders()
		headers.add(name: .eTag, value: order.hashValue.description)
		return try await order.encodeResponse(status: .ok, headers: headers, for: req)
	}
	
	func createOrder(_ req: Request) async throws -> HTTPStatus {
		let userID = try req.auth.require(User.self).requireID()
		let courseIDs = try req.content.decode(Order.Input.self).courseIDs.uniqued()
		
		let courses = try await withThrowingTaskGroup(of: Course.self, body: { group in
			var courses = [Course]()
			for id in courseIDs {
				group.addTask {
					guard let course = try await Course.find(id, on: req.db) else {
						throw CourseError.idNotFound(id: id)
					}
					return course
				}
				
			}
			for try await course in group { courses.append(course) }
			return courses
		})
		let caches = courses.map { try! CourseCache(from: $0) }
		let order = Order(courseCaches: caches, userID: userID, paymentAmount: 123, transactionID: "asdf")
		try await order.save(on: req.db)
		return .created
	}
	// completeOrder should NOT be directly exposed via API endpoint, otherwise a user can access that endpoint and change the order status to completed. Instead, this should be called inside the payment's handler's callback function
	func completeOrder(_ req: Request) async throws -> HTTPStatus {
		let order = try await getOrder(req).content.decode(Order.self)
		guard order.status == .unPaid else {
			throw OrderError.invalidStatus
		}
		order.status = .completed
		order.completeTime = Date.now
		try await order.update(on: req.db)
		return .ok
	}
	
	#warning("How should this be called? User shouldn't call this with its own authentication")
	func refundOrder(_ req: Request) async throws -> HTTPStatus {
		let order = try await getOrder(req).content.decode(Order.self)
		guard order.status == .completed else {
			throw OrderError.invalidStatus
		}
		
		order.status = .refunded
		order.refundTime = Date.now
		try await order.update(on: req.db)
		return .ok
	}
		
	func cancelOrder(_ req: Request) async throws -> HTTPStatus {
		let order = try await getOrder(req).content.decode(Order.self)
		guard order.status == .unPaid else {
			throw OrderError.invalidStatus
		}
		
		order.status = .canceled
		order.cancelTime = Date.now
		try await order.update(on: req.db)
		return .ok
	}

	func deleteOrder(_ req: Request) async throws -> HTTPStatus {
		let order = try await getOrder(req).content.decode(Order.self)
		guard order.status == .unPaid || order.status == .canceled else {
			throw OrderError.invalidStatus
		}
		
		try await order.delete(on: req.db)
		return .ok
	}
}
