import Fluent
import FluentPostgresDriver

struct CreateUser: AsyncMigration {
	func prepare(on database: Database) async throws {
		
		let defaultUnverified = SQLColumnConstraintAlgorithm.default(false)
		
		let contactMethod = try await database.enum(User.FieldKeys.contactMethod.description)
			.case(User.ContactMethod.email.rawValue)
			.case(User.ContactMethod.phone.rawValue)
			.create()
		
		try await database.schema(User.schema).id()
			.field(User.FieldKeys.primaryContact, contactMethod, .required)
			.field(User.FieldKeys.secondaryContact, contactMethod)
			.field(User.FieldKeys.username, .string, .required).unique(on: User.FieldKeys.username)
			.field(User.FieldKeys.firstName, .string)
			.field(User.FieldKeys.lastName, .string)
			.field(User.FieldKeys.email, .string).unique(on: User.FieldKeys.email)
			.field(User.FieldKeys.phone, .string).unique(on: User.FieldKeys.phone)
			.field(User.FieldKeys.password, .string, .required)
			.field(User.FieldKeys.profilePic, .string)
			.field(User.FieldKeys.registerTime, .datetime)
			.field(User.FieldKeys.lastLoginTime, .datetime)
		// Per documentation, dictionary's key should always be string `https://docs.vapor.codes/zh/fluent/schema/#dictionary`
			.field(User.FieldKeys.verificationCode, .dictionary)
			.field(User.FieldKeys.verified, .bool, .required, .sql(defaultUnverified))
			.create()
		
		// Primary and secondary contact methods can't be set to the same value
		let contactsNotSame = SQLRaw("\(User.FieldKeys.primaryContact) != \(User.FieldKeys.secondaryContact)")
		let contactsNotSameConstraint = DatabaseSchema.Constraint.sql(SQLTableConstraintAlgorithm.check(contactsNotSame))
		
		// Neither primary or secondary contact methods is not set to email, if either one is, email field can't be nil
		let emailNotNull = SQLRaw("(\(User.FieldKeys.primaryContact) != '\(User.ContactMethod.email.rawValue)' AND \(User.FieldKeys.secondaryContact) != '\(User.ContactMethod.email.rawValue)') OR \(User.FieldKeys.email) IS NOT NULL")
		let phoneNotNull = SQLRaw("(\(User.FieldKeys.primaryContact) != '\(User.ContactMethod.phone.rawValue)' AND \(User.FieldKeys.secondaryContact) != '\(User.ContactMethod.phone.rawValue)') OR \(User.FieldKeys.phone) IS NOT NULL")
		
		let emailNullConstraint = DatabaseSchema.Constraint.sql(SQLTableConstraintAlgorithm.check(emailNotNull))
		let phoneNullConstraint = DatabaseSchema.Constraint.sql(SQLTableConstraintAlgorithm.check(phoneNotNull))
		
		let emailValid = SQLRaw("email ~* '\(emailRegex)'")
		let phoneValid = SQLRaw("phone ~* '\(cnPhoneRegex)'")
		let emailValidConstraint = DatabaseSchema.Constraint.sql(SQLTableConstraintAlgorithm.check(emailValid))
		let phoneValidConstraint = DatabaseSchema.Constraint.sql(SQLTableConstraintAlgorithm.check(phoneValid))

		try await database.schema(User.schema).constraint(contactsNotSameConstraint).constraint(emailNullConstraint).constraint(phoneNullConstraint).constraint(emailValidConstraint).constraint(phoneValidConstraint).update()
	}
	
	func revert(on database: Database) async throws {
		try await database.schema(User.schema).delete()
		try await database.schema(User.FieldKeys.contactMethod.description).delete()
	}
}

