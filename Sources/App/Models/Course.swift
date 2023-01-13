import Vapor
import Fluent

final class Course: Model, Content {
	
	static let schema = "courses"
	
	struct FieldKeys {
		static let name = FieldKey(stringLiteral: "name")
		static let description = FieldKey(stringLiteral: "description")
		static let published = FieldKey(stringLiteral: "published")
		static let freeChapters = FieldKey(stringLiteral: "free_chapters")
		static let language = FieldKey(stringLiteral: "language")
	}
	
	@ID var id: UUID?
	@Field(key: FieldKeys.name) var name: String
	@Field(key: FieldKeys.description) var description: String
	@Field(key: FieldKeys.published) var published: Bool
	@Field(key: FieldKeys.freeChapters) var freeChapters: [Int]
	@Parent(key: FieldKeys.language) var language: Language
	
	var directoryURL: URL {
		let url = language.directoryURL.appendingPathComponent(name, isDirectory: true)
		//        guard FileManager.default.fileExists(atPath: url.relativePath) && url.isDirectory else {
		//            fatalError("Unable to find a category for course: \(name)")
		//        }
		return url
	}
	
	var imagePath: String? {
		getImagePathInDirectory(url: directoryURL)
	}
	
	var chapters: [Chapter] {
		let urls = (try? FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: [], options: [.skipsHiddenFiles, /*.producesRelativePathURLs*/])) ?? []
		let chapters = urls.filter { $0.isDirectory && $0.pathExtension == "" }.map { Chapter(url: $0) }
		
		return chapters.sorted { $0.name < $1.name }
	}
	
	init() {}
	
	init(id: Course.IDValue? = nil, name: String, description: String, published: Bool, languageID: Language.IDValue, freeChapters: [Int]) {
		self.id = id
		self.name = name
		self.description = description
		self.published = published
		self.freeChapters = freeChapters
		self.$language.id = languageID
	}
}

extension Course {
	struct Input: Decodable {
		var id: Course.IDValue? = nil
		let name: String
		let description: String
		let published: Bool
		let freeChapters: [Int]
		let languageID: Language.IDValue
		
		#warning("make all validate functions query db simultaneously instead of sequentially, or test if current implementation is the way we want. If an ideal way is found, apply it to other validation methods")
		func validate(errors: inout [DebuggableError], req: Request) async throws {
			async let language = Language.find(languageID, on: req.db)
			async let foundID = Course.find(id, on: req.db)
			async let foundName = Course.query(on: req.db).filter(\.$name == name).first()

			if !nameLength.contains(name.count) {
				errors.append(GeneralInputError.nameLengthInvalid)
			}

			if try await language == nil {
				errors.append(LanguageError.idNotFound(id: languageID))
			}
			if id != nil, try await foundID == nil {
				errors.append(CourseError.idNotFound(id: id!))
			}
			if let foundName = try await foundName, foundName.id != id {
				errors.append(CourseError.courseNameExisted(name: name))
			}
		}
		
		func generateCourse() -> Course {
			Course(id: id, name: name, description: description, published: published, languageID: languageID, freeChapters: freeChapters)
		}
		
	}
	
	struct PublicInfo: Content {
		let id: Course.IDValue
		let name: String
		let description: String
		let directoryURL: URL
		let imagePath:  String?
		let chapters: [Chapter]
		let freeChapters: [Int]
	}
	
	// PublicInfo should only be gettable when 'published' is true
	var publicList: PublicInfo? {
		get {
			guard published == true else { return nil }
			return PublicInfo(id: id!, name: name, description: description, directoryURL: directoryURL, imagePath: imagePath, chapters: [],/*courseCount: chaptersCount,*/ freeChapters: freeChapters)
		}
	}
	
	var publicInfo: PublicInfo? {
		get {
			guard published == true else { return nil }
			return PublicInfo(id: id!, name: name, description: description, directoryURL: directoryURL, imagePath: imagePath, chapters: chapters,/*courseCount: chaptersCount,*/ freeChapters: freeChapters)
		}
	}
}
