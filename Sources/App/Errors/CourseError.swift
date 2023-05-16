import Vapor

enum CourseError: Error {
	case idNotFound(id: UUID)
	case courseNameExisted(name: String)
	case nameNotFound(name: String)
	case notForSale
	case invalidAppStoreID
	case notPurchased(name: String)
	case fileNotFound(name: String)
}
extension CourseError: AbortError, DebuggableError {
	var status: HTTPResponseStatus {
		switch self {
			case .idNotFound, .nameNotFound:
				return .notFound
			case .courseNameExisted:
				return .conflict
			case .notForSale, .invalidAppStoreID:
				return .badRequest
			case .notPurchased:
				return .paymentRequired
			case .fileNotFound:
				return .notFound
		}
	}
	
	var reason: String {
		switch self {
			case .idNotFound(let id):
				return "未找到ID为\(id)的课程"
			case .nameNotFound(name: let name):
				return "未找到名称为\(name)的课程"
			case .courseNameExisted(let name):
				return "课程名称'\(name)'已被占用"
			case .notForSale:
				return "无效请求"
			case .invalidAppStoreID:
				return "无效App Store ID"
			case .notPurchased(let name):
				return "请先购买'\(name)'课程"
			case .fileNotFound(let name):
				return "\(name)文件不存在"
		}
	}
	
	var identifier: String {
		switch self {
			case .idNotFound:
				return "course_id_not_found"
			case .nameNotFound:
				return "course_name_not_found"
			case .courseNameExisted:
				return "course_name_existed"
			case .notForSale:
				return "course_not_for_sale"
			case .invalidAppStoreID:
				return "invalid_app_store_id"
			case .notPurchased:
				return "course_not_purchased"
			case .fileNotFound:
				return "file_not_found"
		}
	}
	
	
}
