# Changelog

All notable changes to this project are documented here.
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] — 2026-08-18

A rewrite. See [MIGRATION.md](MIGRATION.md) for an upgrade guide.

The 1.x line is unaffected and remains available on the `1.x` branch.

### Changed

- **Realm** — now realm-swift `20.x`, pinned with `.upToNextMajor(from: "20.0.5")`. The previous dependency floated on `realm-cocoa`'s `master` branch, a repository since renamed.
- **Concurrency** — a per-instance `actor RealmStore` replaces `RealmDatabase`, the global `RealmContext`, `RealmDatabaseThread` and `RealmDatabaseQueue`. Reads return frozen values through `StorageResults` and `Frozen`.
- **API** — async/await only. All completion-handler variants are removed.
- **Queries** — Realm's native type-safe `Query`, wrapped in a `Sendable` `DatabaseQuery` value, replaces the vendored PredicateFlow layer and its Sourcery build phase. No code generation is required.
- **Models** — `@Persisted` replaces `@objc dynamic`. `StorageObject` and `IdentifiableStorage` are protocols rather than base classes, so `EmbeddedObject` and `AsymmetricObject` now work.
- **Identity** — `IdentifiableStorage.ID` is an associated type, so `String`, `Int`, `UUID` and `ObjectId` primary keys are all first-class. Looking up by id on a type without a primary key is now a compile error rather than a `fatalError`.
- **Writes** — take Realm's `UpdatePolicy` instead of a `Bool`.
- **Migrations** — `SchemaMigrator` with versioned steps replaces subclassing `RealmMigrationUtility`. `Realm.Configuration.defaultConfiguration` is never mutated.
- **Storage location** — new databases default to Application Support, excluded from backup. Pass `location: .documents` to keep a 1.x database where it is.
- **Platforms** — iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+. Swift 6 language mode, tools version 6.0.

### Added

- `changes(of:matching:)`, an `AsyncThrowingStream` of change notifications with frozen payloads.
- `MainRealmStore`, a main-actor façade returning live `Results` for SwiftUI and UIKit.
- `CorruptionPolicy`, controlling what happens when the database cannot be opened.
- `SecretStore` with a `KeychainSecretStore` implementation and an in-memory double for tests.
- `KeychainAccessibility`, so the Keychain protection class is explicit and configurable.
- `StorageConfiguration.inMemory(...)` for tests and previews.
- `StorageError`, one exhaustive error type replacing several stringly-typed enums.
- An `NSPredicate` escape hatch on `DatabaseQuery`, taking a `@Sendable` factory.
- 113 tests, including migration against a committed 1.x database fixture.

### Removed

- The vendored PredicateFlow query layer (26 files, ~2,000 lines) and its `.stencil` template.
- The `Sourcery` dependency, which no target used but which pulled SourceKitten, Yams, Stencil and xcodeproj into every consumer's dependency graph.
- The `KeychainSwift` dependency, replaced by a direct `SecItem` wrapper. realm-swift is now the only dependency.
- The 18-class `Operation` layer, including the misspelled public `QuearyableReadDatabaseOperation`.
- `RealmWriteTransaction` and both transaction containers, superseded by Realm's nesting-safe `asyncWrite`.
- `EntityID`, `EntityIdentifier` and `CompoundEntityID`. `CompoundID.make(_:)` builds composite keys.
- `Result` helpers (`value`, `error`, `isSuccess`, `isFailure`) and their typealiases.
- `LinuxMain.swift` and `XCTestManifests.swift`.

### Fixed

**Data loss**

- Initialization caught *every* error and deleted the database. A locked Keychain during a background launch, a full disk, or a transient permission failure all destroyed user data. The default is now to rethrow.
- The Keychain item used `whenUnlocked`, so an app woken in the background on a locked device could not read the encryption key — the trigger for the deletion above. Now `afterFirstUnlockThisDeviceOnly`.
- The encryption key fell back to 32 bytes when 64-byte generation failed. Realm requires exactly 64, so the key failed at open. It now throws.
- Resetting the database removed only the main file, leaving the `.lock`, `.note` and `.management` sidecars behind, and targeted the wrong path when encryption was enabled.

**Security**

- `FileProtectionType.none` was applied to the database's containing directory — with the default location, the entire Documents folder — defeating data protection on a database the package also encrypted. Now `.completeUntilFirstUserAuthentication`, scoped to the Realm files, and configurable.
- Databases are excluded from backup by default, so a device-only key and a backed-up file can no longer be separated.

**Correctness**

- `add(object:update:)` mapped `update: false` to `.all`, itself the more destructive upsert, so the flag did the opposite of what it read like.
- `SafeRealmWriteTransactionContainer` called `cancelWrite()` on error even when it had not opened the transaction, tearing down the caller's outer one.
- The Realm instance cache was an unsynchronised dictionary mutated from arbitrary queues — a data race — keyed off `__dispatch_queue_get_label`, with a `fatalError` if decoding failed.
- `QuearyableReadDatabaseOperation` resolved its single-use `ThreadSafeReference` once and returned stale results thereafter.
- `Result.isSuccess` was implemented as `value != nil`, reporting failure for a successful `Result<T?, _>` holding `nil`.
- The `open class var encryptionPrefix` / `encryptionKey` override points were silently ignored: the property wrapper bound the declaring class's statics.
- `RealmSwift.SortDescriptor` was conformed retroactively, colliding with Foundation's same-named type — a regression of the 1.x fix in 240c7c0. `Sort` owns the concept now.
- `toArray()` eagerly materialised every result set, discarding Realm's laziness.
- `Keychain+Data` dispatched on `T.self ==` and force-cast with `as!`.

### Documented

- Realm's query engine rejects the `ALL` modifier and `MATCHES` (regular expressions) in every form, and supports only `AND`, `OR` and `NOT` compound predicates. 1.x exposed `all(_:)` and `matches(_:)` through PredicateFlow, but neither ever worked against a Realm database.
- An unsupported predicate raises an Objective-C exception rather than throwing a Swift error, so it cannot be caught with `try`.

## [1.0.5] — 2026-08-18

Released from the 1.x maintenance branch. No source changes.

### Fixed

- Tag `1.0.4` predated the ambiguous-`SortDescriptor` fix (`240c7c0`) and the merge of PR #1, so CocoaPods consumers never received either. `1.0.5` ships the existing `master` tree.

## [1.0.4] — 2020-11-28

Initial public releases (`1.0.0`–`1.0.4`).

[2.0.0]: https://github.com/AndrewKochulab/RealmStorage/releases/tag/2.0.0
[1.0.5]: https://github.com/AndrewKochulab/RealmStorage/releases/tag/1.0.5
[1.0.4]: https://github.com/AndrewKochulab/RealmStorage/releases/tag/1.0.4
