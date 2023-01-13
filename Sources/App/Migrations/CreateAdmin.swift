import Fluent
import FluentPostgresDriver


struct CreateAdmin: AsyncMigration {
	func prepare(on database: FluentKit.Database) async throws {
		let defaultNotAccept = SQLColumnConstraintAlgorithm.default(false)
		let defaultType = SQLColumnConstraintAlgorithm.default(AdminUser.AdminType.employee.rawValue)
		
		let adminType = try await database.enum(AdminUser.FieldKeys.adminType.description)
			.case(AdminUser.AdminType.employee.rawValue)
			.case(AdminUser.AdminType.shopOwner.rawValue)
			.create()
		
		try await database.schema(AdminUser.schema).id()
			.field(AdminUser.FieldKeys.email, .string, .required).unique(on: AdminUser.FieldKeys.email)
			.field(AdminUser.FieldKeys.username, .string, .required).unique(on: AdminUser.FieldKeys.username)
			.field(AdminUser.FieldKeys.password, .string, .required)
			.field(AdminUser.FieldKeys.isAccepted, .bool, .required, .sql(defaultNotAccept))
			.field(AdminUser.FieldKeys.adminType, adminType, .required, .sql(defaultType))
			.field(AdminUser.FieldKeys.registerTime, .datetime)
			.field(AdminUser.FieldKeys.lastLoginTime, .datetime)
			.create()
	}
	
	func revert(on database: FluentKit.Database) async throws {
		try await database.schema(AdminUser.schema).delete()
		try await database.schema(AdminUser.FieldKeys.adminType.description).delete()
	}
}

