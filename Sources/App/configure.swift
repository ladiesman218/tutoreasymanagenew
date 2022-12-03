import Vapor
import Fluent
import FluentPostgresDriver


// configures your application
public func configure(_ app: Application) throws {
//	app.environment = .development
	
 	app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))	// To serve files from /Public folder
	
	let databaseName: String
	let databasePort: Int
	
	// 1
	if (app.environment == .testing) {
	  databaseName = "vapor-test"
	  databasePort = 5433
	} else {
	  databaseName = "tutoreasymanage"
	  databasePort = 5432
	}

	if var config = Environment.get("DATABASE_URL").flatMap(URL.init).flatMap(PostgresConfiguration.init) {
		config.tlsConfiguration = .makeClientConfiguration()
		config.tlsConfiguration?.certificateVerification = .none
		app.databases.use(.postgres(configuration: config), as: .psql)
	} else {
		app.databases.use(.postgres(hostname: Environment.get("DATABASE_HOST") ?? "localhost", port: databasePort, username: Environment.get("DATABASE_USERNAME") ?? "vapor_username", password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password", database: Environment.get("DATABASE_NAME") ?? databaseName), as: .psql)
	}
	
	
	
//	if var config = Environment.get("DATABASE_URL").flatMap(URL.init).flatMap(PostgresConfiguration.init) {
//	  config.tlsConfiguration = .makeClientConfiguration()
//	  config.tlsConfiguration?.certificateVerification = .none
//	  app.databases.use(.postgres(configuration: config), as: .psql)
//	} else {
//	  app.databases.use(.postgres(
//		hostname: Environment.get("DATABASE_HOST") ?? "localhost",
//		port: 5432,
//		username: Environment.get("DATABASE_USER") ?? "vapor_username",
//		password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
//		database: Environment.get("DATABASE_NAME") ?? "tutoreasy",
//		connectionPoolTimeout: .minutes(3)
//	  ), as: .psql)
//	}
	
	app.migrations.add(CreateAdmin())
	app.migrations.add(CreateOwner())
	app.migrations.add(CreateLanguage())
	app.migrations.add(CreateCourse())
	app.migrations.add(CreateUser())
	app.migrations.add(CreateToken())
    if app.environment == .development {
        app.migrations.add(ImportTestingData())
    }
	app.migrations.add(CreateOrder())
	app.migrations.add(CreateLanguageCache())
	
	// Config session, .sessions.use(.fluent) has to be called before .middleware.use() otherwise won't work...
	// Currently, session is used for Admin. Normal users will use tokens only.
	app.migrations.add(SessionRecord.migration)
	app.sessions.use(.fluent)
	app.middleware.use(app.sessions.middleware)
	
	// This will automatically run migrations everytime the app is restarted. Notice this has to be called after session migration.
	try app.autoMigrate().wait()
	
    // register routes
    try routes(app)
}
