//
//  File.swift
//  
//
//  Created by Lei Gao on 2022/10/13.
//

import Vapor
import Fluent
import PostgresKit

struct ImportTestingData: AsyncMigration {
    
    // MARK: - Courses
    
	var cxb = Course(name: "创新吧", description: "创新吧课程，更适合小学高年级孩子学习", published: true, price: 1200, annuallyIAPIdentifier: "chuangxinba_test")
    
	var bcw = Course(name: "编程屋", description: "1-3年级小朋友适合的Scratch课程，跟米乐熊一起体验编程的乐趣吧", published: true, price: 1000, annuallyIAPIdentifier: "bianchengwu_test")
	
	func prepare(on database: Database) async throws {
		try await [cxb, bcw].create(on: database)
	}
	
	func revert(on database: Database) async throws {
		try await Course.query(on: database).delete()
	}
}
