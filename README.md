# RealmStorage

[![Swift 6](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-iOS%2013%20%7C%20macOS%2010.15%20%7C%20tvOS%2013%20%7C%20watchOS%206-lightgrey.svg)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A modern wrapper for [Realm](https://github.com/realm/realm-swift) — actor-isolated, async/await only, and safe under Swift 6 strict concurrency.

```swift
let store = RealmStore(
    configuration: StorageConfiguration(schemaVersion: 1, objectTypes: [User.self])
)
try await store.open()

let users = try await store.objects(User.self) {
    $0.firstName == "Robert" && $0.events.count >= 5 && $0.updatedAt != nil
}
```

> **Upgrading from 1.x?** 2.0 was a rewrite. See [MIGRATION.md](MIGRATION.md) for a step-by-step guide. The 1.x line remains available via SPM and as source on the [`1.x`](https://github.com/AndrewKochulab/RealmStorage/tree/1.x) branch — but it can no longer be installed through CocoaPods on a current toolchain, for reasons outside this package's control ([details](CHANGELOG.md#105--2026-08-18)).

## Features

- **Actor-isolated.** One `actor` owns the Realm; there is no shared mutable global and no thread-confinement bookkeeping to get wrong.
- **Swift 6 clean.** Builds in Swift 6 language mode with zero warnings and no `@unchecked` conformances on Realm's own types.
- **async/await only.** No completion handlers.
- **Type-safe queries** built on Realm's native `Query` — no code generation, no build phase, no generated file.
- **Live observation** through `AsyncThrowingStream`, plus a main-actor façade for SwiftUI.
- **Encryption at rest**, with the key held in the Keychain and provisioned automatically.
- **One dependency** — realm-swift, and nothing else.

## Installation

### Swift Package Manager

```swift
.package(url: "https://github.com/AndrewKochulab/RealmStorage.git", from: "2.0.0")
```

Then add `RealmStorage` to your target's dependencies.

### CocoaPods

```ruby
pod 'RealmStorage', '~> 2.1'
```

No build phase is required. 1.x needed a Sourcery run to generate query schemas; 2.0 does not.

## Defining models

Models are ordinary Realm objects using `@Persisted`, marked with `StorageObject` — or `IdentifiableStorage` when they have a primary key.

```swift
import RealmSwift
import RealmStorage

final class User: Object, IdentifiableStorage {
    @Persisted(primaryKey: true) var id: UUID
    @Persisted var firstName: String
    @Persisted var lastName: String
    @Persisted var age: Int
    @Persisted var createdAt: Date
    @Persisted var updatedAt: Date?
    @Persisted var events: List<Event>
}

final class Event: Object, IdentifiableStorage {
    @Persisted(primaryKey: true) var id: UUID
    @Persisted var name: String
    @Persisted var date: Date?
}
```

`IdentifiableStorage` takes the key's type from your `id` property, so `String`, `Int`, `UUID` and `ObjectId` all work. Looking an object up by id on a type without a primary key is a compile error.

For a composite key, build the string with `CompoundID`:

```swift
final class EventMember: Object, IdentifiableStorage {
    @Persisted(primaryKey: true) var id: String
    @Persisted var user: User?
    @Persisted var event: Event?

    func updateCompoundID() {
        guard let user, let event else { return }
        id = CompoundID.make(user.id.uuidString, event.id.uuidString)
    }
}
```

## Opening a store

```swift
let store = RealmStore(
    configuration: StorageConfiguration(
        schemaVersion: 1,
        objectTypes: [User.self, Event.self, EventMember.self]
    )
)

try await store.open()
```

`StorageConfiguration` is a `Sendable` value. The defaults are chosen so that the safe thing happens without configuration:

| | Default | Why |
|---|---|---|
| `location` | `.applicationSupport` | Not user-visible, and excluded from backup by default |
| `fileProtection` | `.completeUntilFirstUserAuthentication` | Data protection stays on, while background launches still work |
| `excludedFromBackup` | `true` | The encryption key is device-only; a restored backup would have no key for the file |
| `corruptionPolicy` | `.rethrow` | Nothing is ever deleted without you asking |
| `encryption` | `.none` | Opt in explicitly |

### Encryption

```swift
let configuration = StorageConfiguration(
    schemaVersion: 1,
    encryption: .keychain(store: KeychainSecretStore()),
    objectTypes: [User.self]
)
```

A 64-byte key is generated on first launch and kept in the Keychain as `afterFirstUnlockThisDeviceOnly`, so a background launch on a locked device can still open the database. If an unencrypted database already exists, it is copied into the encrypted file and the plaintext one is removed.

With encryption on, the file is named `<fileName>_encrypted.realm` — the suffix is what makes that one-time migration from a 1.x plaintext database possible. Use `StorageLocation.file(_:)` when you want to name the file yourself.

You can supply your own key with `.key(_:)`, or your own storage by conforming to `SecretStore`.

## Querying

Queries are composable values built on Realm's native type-safe `Query`.

```swift
let query = DatabaseQuery<User>()
    .where { $0.firstName == "Robert" && $0.events.count >= 5 }
    .sorted(by: \.createdAt, ascending: false)
    .limited(to: 20)

let users = try await store.objects(User.self, matching: query)
```

Building on a query returns a new one, so a shared base is safe to hold and extend.

`limited(to:)` applies everywhere the query is used — reads and writes alike — so
`delete(_:matching: query.limited(to: 5))` removes at most five objects.

For a one-off filter, pass the closure directly:

```swift
let adults = try await store.objects(User.self) { $0.age >= 18 }
```

### Reading

```swift
let all      = try await store.all(User.self)
let user     = try await store.object(User.self, id: someUUID)
let some     = try await store.objects(User.self, ids: [idA, idB])
let first    = try await store.first(User.self, matching: query)
let total    = try await store.count(User.self)
let anyMatch = try await store.contains(User.self, matching: query)
```

Reads return frozen values, so they are safe to pass anywhere. `StorageResults` stays lazy — call `.array()` when you want everything materialised. Single objects come back as `Frozen<Element>`, which reads through to the object, so `user?.firstName` works as written.

To get plain value types out instead, map inside the store:

```swift
let names = try await store.objects(User.self, matching: query) { $0.firstName }
```

### Writing

```swift
try await store.save(User(id: UUID(), firstName: "Steve"))
try await store.save([userA, userB], update: .modified)

try await store.update(User.self, id: userID) { user in
    user.firstName = "Tony"
}

try await store.delete(User.self, id: userID)
try await store.delete(User.self, matching: DatabaseQuery { $0.isActive == false })
```

For several changes in one transaction:

```swift
try await store.write { realm in
    realm.add(user, update: .modified)
    realm.add(event, update: .modified)
}
```

A throwing block rolls the whole transaction back.

### Observing

```swift
for try await change in await store.changes(of: User.self, matching: query) {
    switch change {
    case .initial(let users):
        render(users)
    case .update(let users, let deletions, let insertions, let modifications):
        apply(users, deletions, insertions, modifications)
    }
}
```

Payloads are frozen. Ending the loop invalidates the notification token. With a
`limited(to:)` query the reported indices are those visible within the limit, so
`results[index]` is always safe.

To watch one object instead, pass its primary key. The stream reports which properties
changed, and finishes once the object is deleted:

```swift
for try await change in await store.changes(of: User.self, id: userID) {
    switch change {
    case .initial(let user), .change(let user, _):
        render(user)
    case .deleted:
        dismiss()
    }
}
```

### SwiftUI

`RealmStore` hands back frozen snapshots, which is what makes it safe to share — but SwiftUI wants live, auto-updating results. `MainRealmStore` provides those, pinned to the main actor:

```swift
@MainActor
final class UserListModel: ObservableObject {
    private let store = MainRealmStore(
        configuration: StorageConfiguration(objectTypes: [User.self])
    )

    @Published var users: Results<User>?

    func load() async throws {
        try await store.open()
        users = try store.objects(User.self) { $0.isActive == true }
    }
}
```

Both types can point at the same `StorageConfiguration`.

## Backups and maintenance

`writeCopy` produces a compacted copy — useful for backups, support bundles, or shipping a
seed database:

```swift
try await store.writeCopy(to: backupURL)                        // plaintext
try await store.writeCopy(to: backupURL, encryptionKey: key)    // encrypted
```

Open a copy again with `StorageLocation.file(_:)`, which uses the path exactly as given
rather than applying the usual naming convention:

```swift
let restored = RealmStore(
    configuration: StorageConfiguration(location: .file(backupURL), objectTypes: [User.self])
)
```

Realm files only grow, so a long-lived database with heavy churn can accumulate dead
space. `fileSize()` tells you how much, and compaction is opt-in:

```swift
configuration.shouldCompactOnLaunch = { total, used in
    total > 100 * 1024 * 1024 && Double(used) / Double(total) < 0.5
}
```

## Migrations

Express each schema change as a step; RealmStorage runs the ones that apply, in order.

```swift
let migrator = SchemaMigrator {
    SchemaMigrationStep(toVersion: 2) { migration in
        migration.renameProperty(onType: "User", from: "name", to: "firstName")
    }
    SchemaMigrationStep(toVersion: 3) { migration in
        migration.enumerateObjects(ofType: "User") { _, new in
            new?["isActive"] = true
        }
    }
}

var configuration = StorageConfiguration(schemaVersion: 3, objectTypes: [User.self])
configuration.migrate = migrator.migrationBlock
```

## Query reference

Realm's `Query` covers everything the 1.x PredicateFlow layer did:

| Need | Write |
|---|---|
| Equality | `$0.name == "Robert"`, `$0.name != "Robert"` |
| Membership | `$0.name.in(["Robert", "Tony"])` |
| Comparison | `$0.age > 30`, `$0.age <= 30` |
| Optionals | `$0.updatedAt != nil` |
| Booleans | `$0.isActive == true` |
| Strings | `.contains`, `.starts(with:)`, `.ends(with:)`, `.like` |
| Case / diacritics | `$0.name.contains("rob", options: .caseInsensitive)` |
| Negation | `!$0.name.contains("x")` |
| Compound | `&&`, `\|\|` |
| Collections | `$0.events.count >= 5`, `.min`, `.max`, `.avg`, `.sum` |
| Relationships | `$0.events.name == "Talk"` (implicit ANY) |

For anything left over — `SUBQUERY(...).@count`, `NONE`, `BETWEEN` — drop to a predicate:

```swift
DatabaseQuery<User>().filter {
    NSPredicate(format: "SUBQUERY(events, $e, $e.name == %@).@count > 1", "Talk")
}
```

> **Realm's own limits.** Realm's query engine rejects the `ALL` modifier and `MATCHES` (regular expressions) in every form, and supports only `AND`, `OR` and `NOT` compound predicates. RealmStorage 1.x exposed `all(_:)` and `matches(_:)` through PredicateFlow, but neither ever worked against a Realm database. An unsupported predicate raises an Objective-C exception rather than throwing, so it cannot be caught — cover raw predicates with a test.

## Requirements

| | |
|---|---|
| Swift | 6.0+ |
| Xcode | 26.0+ |
| Platforms | iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+ |
| Realm | realm-swift 20.x |

RealmStorage builds in Swift 6 language mode. Because language mode is per-target, your own code can stay on Swift 5.

### A note on Realm

MongoDB no longer distributes Realm. [realm-swift](https://github.com/realm/realm-swift) 20.x is community-maintained and local-only — Atlas Device Sync was removed. RealmStorage has always been a local-persistence wrapper, so nothing it offered depended on sync.

## Contributing

⭐️ If you like what you see, star us on GitHub.

Found a bug, a typo, or something documented badly? Please open an issue. Contributions are welcome and appreciated — see [CONTRIBUTING.md](CONTRIBUTING.md) for how to get set up and what the tests expect.

## License

MIT. See [LICENSE](LICENSE).
