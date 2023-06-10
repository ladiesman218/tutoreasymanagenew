import Vapor
import Fluent
import FluentPostgresDriver


// configures your application
public func configure(_ app: Application) throws {
//	app.environment = .development
	
 	app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))	// To serve files from /Public folder
	
	// production env should init db instance from enviroment(set in Dockerfile). For convenience, other envs should use the same db instance so we don't need too many db container running for different envs. This db instance should can use the hard coded db parameters.
	if app.environment == .production {
		// If enviroment has an vairable called DATABASE_URL, then it's for production, force init a PostgresConfiguration from that variable's value, or crash the app.
		print("PRODUCTION enviroment")
		var config = Environment.get("DATABASE_URL").flatMap(URL.init)!.flatMap(PostgresConfiguration.init)!
		config.tlsConfiguration = .makeClientConfiguration()
		config.tlsConfiguration?.certificateVerification = .none
		app.databases.use(.postgres(configuration: config), as: .psql)
	} else {
		// Before start the app, run `docker run --name tutor-local-test -p 5433:5432 -e POSTGRES_PASSWORD=tutor_test -e POSTGRES_USER=tutor_test -e POSTGRES_DB=tutor_test -d postgres:12-alpine` in terminal to start a container for the testing db.
		let postgres = DatabaseConfigurationFactory.postgres(hostname: "localhost", port: 5433, username: "tutor_test", password: "tutor_test", database: "tutor_test")
		app.databases.use(postgres, as: .psql)
	}
	
//	if var config = Environment.get("DATABASE_URL").flatMap(URL.init).flatMap(PostgresConfiguration.init) {
//		config.tlsConfiguration = .makeClientConfiguration()
//		config.tlsConfiguration?.certificateVerification = .none
//		app.databases.use(.postgres(configuration: config), as: .psql)
//	} else {
//		let postgres = DatabaseConfigurationFactory.postgres(hostname: Environment.get("DATABASE_HOST") ?? "localhost", port: databasePort, username: Environment.get("DATABASE_USERNAME") ?? "vapor_username", password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password", database: Environment.get("DATABASE_NAME") ?? databaseName)
//		app.databases.use(postgres, as: .psql)
//		print(app.databases.configuration(for: .psql).debugDescription)
//	}
	
	app.migrations.add(CreateAdmin())
	app.migrations.add(CreateOwner())
	app.migrations.add(CreateCourse())
	app.migrations.add(CreateUser())
	app.migrations.add(CreateToken())
    if app.environment != .production {
        app.migrations.add(ImportTestingData())
    }
	app.migrations.add(CreateOrder())
	
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
