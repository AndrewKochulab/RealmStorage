//
//  SchemaMigrator.swift
//  RealmStorage
//

import Foundation
import RealmSwift

/// Builds a Realm migration block from a set of versioned steps.
///
/// Realm hands you one block and the old schema version; expressing "do X going from 1
/// to 2, then Y going from 2 to 3" by hand means a chain of `if oldVersion < n` checks
/// that is easy to get wrong. This runs the steps in order and skips those already applied.
///
/// ```swift
/// let migrator = SchemaMigrator {
///     SchemaMigrationStep(toVersion: 2) { migration in
///         migration.renameProperty(onType: "User", from: "identifier", to: "id")
///     }
/// }
///
/// var configuration = StorageConfiguration(schemaVersion: 2)
/// configuration.migrate = migrator.migrationBlock
/// ```
public struct SchemaMigrator: Sendable {

    private let steps: [SchemaMigrationStep]

    public init(steps: [SchemaMigrationStep]) {
        self.steps = steps.sorted { $0.toVersion < $1.toVersion }
    }

    public init(@SchemaMigrationBuilder _ build: () -> [SchemaMigrationStep]) {
        self.init(steps: build())
    }

    /// A block suitable for ``StorageConfiguration/migrate``.
    public var migrationBlock: @Sendable (Migration, UInt64) -> Void {
        let migrator = self

        return { migration, oldSchemaVersion in
            for step in migrator.steps(upgradingFrom: oldSchemaVersion) {
                step.apply(migration)
            }
        }
    }

    /// The steps that would run for a database currently at `oldSchemaVersion`, in the
    /// order they would run.
    ///
    /// Exposed so the ordering and skipping rules can be tested without conjuring a
    /// `Migration`, which only Realm can create.
    public func steps(upgradingFrom oldSchemaVersion: UInt64) -> [SchemaMigrationStep] {
        steps.filter { oldSchemaVersion < $0.toVersion }
    }
}

/// One versioned migration step.
public struct SchemaMigrationStep: Sendable {

    /// The schema version this step brings the database up to.
    public let toVersion: UInt64

    private let body: @Sendable (Migration) -> Void

    public init(toVersion: UInt64, _ body: @escaping @Sendable (Migration) -> Void) {
        self.toVersion = toVersion
        self.body = body
    }

    func apply(_ migration: Migration) {
        body(migration)
    }
}

@resultBuilder
public enum SchemaMigrationBuilder {

    public static func buildBlock(_ steps: SchemaMigrationStep...) -> [SchemaMigrationStep] {
        steps
    }

    public static func buildArray(_ steps: [[SchemaMigrationStep]]) -> [SchemaMigrationStep] {
        steps.flatMap { $0 }
    }

    public static func buildOptional(_ steps: [SchemaMigrationStep]?) -> [SchemaMigrationStep] {
        steps ?? []
    }
}

// MARK: - Upgrading from RealmStorage 1.x

public extension SchemaMigrationStep {

    /// The step that carries a RealmStorage 1.x database forward to 2.0.
    ///
    /// v1's `StorageObject` declared a private `_schemaValue` column on every model, and
    /// `IdentifiableStorageObject` stored the primary key under `identifier`. In 2.0 the
    /// column is gone and the property is called `id`.
    ///
    /// The rename **must** go through `renameProperty`. Declaring `id` as a new property
    /// and letting `identifier` be dropped would leave every row with an empty primary
    /// key — Realm treats that as a delete-plus-add, not a rename.
    ///
    /// - Parameters:
    ///   - toVersion: the schema version this migration produces.
    ///   - typeNames: the model class names to rename `identifier` to `id` on. Pass only
    ///     the types that inherited from `IdentifiableStorageObject` in 1.x.
    static func upgradingFromV1(
        toVersion: UInt64,
        renamingIdentifierOn typeNames: [String]
    ) -> SchemaMigrationStep {
        SchemaMigrationStep(toVersion: toVersion) { migration in
            for typeName in typeNames {
                migration.renameProperty(onType: typeName, from: "identifier", to: "id")
            }

            // `_schemaValue` needs no explicit handling: Realm removes properties that
            // are absent from the new schema automatically once the version increments.
        }
    }
}
