import Vapor
import Fluent

final class Language: Model, Content {
	
	static let schema: String = "languages"
	
	struct FieldKeys {
		static let id = FieldKey(stringLiteral: "id")	// This is created for course migration referrence
		static let name = FieldKey(stringLiteral: "name")
		static let description = FieldKey(stringLiteral: "description")
		static let published = FieldKey(stringLiteral: "published")
		static let price = FieldKey(stringLiteral: "price")
		static let iapIdentifier1 = FieldKey(stringLiteral: "in_app_purchase_identifier_1")
	}
	
	@ID var id: UUID?
	@Field(key: FieldKeys.name) var name: String
	@Field(key: FieldKeys.description) var description: String
	@Field(key: FieldKeys.published) var published: Bool
	@Field(key: FieldKeys.price) var price: Double
	@Children(for: \.$language) var courses: [Course]
	@Field(key: FieldKeys.iapIdentifier1) var annuallyIAPIdentifier: String
	
	// According to https://docs.swift.org/swift-book/LanguageGuide/Properties.html, If a property marked with the lazy modifier is accessed by multiple threads simultaneously and the property hasn’t yet been initialized, there’s no guarantee that the property will be initialized only once.
	// When lazy properties get initialized, their values will never change. In this case even when we change the name of lanuage, its path and imageURL will stay unchanged unless the server is rebooted. So although using computed properties here seems a waste of resource since values are computed everytime they are accessed and never get stored, we will still be using them here.
    // For current implementations, path and imageURL aren't really necessary, we can just generate urls on client side based on how we are organizing file structures. Keeping those 2 variables are for futureproof, in case we will change file structures later.
	var directoryURL: URL {
        let url = courseRoot.appendingPathComponent(name, isDirectory: true)
//        guard FileManager.default.fileExists(atPath: url.relativePath) && url.isDirectory else {
//            fatalError("Unable to find a category for language: \(name)")
//        }
        return url
	}

	var imagePath: String? {
		return getImagePathInDirectory(url: directoryURL)
	}
		
	init() {}
	
	init(id: Language.IDValue? = nil, name: String, description: String, published: Bool, price: Double, annuallyIAPIdentifier: String) {
		self.id = id
		self.name = name
		self.description = description
		self.published = published
		self.price = price
		self.annuallyIAPIdentifier = annuallyIAPIdentifier
	}
}


extension Language {
	
	struct Input: Decodable {
		
		var id: Language.IDValue?
		let name: String
		let description: String
		let published: Bool
		let price: Double
		let annuallyIAPIdentifier: String
		
		func validate(errors: inout [DebuggableError], req: Request) async throws {
			async let foundID = Language.find(id, on: req.db)
			async let foundName = Language.query(on: req.db).filter(\.$name == name).first()
			async let foundIAPIdentifier = Language.query(on: req.db).filter(\.$annuallyIAPIdentifier == annuallyIAPIdentifier).first()

			if !nameLength.contains(name.count) {
				errors.append(GeneralInputError.nameLengthInvalid)
			}
			if price < 0 {
				errors.append(GeneralInputError.invalidPrice)
			}
			if published && annuallyIAPIdentifier.isEmpty {
				errors.append(LanguageError.invalidAppStoreID)
			}
			
			if id != nil, try await foundID == nil {
				errors.append(LanguageError.idNotFound(id: id!))
			}
			if let foundName = try await foundName {
				if foundName.id != id {
					errors.append(LanguageError.languageNameExisted(name: name))
				}
			}
			if let foundIdentifier = try await foundIAPIdentifier {
				if foundIdentifier.id != id {
					errors.append(LanguageError.invalidAppStoreID)
				}
			}
		}
		
		func generateLanguage() -> Language {
			return Language(id: id, name: name, description: description, published: published, price: price, annuallyIAPIdentifier: annuallyIAPIdentifier)
		}
	}
	
	struct PublicInfo: Content {
        let id: Language.IDValue
		let name: String
		let description: String
		let price: Double
        let courses: [Course.PublicInfo]
		let directoryURL: URL
		let imagePath: String?
		let annuallyIAPIdentifer: String
	}
	
    // PublicInfo should only be gettable when 'published' is true
	var publicList: PublicInfo? {
		get {
            guard published == true else { return nil }
			return PublicInfo(id: id!, name: name, description: description, price: price, courses: [], directoryURL: directoryURL, imagePath: imagePath, annuallyIAPIdentifer: annuallyIAPIdentifier)
		}
	}

	var publicItem: PublicInfo? {
		get {
            guard published == true else { return nil }
			return PublicInfo(id: id!, name: name, description: description, price: price, courses: courses.compactMap { $0.publicInfo }, directoryURL: directoryURL, imagePath: imagePath, annuallyIAPIdentifer: annuallyIAPIdentifier)
		}
	}
    
}
