//
//  File.swift
//  
//
//  Created by Lei Gao on 2023/9/15.
//

import Vapor
import Queues
import Fluent

struct OrderExecution: Codable {
	
	enum Execution: Codable {
		case cancel, delete
	}
	
	let execution: Execution
	let id: Order.IDValue
}

struct OrderJobs: AsyncJob {
	typealias Payload = OrderExecution
	
	func dequeue(_ context: QueueContext, _ payload: Payload) async throws {
		guard let order = try await Order.find(payload.id, on: context.application.db) else {
			throw OrderError.idNotFound(id: payload.id)
		}
		
		switch payload.execution {
			case .cancel:
				guard order.status == .unPaid else { return }
				order.status = .cancelled
				order.cancelTime = Date.now
				try await order.save(on: context.application.db)
			case .delete:
				guard order.status == .unPaid || order.status == .cancelled else { return }
				try await order.delete(on: context.application.db)
		}
	}
	
	func error(_ context: QueueContext, _ error: Error, _ payload: Payload) async throws {
		print("execute order job failed")
		print(error.localizedDescription)
		// If you don't want to handle errors you can simply return. You can also omit this function entirely.
	}
}

// After a order has been cancelled more than 1 month, delete it from db
struct PurgeOrder: AsyncScheduledJob {
	func run(context: Queues.QueueContext) async throws {
		let database = context.queue.context.application.db
		let cancelledOrders = try await Order.query(on: database).filter(\.$status == .cancelled).all()
		guard cancelledOrders.allSatisfy({
			$0.cancelTime != nil
		}) else {
			return
		}
		let oneMonth: Double = 30 * 24 * 60 * 60
		let invalidOrders = cancelledOrders.filter {
			// Calculate orders' cancelTime plus one month time period
			let aMonthLater = Date(timeInterval: oneMonth, since: $0.cancelTime!)
			return aMonthLater <= Date.now
		}
		
		try await invalidOrders.delete(on: database)
	}
}
