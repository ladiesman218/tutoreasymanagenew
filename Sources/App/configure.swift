import Vapor
import Fluent
import FluentPostgresDriver
import QueuesFluentDriver
import Logging

// configures application
public func configure(_ app: Application) throws {
	app.logger = Logger(label: "TEServer")
	app.logger.logLevel = .info
	app.logger.log(level: .info, "Starting server for", metadata: ["environment": "\(app.environment.name)"])
	
	// When deploying with docker compose, app service depends on database service, it's done by setting app's environment variable DATABASE_HOST to database service's name. So here we need to get database host from environment variable. For local testing, DATABASE_HOST won't be existed so "localhost" will be used.
	let dbHost = Environment.get("DATABASE_HOST") ?? "localhost"
	let dbName = Environment.get("DATABASE_NAME")!
	let dbPort = Int(Environment.get("DATABASE_PORT")!)!
	let dbUser = Environment.get("DATABASE_USERNAME")!
	let dbPass = Environment.get("DATABASE_PASSWORD")!
	let _ = Environment.get("BREVOAPI")!
	
	// Database will be on the same server as app itself, so postgres should disable tls.
	// Server's tls is handled by nginx, so in project's conf we can disable tls
	let config = SQLPostgresConfiguration(hostname: dbHost, port: dbPort, username: dbUser, password: dbPass, database: dbName, tls: .disable)
	let postgres = DatabaseConfigurationFactory.postgres(configuration: config, connectionPoolTimeout: .seconds(30))
	app.databases.use(postgres, as: .psql)
	
	app.migrations.add(CreateAdmin())
	app.migrations.add(CreateOwner())
	app.migrations.add(CreateCourse())
	app.migrations.add(CreateUser())
	app.migrations.add(CreateToken())
	app.migrations.add(CreateAPNSToken())
	
	if app.environment != .production {
		app.migrations.add(ImportTestingData())
	}
	app.migrations.add(CreateOrder())
	// Currently, session is used for Admin. Normal users will use tokens only.
	app.migrations.add(SessionRecord.migration)
	// The QueuesFluentDriver package needs a table, named _jobs_meta by default, to store the Vapor Queues jobs. Make sure to add this to your migrations by calling `app.migrations.add(JobMetadataMigrate()), or change the name by pass in the schema parameter and give it a customized name.
	app.migrations.add(JobMetadataMigrate(schema: "_automated_jobs"))
	// This will automatically run migrations everytime the app is restarted.
	try app.autoMigrate().wait()
	
	// Config session, .sessions.use(.fluent) has to be called before .middleware.use() otherwise won't work
	app.sessions.use(.fluent)
	app.middleware.use(app.sessions.middleware)
	app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))	// To serve files from /Public folder
	
	// By default, the Vapor Queues package creates 2 workers per CPU core, and each worker would poll the database for jobs to be run every second. On a 4 cores system, this means 8 workers querying the database every second by default. We can change the jobs polling interval by setting refreshInterval. Say if we set it to 1 minute and the server app is started at mm:30, it will check for pending jobs in database at every minute's 30 seconds, so if a job is scheduled to be runned at 1:23:45AM, its actual pulling time will be 1:24:30AM.
	app.queues.configuration.refreshInterval = .minutes(1)
	app.queues.use(.fluent())
	app.queues.add(OrderJobs())
	app.queues.add(UserJobs())
	
	// Currently this Cleanup has no actual effect coz we need another running worker, check out documentation at https://docs.vapor.codes/advanced/queues/#scheduling-jobs
	app.queues.schedule(PurgeOrder()).monthly().on(22).at(23, 24)
	try app.queues.startInProcessJobs(on: .default)
	
	// register routes
	try routes(app)
}
