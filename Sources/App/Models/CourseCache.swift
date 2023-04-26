//
//  File.swift
//  
//
//  Created by Lei Gao on 2023/1/3.
//

import Foundation
import Vapor
import FluentKit


struct CourseCache: Codable, Hashable {
	let id: UUID
	let name: String
	let description: String
	let price: Float
	let iapIdentifier: String?
	
	init(id: Course.IDValue, name: String, description: String, price: Float, iapIdentifier: String?) {
		self.id = id
		self.name = name
		self.description = description
		self.price = price
		self.iapIdentifier = iapIdentifier
	}
	
	init(from course: Course) throws {
		self.id = try course.requireID()
		self.name = course.name
		self.description = course.description
		self.price = course.price
		self.iapIdentifier = course.annuallyIAPIdentifier
	}
}
