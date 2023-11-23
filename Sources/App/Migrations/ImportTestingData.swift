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
        
	let bcw = Course(name: "编程屋", description: "1-3年级小朋友适合的Scratch课程，跟米乐熊一起体验编程的乐趣吧", published: true, price: 1000, annuallyIAPIdentifier: "bianchengwu_test")
	let lg = Course(name: "9686乐高小颗粒课程", description: "", published: true, price: 1234, annuallyIAPIdentifier: "9686")
	let yy = Course(name: "幼儿园英语课程", description: "", published: true, price: 1234, annuallyIAPIdentifier: "english")
	let scratch = Course(name: "scratch编程课", description: "", published: true, price: 1234, annuallyIAPIdentifier: "scratch")
	let wedo = Course(name: "Wedo2.0机器人编程课程", description: "", published: true, price: 1234, annuallyIAPIdentifier: "wedo")
	let meishu = Course(name: "美术课", description: "", published: true, price: 1234, annuallyIAPIdentifier: "art")
	
	func prepare(on database: Database) async throws {
		try await [bcw, lg, yy, scratch, wedo, meishu].create(on: database)
	}
	
	func revert(on database: Database) async throws {
		try await Course.query(on: database).delete()
	}
}
