import Vapor
import Fluent

final class Course: Model, Content {
	
	static let schema = "courses"
	
	struct FieldKeys {
		static let name = FieldKey(stringLiteral: "name")
		static let description = FieldKey(stringLiteral: "description")
		static let published = FieldKey(stringLiteral: "published")
		static let price = FieldKey(stringLiteral: "price")
		static let annuallyIAPIdentifier = FieldKey(stringLiteral: "annually_iap_identifier")
	}
	
	@ID var id: UUID?
	@Field(key: FieldKeys.name) var name: String
	@Field(key: FieldKeys.description) var description: String
	@Field(key: FieldKeys.published) var published: Bool
	@Field(key: FieldKeys.price) var price: Float
	@Field(key: FieldKeys.annuallyIAPIdentifier) var annuallyIAPIdentifier: String
	
	var directoryURL: URL {
		let url = courseRoot.appendingPathComponent(name, isDirectory: true).standardizedFileURL
		return url
	}
	
	var imageURL: URL? {
		getImageURLInDirectory(url: directoryURL)
	}
	
	var stages: [Stage] {
		let stageURLs = directoryURL.subFoldersURLs
		return stageURLs.sorted { $0.path < $1.path }.map { return Stage(directoryURL: $0) }
	}
	
	init() {}
	
	init(id: Course.IDValue? = nil, name: String, description: String, published: Bool, price: Float, annuallyIAPIdentifier: String) {
		self.id = id
		self.name = name
		self.description = description
		self.published = published
		self.price = price
		self.annuallyIAPIdentifier = annuallyIAPIdentifier
	}
}

extension Course {
	struct Input: Decodable {
		var id: Course.IDValue? = nil
		let name: String
		let description: String
		let published: Bool
		let price: Float
		let annuallyIAPIdentifier: String
		
		func validate(errors: inout [DebuggableError], req: Request) async throws {
			async let foundID = Course.find(id, on: req.db)
			async let foundName = Course.query(on: req.db).filter(\.$name == name).first()
			async let foundIAPIdentifier = Course.query(on: req.db).filter(\.$annuallyIAPIdentifier == annuallyIAPIdentifier).first()
			
			if !nameLength.contains(name.count) {
				errors.append(GeneralInputError.nameLengthInvalid)
			}
			
			if price < 0 {
				errors.append(GeneralInputError.invalidPrice)
			}
			
			if id != nil, try await foundID == nil {
				errors.append(CourseError.idNotFound(id: id!))
			}
			if let foundName = try await foundName, foundName.id != id {
				errors.append(CourseError.courseNameExisted(name: name))
			}
			if let foundIdentifier = try await foundIAPIdentifier {
				if foundIdentifier.id != id {
					errors.append(CourseError.invalidAppStoreID)
				}
			}
		}
		
		func generateCourse() -> Course {
			Course(id: id, name: name, description: description, published: published, price: price, annuallyIAPIdentifier: annuallyIAPIdentifier)
		}
		
	}
	
	struct PublicInfo: Content {
		let id: Course.IDValue
		let name: String
		let description: String
		let price: Float
		let stages: [Stage]
		let imageURL: URL?
		let annuallyIAPIdentifier: String
	}
	
	// PublicInfo should only be gettable when 'published' is true
	var publicList: PublicInfo? {
		get {
			guard published == true else { return nil }
			return PublicInfo(id: id!, name: name, description: description, /*directoryURL: directoryURL,*/ price: price, stages: [], imageURL: imageURL, annuallyIAPIdentifier: annuallyIAPIdentifier)
		}
	}
	
	var publicInfo: PublicInfo? {
		get {
			guard published == true else { return nil }
			return PublicInfo(id: id!, name: name, description: description, /*directoryURL: directoryURL,*/ price: price, stages: stages, imageURL: imageURL, annuallyIAPIdentifier: annuallyIAPIdentifier)
		}
	}
}
