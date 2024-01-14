import App
import Vapor

var env = try Environment.detect()
LoggingSystem.bootstrap(fragment: timestampDefaultLoggerFragment(), console: ConsoleKitTerminal.Terminal())
//try LoggingSystem.bootstrap(from: &env)
let app = Application(env)
defer { app.shutdown() }
try configure(app)
try app.run()
