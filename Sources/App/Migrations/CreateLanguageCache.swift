//
//  File.swift
//  
//
//  Created by Lei Gao on 2022/11/24.
//

import Fluent

struct CreateLanguageCache: Migration {
	func prepare(on database: FluentKit.Database) -> NIOCore.EventLoopFuture<Void> {
		database.schema(LanguageCache.schema)
			.id()
			.field(LanguageCache.FieldKeys.name, .string, .required)
			.field(LanguageCache.FieldKeys.description, .string)
			.field(LanguageCache.FieldKeys.price, .double, .required)
			.field(LanguageCache.FieldKeys.order, .uuid, .required, .references(Order.schema, Order.FieldKeys.id, onDelete: .cascade))
			.create()
	}
	
	func revert(on database: FluentKit.Database) -> NIOCore.EventLoopFuture<Void> {
		database.schema(LanguageCache.schema).delete()
	}
	
	
}


