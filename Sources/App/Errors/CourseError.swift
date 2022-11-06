import Vapor

enum CourseError: Error {
    case idNotFound(id: Language.IDValue)
    case courseNameExisted(name: String)
}
extension CourseError: AbortError, DebuggableError {
	var status: HTTPResponseStatus {
		switch self {
		case .idNotFound:
			return .notFound
		case .courseNameExisted:
			return .conflict
		}
	}
	
	var reason: String {
		switch self {
		case .idNotFound(let id):
			return "未找到ID为\(id)的课程"
		case .courseNameExisted(let name):
			return "课程名称'\(name)'已被占用"
		}
	}
	
	var identifier: String {
		switch self {
		case .idNotFound:
			return "course_id_not_found"
		case .courseNameExisted:
			return "course_name_existed"
		}
	}
	

}
