import Vapor

enum LanguageError: Error {
	case idNotFound(id: Language.IDValue)
	case languageNameExisted(name: String)
	case invalidAppStoreID
	case notForSale
}

extension LanguageError: AbortError, DebuggableError {
	
	var status: HTTPResponseStatus {
		switch self {
			case .idNotFound:
				return .notFound
			case .languageNameExisted:
				return .conflict
			case .invalidAppStoreID, .notForSale:
				return .badRequest
		}
	}
	
	var reason: String {
		switch self {
			case .idNotFound(let id):
				return "未找到ID为\(id)的语言"
			case .languageNameExisted(let name):
				return "语言名称\(name)已被占用"
			case .invalidAppStoreID:
				return "无效app store id"
			case .notForSale:
				return "无法购买该课程"
		}
	}
	
	var identifier: String {
		switch self {
			case .idNotFound:
				return "language_id_not_found"
			case .languageNameExisted:
				return "language_name_existed"
			case .invalidAppStoreID:
				return "invalid_app_store_id"
			case.notForSale:
				return "language_not_for_sale"
		}
	}
}
