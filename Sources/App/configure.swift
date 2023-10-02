import Vapor
import Fluent
import FluentPostgresDriver
import SendGrid
import QueuesFluentDriver

// configures application
public func configure(_ app: Application) throws {
	// production env should init db instance from enviroment(set in Dockerfile or .env file). For convenience, other envs should use the same db instance so we don't need too many db container running for different envs. This db instance can use the hard coded db parameters.
	if app.environment == .production {
		let config = SQLPostgresConfiguration(hostname: Environment.get("DATABASE_HOST")!, port: 5432, username: Environment.get("DATABASE_USERNAME")!, password: Environment.get("DATABASE_PASSWORD")!, database: Environment.get("DATABASE_NAME")!, tls: .disable)
		app.databases.use(.postgres(configuration: config), as: .psql)
	} else {
		let config = SQLPostgresConfiguration(hostname: "localhost", port: 5433, username: "tutor_test", password: "tutor_test", database: "tutor_test", tls: .disable)
		let postgres = DatabaseConfigurationFactory.postgres(configuration: config)
		app.databases.use(postgres, as: .psql)
	}
	
	app.migrations.add(CreateAdmin())
	app.migrations.add(CreateOwner())
	app.migrations.add(CreateCourse())
	app.migrations.add(CreateUser())
	app.migrations.add(CreateToken())
    if app.environment != .production {
        app.migrations.add(ImportTestingData())
    }
	app.migrations.add(CreateOrder())
	// Currently, session is used for Admin. Normal users will use tokens only.
	app.migrations.add(SessionRecord.migration)
	// The QueuesFluentDriver package needs a table, named _jobs_meta by default, to store the Vapor Queues jobs. Make sure to add this to your migrations by calling `app.migrations.add(JobMetadataMigrate()), or change the name by pass in the schema parameter and give it a customized name.
	app.migrations.add(JobMetadataMigrate(schema: "_automated_jobs"))
	// Config session, .sessions.use(.fluent) has to be called before .middleware.use() otherwise won't work
	// This will automatically run migrations everytime the app is restarted.
	try app.autoMigrate().wait()
	
	app.sessions.use(.fluent)
	app.middleware.use(app.sessions.middleware)
	app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))	// To serve files from /Public folder
	
	// By default, the Vapor Queues package creates 2 workers per CPU core, and each worker would poll the database for jobs to be run every second. On a 4 cores system, this means 8 workers querying the database every second by default. We can change the jobs polling interval by setting refreshInterval. Say if we set it to 1 minute and the server app is started at mm:30, it will check for pending jobs in database at every minute's 30 seconds, so if a job is scheduled to be runned at 1:23:45AM, its actual pulling time will be 1:24:30AM.
	app.queues.configuration.refreshInterval = .minutes(1)
	app.queues.use(.fluent())
	app.queues.add(EmailJob())
	app.queues.add(OrderJobs())
	
	// Currently this Cleanup has no actual effect coz we need another running worker, check out documentation at https://docs.vapor.codes/advanced/queues/#scheduling-jobs
	app.queues.schedule(Cleanup()).monthly().on(27).at(13, 27)
	try app.queues.startInProcessJobs(on: .default)
	
    // register routes
    try routes(app)
	
//	app.sendgrid.initialize()
}
