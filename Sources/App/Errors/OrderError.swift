//
//  File.swift
//  
//
//  Created by Lei Gao on 2022/11/22.
//

import Vapor

enum OrderError: Error {
	case idNotFound(id: Order.IDValue)
	case courseNotFound(id: Course.IDValue)
	case invalidStatus
	case invalidInput
}

extension OrderError: AbortError, DebuggableError {
	var reason: String {
		switch self {
			case .idNotFound(let id):
				return "未找到ID为\(id.uuidString)的订单，请联系网站管理员\(adminEmail)"
			case .courseNotFound(let id):
				return "未找到ID为\(id.uuidString)的课程"
			case .invalidStatus:
				return "订单状态无效"
			case .invalidInput:
				return "无效输入"
		}
	}
	
	var status: HTTPResponseStatus {
		switch self {
			case .idNotFound, .courseNotFound:
				return .notFound
			case .invalidStatus:
				return .preconditionFailed
			case .invalidInput:
				return .badRequest
		}

	}
	
	var identifier: String {
		switch self {
			case .idNotFound(let id):
				return "order_id_not_found: \(id)"
			case .courseNotFound(let id):
				return "course_id_not_found: \(id)"
			case .invalidStatus:
				return "invalid_order_status"
			case .invalidInput:
				return "invalid_order_input"
		}
	}
}
