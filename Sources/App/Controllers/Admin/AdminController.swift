import Vapor
import Fluent


struct AdminController: RouteCollection {
    
    func boot(routes: RoutesBuilder) throws {
        let admin = routes.grouped("api", "admin")
        admin.post("register", use: register)
        admin.post("login", use: login)
        // Either group logout with AdminUser.sessionAuthenticator, or call req.session.unauthenticate(admin) manually in logout function, otherwise API won't work but web will...
        admin.post("logout", use: logout)
    }
    
    func register(req: Request) -> EventLoopFuture<Response> {
        var errors = [DebuggableError]()
        let input: AdminUser.RegisterInput
        do {
            input = try req.content.decode(AdminUser.RegisterInput.self)
        } catch {
            return req.eventLoop.future(error: error)
        }
        
        input.validate(errors: &errors)
        
        // email and username validation
        let queryEmail = AdminUser.query(on: req.db).filter(\.$email == input.email).first().map { foundEmail -> Void in
            if foundEmail != nil { errors.append(RegistrationError.emailAlreadyExists) }
        }
        let queryUserName = AdminUser.query(on: req.db).filter(\.$username == input.username).first().map { foundUserName -> Void in
            if foundUserName != nil { errors.append(RegistrationError.usernameAlreadyExists) }
        }
        
        return queryEmail.and(queryUserName).guard({ _ in
            errors.isEmpty
        }, else: errors.abort).flatMap { _ in
            return req.password.async.hash(input.password1).map { hash in
                AdminUser(email: input.email, username: input.username, password: hash)
            }.flatMap { admin in
                admin.save(on: req.db).transform(to: HTTPStatus.created).encodeResponse(for: req)
            }
        }
    }
    
    func login(req: Request) -> EventLoopFuture<Response> {
        let input: AdminUser.LoginInput
        do {
            input = try req.content.decode(AdminUser.LoginInput.self)
        } catch {
            return req.eventLoop.future(error: error)
        }
        
        return AdminUser.query(on: req.db)
        // Make sure there is an admin account with either the given username or email address
            .group(.or) { group in
                group.filter(\.$username == input.loginName).filter(\.$email == input.loginName)
            }.first().unwrap(or: AuthenticationError.userNotFound)
        // Make sure the given account is approved by the owner
            .guard({ admin in
                admin.isAccepted
            }, else: AuthenticationError.adminNotApproved)
                    // Make sure the password and loginName matches
                .guard({ admin in
                    try! req.password.verify(input.password, created: admin.password)
                }, else: AuthenticationError.invalidLoginNameOrPassword)
                    .flatMap { admin in
                        // Invalidate all sessions for the given admin acount first
                        admin.unauthenticateAllSessions(id: admin.id!, req: req, sessionDataKey: "_AdminUserSession").flatMap { _ in
                            req.auth.login(admin)
                            req.session.authenticate(admin)
                            admin.lastLoginTime = Date()
                            return admin.save(on: req.db).transform(to: admin).encodeResponse(for: req)
                        }
                    }
    }
    
    func logout(req: Request) -> HTTPStatus {
        req.auth.logout(AdminUser.self)
        req.session.unauthenticate(AdminUser.self)
        return HTTPStatus.ok
    }
    
    
}

