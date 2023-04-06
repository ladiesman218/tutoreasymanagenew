import Vapor

enum GeneralInputError: Error {
	case invalidID
	case invalidSlug
	case nameLengthInvalid
	case invalidPrice
	case invalidDataStructure
	case invalidURL
}

extension GeneralInputError: AbortError, DebuggableError {
	
	var reason: String {
		switch self {
			case .invalidID:
				return "无效ID类型，请参考文档"
			case .invalidSlug:
				return "Slug中只可以使用小写英文字母(a - z), 数字(0-9)以及横线(-)"
			case .nameLengthInvalid:
				return "名字长度应介于\(nameLength.lowerBound.description) 到 \((nameLength.upperBound - 1).description)个字符之间"
			case .invalidPrice:
				return "价格最低不应小于0"
			case .invalidDataStructure:
				return "数据无效"
			case .invalidURL:
				return "请求资源地址无效"
		}
	}
	
	var status: HTTPResponseStatus {
		return .badRequest
	}
	
	var identifier: String {
		switch self {
			case .invalidID:
				return "invalid_id"
			case .invalidSlug:
				return "invalid_slug"
			case .nameLengthInvalid:
				return "name_length_invalid"
			case .invalidPrice:
				return "invalid_price"
			case .invalidDataStructure:
				return "invalid_data_structure"
			case .invalidURL:
				return "invalid_url"
		}
	}
}

