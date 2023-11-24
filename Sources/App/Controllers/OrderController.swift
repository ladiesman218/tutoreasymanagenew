//
//  File.swift
//  
//
//  Created by Lei Gao on 2023/9/15.
//

import Vapor
import Fluent
import Queues

// Both admin and users can create, read, cancel, delete orders, so this struct acts as a shared order manager, admin and user controller should call these to avoid implementing duplicate functions. User's identity is needed for order's CRUD operations, but it will be retrieved differetly in admin and user controller. So all functions in this controller should pass in user as parameter. Also all functions in this controller should not return Response saying .notModified, otherwise callers have no response body to be decoded into the actual orders.
struct OrderController {
	
	static let idParaName = "orderID"
	
	static func createOrder(_ req: Request, user: User) async throws -> HTTPStatus {
		// Use map coz unique sequence doesn't have a .isEmpty property
		let courseIDs = try req.content.decode([Order.IDValue].self).uniqued().map { $0 }
		guard !courseIDs.isEmpty else { throw GeneralInputError.invalidID }
		// Only verified user can create new order
		guard user.verified else { throw AuthenticationError.emailIsNotVerified }
		let userID = try user.requireID()

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
		let order = Order(courseCaches: caches, userID: userID, paymentAmount: 0, transactionID: "asdf")
		try await order.save(on: req.db)
		try await queueCancelOrder(req, orderID: order.requireID())
		return .created
	}
	
	static func getAllOrders(_ req: Request, for user: User) async throws -> [Order] {
		let orders = try await user.$orders.get(on: req.db)
		return orders
	}

	static func getOrder(_ req: Request) async throws -> Order {
		guard let idString = req.parameters.get(idParaName), let id = Order.IDValue(idString) else {
			throw GeneralInputError.invalidID
		}
		
		guard let order = try await Order.find(id, on: req.db) else { throw OrderError.idNotFound(id: id) }
		return order
	}
	
	static func filterAllValidOrders(orders: [Order]) -> [Order] {
		// First, filter out orders that have expirationTime, since expirationTime is optional
		let subscriptionOrders = orders.filter {
			$0.expirationTime != nil
		}
		
		let validOrders = subscriptionOrders.filter {
			// Refunded orders may also have expirationTime, so this needs to be .completed.
			$0.status == .completed && $0.expirationTime! > Date.now
		}
		
		return validOrders
	}
	
	static func cancelOrder(_ req: Request, for user: User) async throws -> HTTPStatus {
		let userID = try user.requireID()
		let order = try await getOrder(req)
		guard order.$user.id == userID else { throw OrderError.invalidInput }
		guard order.status == .unPaid else { throw OrderError.invalidStatus }
		
		order.cancelTime = Date.now
		order.status = .cancelled
		try await order.save(on: req.db)
		return .ok
	}
	
	static func deleteOrder(_ req: Request, for user: User) async throws -> HTTPStatus {
		let userID = try user.requireID()
		let order = try await getOrder(req)
		guard order.status == .unPaid || order.status == .cancelled else {
			throw OrderError.invalidStatus
		}
		guard order.$user.id == userID else { throw OrderError.invalidInput }
		
		try await order.delete(on: req.db)
		return .noContent
	}
	
	static func queueCancelOrder(_ req: Request, orderID: Order.IDValue) async throws {
		// Delay the job after 15 mins
		let futureDate = Date(timeIntervalSinceNow: 60 * 15)
		try await req.queue.dispatch(OrderJobs.self, OrderExecution(execution: .cancel, id: orderID), delayUntil: futureDate)
	}
}
