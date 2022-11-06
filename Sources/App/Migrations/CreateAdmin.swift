import Fluent
import FluentPostgresDriver


struct CreateAdmin: Migration {
  
  func prepare(on database: Database) -> EventLoopFuture<Void> {
	
	let defaultNotAccept = SQLColumnConstraintAlgorithm.default(false)
	let defaultType = SQLColumnConstraintAlgorithm.default(AdminUser.AdminType.employee.rawValue)
	
	return database.enum(AdminUser.FieldKeys.adminType.description)
	  .case(AdminUser.AdminType.employee.rawValue)
	  .case(AdminUser.AdminType.shopOwner.rawValue)
	  
	  .create().flatMap { adminType in
		return database.schema(AdminUser.schema)
		  .id()
		  .field(AdminUser.FieldKeys.email, .string, .required).unique(on: AdminUser.FieldKeys.email)
		  .field(AdminUser.FieldKeys.username, .string, .required).unique(on: AdminUser.FieldKeys.username)
		  .field(AdminUser.FieldKeys.password, .string, .required)
		  .field(AdminUser.FieldKeys.isAccepted, .bool, .required, .sql(defaultNotAccept))
		  .field(AdminUser.FieldKeys.adminType, adminType, .required, .sql(defaultType))
		  .field(AdminUser.FieldKeys.registerTime, .datetime)
		  .field(AdminUser.FieldKeys.lastLoginTime, .datetime)
		  .create()
	  }
  }
  
  func revert(on database: Database) -> EventLoopFuture<Void> {
	return database.schema(AdminUser.schema).delete().flatMap {
	  database.schema(AdminUser.FieldKeys.adminType.description).delete()
	}
  }
}

