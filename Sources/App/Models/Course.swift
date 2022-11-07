import Vapor
import Fluent

final class Course: Model, Content {
	
	static let schema = "courses"
	
	struct FieldKeys {
		static let name = FieldKey(stringLiteral: "name")
		static let description = FieldKey(stringLiteral: "description")
		static let price = FieldKey(stringLiteral: "price")
		static let published = FieldKey(stringLiteral: "published")
		static let freeChapters = FieldKey(stringLiteral: "free_chapters")
		static let language = FieldKey(stringLiteral: "language")
	}
	
	@ID var id: UUID?
	@Field(key: FieldKeys.name) var name: String
	@Field(key: FieldKeys.description) var description: String
	@Field(key: FieldKeys.price) var price: Double
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
        return chapters
    }
		
	init() {}
	
	init(id: Course.IDValue? = nil, name: String, description: String, price: Double, published: Bool, languageID: Language.IDValue, freeChapters: [Int]) {
		self.id = id
		self.name = name
		self.description = description
		self.price = price
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
		let price: Double
		let published: Bool
		let freeChapters: [Int]
		let languageID: Language.IDValue
		
		func validate(errors: inout [DebuggableError]) {
			if !nameLength.contains(name.count) {
				errors.append(GeneralInputError.nameLengthInvalid)
			}
			
			if price < 0 {
				errors.append(GeneralInputError.invalidPrice)
			}
		}
		
		func generateCourse() -> Course {
			Course(id: id, name: name, description: description, price: price, published: published, languageID: languageID, freeChapters: freeChapters)
		}
		
	}
	
	struct PublicInfo: Content {
        let id: Course.IDValue
		let name: String
		let description: String
		let price: Double
		let directoryURL: URL
		let imagePath:  String?
        let chapters: [Chapter]
		let freeChapters: [Int]
	}
	
    // PublicInfo should only be gettable when 'published' is true
	var publicList: PublicInfo? {
		get {
            guard published == true else { return nil }
            return PublicInfo(id: id!, name: name, description: description, price: price, directoryURL: directoryURL, imagePath: imagePath, chapters: [],/*courseCount: chaptersCount,*/ freeChapters: freeChapters)
		}
	}
	
	var publicInfo: PublicInfo? {
		get {
            guard published == true else { return nil }
            chapters.forEach { print($0.name) }
            return PublicInfo(id: id!, name: name, description: description, price: price, directoryURL: directoryURL, imagePath: imagePath, chapters: chapters,/*courseCount: chaptersCount,*/ freeChapters: freeChapters)
		}
	}
}
