//
//  MigrationTests.swift
//  RealmStorageTests
//

import Foundation
import RealmSwift
import Testing
@testable import RealmStorage

@Suite("Migration")
struct MigrationTests {

    @Test("steps run in ascending version order")
    func stepsRunInOrder() {
        let migrator = SchemaMigrator(steps: [
            SchemaMigrationStep(toVersion: 3) { _ in },
            SchemaMigrationStep(toVersion: 1) { _ in },
            SchemaMigrationStep(toVersion: 2) { _ in }
        ])

        #expect(migrator.steps(upgradingFrom: 0).map(\.toVersion) == [1, 2, 3])
    }

    @Test("steps at or below the current version are skipped")
    func stepsAreSkipped() {
        let migrator = SchemaMigrator(steps: [
            SchemaMigrationStep(toVersion: 1) { _ in },
            SchemaMigrationStep(toVersion: 2) { _ in },
            SchemaMigrationStep(toVersion: 3) { _ in }
        ])

        #expect(migrator.steps(upgradingFrom: 2).map(\.toVersion) == [3])
        #expect(migrator.steps(upgradingFrom: 3).isEmpty)
    }

    @Test("the result builder collects steps")
    func resultBuilder() {
        let migrator = SchemaMigrator {
            SchemaMigrationStep(toVersion: 1) { _ in }
            SchemaMigrationStep(toVersion: 2) { _ in }
        }

        #expect(migrator.steps(upgradingFrom: 0).map(\.toVersion) == [1, 2])
    }

    /// The 1.x upgrade, run against a real RealmStorage 1.x database file committed as a
    /// test fixture (`Fixtures/v1-schema.realm`). Using a fixture rather than writing the
    /// old schema at runtime is not just convenient: Realm will not let two Swift classes
    /// claim the same object name in one process, so the old and new shapes cannot both
    /// be declared in the test bundle.
    ///
    /// The rename **must** go through `renameProperty`. Declaring `id` as a new property
    /// and letting `identifier` be dropped is a delete-plus-add, which would leave every
    /// row with an empty primary key — so this asserts the values, not just the shape.
    @Test("upgrading a real 1.x file renames identifier to id, keeps values, drops _schemaValue")
    @MainActor
    func upgradeFromV1Fixture() async throws {
        try await TestStore.withTemporaryDirectory { directory in
            let fixture = try #require(
                Bundle.module.url(forResource: "v1-schema", withExtension: "realm", subdirectory: "Fixtures")
            )

            let fileURL = directory.appendingPathComponent("default").appendingPathExtension("realm")
            try FileManager.default.copyItem(at: fixture, to: fileURL)

            let migrator = SchemaMigrator(steps: [
                .upgradingFromV1(toVersion: 2, renamingIdentifierOn: ["User"])
            ])

            let store = RealmStore(
                configuration: StorageConfiguration(
                    location: .directory(directory),
                    schemaVersion: 2,
                    fileProtection: nil,
                    excludedFromBackup: false,
                    objectTypes: TestModels.all,
                    migrate: migrator.migrationBlock
                )
            )
            try await store.open()

            // Primary keys survived the rename rather than being reset to "".
            let ids = try await store.objects(User.self, matching: DatabaseQuery<User>().sorted(by: \.id)) { $0.id }
            let names = try await store.objects(User.self, matching: DatabaseQuery<User>().sorted(by: \.id)) { $0.firstName }

            #expect(ids == ["user-0", "user-1", "user-2"])
            #expect(names == ["Steve", "Tony", "Bruce"])

            // The dead column v1 added to every table is gone.
            let properties = try await store.withRealm { realm -> [String] in
                realm.schema["User"]?.properties.map(\.name) ?? []
            }

            #expect(properties.contains("id"))
            #expect(!properties.contains("_schemaValue"))
            #expect(!properties.contains("identifier"))
        }
    }

    @Test("a plain schema-version bump adding a property preserves data")
    func addingAPropertyPreservesData() async throws {
        try await TestStore.withTemporaryDirectory { directory in
            func makeConfiguration(schemaVersion: UInt64) -> StorageConfiguration {
                StorageConfiguration(
                    location: .directory(directory),
                    schemaVersion: schemaVersion,
                    fileProtection: nil,
                    excludedFromBackup: false,
                    objectTypes: TestModels.all
                )
            }

            let store = RealmStore(configuration: makeConfiguration(schemaVersion: 1))
            try await store.open()
            try await store.save(User(id: "u1", firstName: "Steve"))
            await store.close()

            let upgraded = RealmStore(configuration: makeConfiguration(schemaVersion: 2))
            try await upgraded.open()

            #expect(try await upgraded.object(User.self, id: "u1")?.firstName == "Steve")
        }
    }
}
