//
//  File.swift
//  
//
//  Created by Lei Gao on 2022/10/13.
//

import Vapor
import Fluent
import PostgresKit

struct ImportTestingData: Migration {
    
    // MARK: - languages
	let scratch = Language(name: "Scratch", description: "图形化编程工具，通过点击并拖拽的方式，完成编程，可以使儿童或者成人编程初学者学习编程基础概念等", published: true, price: 1200, annuallyIAPIdentifier: "scratch_test")
	let wedo = Language(name: "Wedo", description: "通过乐高电动模型和简单的程序编写，鼓励和激发小学生学习科学和工程相关课程的兴趣。 VeDo 2.0强调孩子通过动手体验来树立信心，敢于发现、提出和思考问题，运用工具寻 找答案，并解决实际生活中的问题学生可以在提出问题和解决问题的过程中学到知识。", published: true, price: 1000, annuallyIAPIdentifier: "wedo_test")
	let python = Language(name: "Python", description: "Python由荷兰数学和计算机科学研究学会的吉多·范罗苏姆于1990年代初设计，作为一门叫做ABC语言的替代品。Python提供了高效的高级数据结构，还能简单有效地面向对象编程。Python语法和动态类型，以及解释型语言的本质，使它成为多数平台上写脚本和快速开发应用", published: true, price: 1150.2, annuallyIAPIdentifier: "python_test")
    
    // MARK: - Courses
    
    var cxb = Course(name: "创新吧", description: "创新吧课程，更适合小学高年级孩子学习", published: true, languageID: UUID(), freeChapters: [1, 2, 3])
    
    var bcw = Course(name: "编程屋", description: "1-3年级小朋友适合的Scratch课程，跟米乐熊一起体验编程的乐趣吧", published: true, languageID: UUID(), freeChapters: [1, 3, 5])
    
    func prepare(on database: FluentKit.Database) -> NIOCore.EventLoopFuture<Void> {
        return [scratch, wedo, python].create(on: database).transform(to: [scratch, wedo, python]).flatMap { languages in
            let ids = languages.map { try! $0.requireID() }
            cxb.$language.id = ids.first!
            bcw.$language.id = ids.first!
            return [cxb, bcw].create(on: database)
        }
    }
    
    func revert(on database: FluentKit.Database) -> NIOCore.EventLoopFuture<Void> {
        Course.query(on: database).delete().flatMap {
            Language.query(on: database).delete()
        }
    }
    
    
}
