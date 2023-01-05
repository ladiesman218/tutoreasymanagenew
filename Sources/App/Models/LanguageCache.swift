//
//  File.swift
//  
//
//  Created by Lei Gao on 2023/1/3.
//

import Foundation
import Vapor
import FluentKit


struct LanguageCache: Codable {
	let languageID: Language.IDValue
	let name: String
	let description: String
	let price: Double
	let iapIdentifier: String?
	
	init(languageID: Language.IDValue, name: String, description: String, price: Double, iapIdentifier: String?) {
		self.languageID = languageID
		self.name = name
		self.description = description
		self.price = price
		self.iapIdentifier = iapIdentifier
	}
	init(from language: Language) throws {
		let id = try language.requireID()
		guard language.published else {
			throw LanguageError.notForSale
		}
		self.languageID = id
		self.name = language.name
		self.description = language.description
		self.price = language.price
		self.iapIdentifier = language.annuallyIAPIdentifier
	}
}
