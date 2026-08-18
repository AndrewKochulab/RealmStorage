# Migrating from RealmStorage 1.x to 2.0

2.0 is a rewrite. It moves to realm-swift 20, replaces the vendored PredicateFlow query layer with Realm's own type-safe queries, and makes the whole surface async/await over an actor-isolated database.

**Nothing breaks until you upgrade.** 1.x stays where it is: the `1.x` branch and tag `1.0.5` (which, unlike `1.0.4`, finally includes the SortDescriptor fix from 2021). Pin to `~> 1.0` and you are unaffected.

Budget an afternoon for a small app. Most of the work is mechanical, and the compiler finds nearly all of it.

## At a glance

| 1.x | 2.0 |
|---|---|
| `RealmDatabase` + global `RealmContext` | `RealmStore` (one actor instance, no global) |
| `RealmPersistence<T>` subclasses | methods on `RealmStore` |
| 18 `*DatabaseOperation` classes | `DatabaseQuery` values |
| PredicateFlow + Sourcery build phase | Realm's native `.where` |
| `@objc dynamic` models | `@Persisted` models |
| `IdentifiableStorageObject` (base class) | `IdentifiableStorage` (protocol) |
| `EntityID` / `EntityIdentifier` | your own `id` type — `String`, `Int`, `UUID`, `ObjectId` |
| `CompoundEntityID` | `CompoundID.make(_:)` |
| completion handlers | `async`/`await` |
| `RealmMigrationUtility` subclass | `StorageConfiguration` + `SchemaMigrator` |
| `KeychainSwift` dependency | built-in `KeychainSecretStore` |
| Realm 10.x | realm-swift 20.x |

## 1. Remove the Sourcery build phase

1.x asked you to add a Run Script phase invoking Sourcery against `PredicateFlow.stencil`, and to import the generated file. 2.0 generates nothing.

- Delete the Run Script build phase (the one referencing `$PODS_ROOT/Sourcery/bin/sourcery`).
- Delete `PredicateFlow.generated.swift` from your project.
- Remove `PredicateSchema` conformances from your models.

If you leave the build phase in place it will fail with a confusing path error, because the `.stencil` template no longer exists.

## 2. Update your models

Realm forbids mixing `@objc dynamic` and `@Persisted` within a class *or any of its ancestors*. 1.x's `StorageObject` declared `@objc dynamic` properties, so inheriting from it locked you out of `@Persisted` entirely. That is why the base classes had to go.

**Before**

```swift
final class User: IdentifiableStorageObject, PredicateSchema {
    dynamic var createdAt = Date()
    dynamic var updatedAt: Date?
    dynamic var firstName = ""
    let events = List<Event>()
}
```

**After**

```swift
final class User: Object, IdentifiableStorage {
    @Persisted(primaryKey: true) var id: String
    @Persisted var createdAt: Date
    @Persisted var updatedAt: Date?
    @Persisted var firstName: String
    @Persisted var events: List<Event>
}
```

Points to note:

- Inherit from `Object` directly and adopt `IdentifiableStorage` (or `StorageObject` for a model without a primary key).
- Declare `id` yourself with `@Persisted(primaryKey: true)`. There is no `primaryKey()` override, and `id` is now a real stored property you can query and sort on — in 1.x it was computed over a private `identifier`, so predicates had to reference the private name.
- The key's type is yours to choose. `String` keeps existing data working; `UUID` or `ObjectId` are better for new models.
- `EntityIdentifier(value:)` is gone — assign the value directly. `CompoundEntityID(items:separator:)` becomes `CompoundID.make(_:separator:)`, which returns a `String`.

## 3. Write the schema migration

Your existing database is in the 1.x shape, and two things about it changed:

- Every table carried a private `_schemaValue` column that `StorageObject` added. It is gone.
- The primary key was stored as `identifier`. It is now `id`.

The rename **must** go through `renameProperty`. If you simply declare `id` and let `identifier` be dropped, Realm treats that as a delete plus an add, and **every row loses its primary key**.

```swift
let migrator = SchemaMigrator(steps: [
    .upgradingFromV1(
        toVersion: 2,
        renamingIdentifierOn: ["User", "Event", "EventMember"]
    )
])

var configuration = StorageConfiguration(
    schemaVersion: 2,
    objectTypes: [User.self, Event.self, EventMember.self]
)
configuration.migrate = migrator.migrationBlock
```

List every model that inherited from `IdentifiableStorageObject`. `_schemaValue` needs no handling — Realm drops properties absent from the new schema once the version increments.

Bump `schemaVersion` past whatever your app last shipped. Test the upgrade against a real 1.x database before releasing.

## 4. Replace the database object

**Before**

```swift
let database = RealmDatabase()
database.migrationUtilityContext = { MyMigrationUtility(schemaVersion: 3) }
try database.initiateModule()
```

**After**

```swift
let store = RealmStore(configuration: configuration)
try await store.open()
```

There is no global `RealmContext`. Hold the `RealmStore` wherever you keep your dependencies and pass it in. It is `Sendable`, so sharing it is safe, and you can have more than one.

If you subclassed `RealmMigrationUtility` to override `storageDirectoryURL()`, `encryptedStorageName()` or similar, those are now fields on `StorageConfiguration` (`location`, `fileName`, `encryption`). Note that overriding `encryptionPrefix`/`encryptionKey` never actually worked in 1.x — the property wrapper bound the declaring class's statics, so subclass overrides were ignored.

### Keep your file where it is

1.x stored the database in **Documents**. 2.0 defaults to Application Support. If you do not say otherwise, your app will not find its existing data:

```swift
StorageConfiguration(
    location: .documents,        // keep 1.x's location
    fileName: "default",
    schemaVersion: 2,
    objectTypes: [...]
)
```

Move to `.applicationSupport` only when you are ready to relocate the file yourself.

## 5. Replace persistence subclasses

1.x had you declare a `RealmPersistence` subclass per model and reach it through a `DB` facade you wrote. 2.0 uses one store, with the model type as a parameter.

**Before**

```swift
final class UserPersistence: RealmPersistence<User> {}
let users = DB.user().all().get()
```

**After**

```swift
let users = try await store.all(User.self)
```

For per-model helpers, extend the store instead of subclassing:

```swift
extension RealmStore {
    func activeUsers() async throws -> StorageResults<User> {
        try await objects(User.self) { $0.isActive == true }
    }
}
```

## 6. Translate your queries

`$0` is now the model's key paths rather than a generated schema, and the operators are Swift's own.

| 1.x (PredicateFlow) | 2.0 (Realm `Query`) |
|---|---|
| `$0.firstName.isEqual("Robert")` | `$0.firstName == "Robert"` |
| `$0.firstName.isNotEqual("Robert")` | `$0.firstName != "Robert"` |
| `$0.firstName.isIn(["A", "B"])` | `$0.firstName.in(["A", "B"])` |
| `$0.age.isGreater(than: 30)` | `$0.age > 30` |
| `$0.age.isGreater(thanOrEqual: 30)` | `$0.age >= 30` |
| `$0.age.isLess(than: 30)` | `$0.age < 30` |
| `$0.age.isLess(thanOrEqual: 30)` | `$0.age <= 30` |
| `$0.updatedAt.isNil` | `$0.updatedAt == nil` |
| `$0.updatedAt.isNotNil` | `$0.updatedAt != nil` |
| `$0.isActive.isTrue` | `$0.isActive == true` |
| `$0.isActive.isFalse` | `$0.isActive == false` |
| `$0.name.contains("ob")` | `$0.name.contains("ob")` |
| `$0.name.begins(with: "R")` | `$0.name.starts(with: "R")` |
| `$0.name.ends(with: "t")` | `$0.name.ends(with: "t")` |
| `$0.name.like("R*t")` | `$0.name.like("R*t")` |
| `$0.name.notContains("x")` | `!$0.name.contains("x")` |
| `$0.name.contains("x", options: .caseInsensitive)` | `$0.name.contains("x", options: .caseInsensitive)` |
| `$0.events.count().isGreater(thanOrEqual: 5)` | `$0.events.count >= 5` |
| `$0.events.isEmpty` | `$0.events.count == 0` |
| `$0.events.avg()` / `.min()` / `.max()` / `.sum()` | `$0.events.avg` / `.min` / `.max` / `.sum` |

Compounds fold into one closure:

**Before**

```swift
DB.user().objects { query in
    query.add { $0.firstName.isEqual("Robert") }
         .and { $0.events.count().isGreater(thanOrEqual: 5) }
         .and(\.updatedAt.isNotNil)
    query.sort { $0.createdAt.descending() }
}.get()
```

**After**

```swift
try await store.objects(
    User.self,
    matching: DatabaseQuery<User>()
        .where { $0.firstName == "Robert" && $0.events.count >= 5 && $0.updatedAt != nil }
        .sorted(by: \.createdAt, ascending: false)
)
```

### Two things that never worked

1.x exposed `matches(_:)` (regular expressions) and an `all` quantifier through PredicateFlow. **Realm's query engine supports neither**, in any form — a query using them threw at runtime against a Realm database. If you have such a query, it was already failing; rework it rather than looking for the 2.0 equivalent.

For `SUBQUERY`, `NONE` and `BETWEEN`, use the predicate escape hatch:

```swift
DatabaseQuery<User>().filter {
    NSPredicate(format: "SUBQUERY(events, $e, $e.name == %@).@count > 1", "Talk")
}
```

## 7. Move to async/await

Every completion handler is gone. Where 1.x had a sync and an async form, there is now one `async` method.

| 1.x | 2.0 |
|---|---|
| `DB.user().all().get()` | `try await store.all(User.self)` |
| `DB.user().all { op in ... }` | `try await store.all(User.self)` |
| `DB.user().object(by: id)` | `try await store.object(User.self, id: id)` |
| `DB.event().first { e in ... }` | `try await store.first(Event.self)` |
| `DB.event().last()` | `try await store.last(Event.self)` |
| `DB.user().save(user)` | `try await store.save(user)` |
| `DB.user().update(user) { ... }` | `try await store.update(User.self, id: user.id) { ... }` |
| `DB.user().delete(by: id)` | `try await store.delete(User.self, id: id)` |
| `DB.user().deleteAll()` | `try await store.deleteAll(User.self)` |
| `try DB.perform { transaction in ... }` | `try await store.write { realm in ... }` |

Custom `ReadObjectsDatabaseOperation` subclasses become extensions:

**Before**

```swift
final class ReadCurrentSubscriptionsDatabaseOperation: ReadObjectsDatabaseOperation<Subscription> {
    init(shouldThreadSafe: Bool = false) {
        super.init(matching: { query in
            query.add(\.hasExpired.isFalse)
            query.sort { $0.expiresAt.descending() }
        }, shouldThreadSafe: shouldThreadSafe)
    }
}
```

**After**

```swift
extension DatabaseQuery where Element == Subscription {
    static var current: DatabaseQuery<Subscription> {
        DatabaseQuery<Subscription>()
            .where { $0.hasExpired == false }
            .sorted(by: \.expiresAt, ascending: false)
    }
}

let current = try await store.objects(Subscription.self, matching: .current)
```

`shouldThreadSafe` has no successor and needs none: results are frozen, so they are already safe to move between threads.

### Transactions

`transaction.add(object:update:)` took a `Bool` that mapped to `update ? .modified : .all`. Because `.all` is itself an upsert — the more destructive one — `update: false` silently overwrote rather than erroring. 2.0 takes Realm's `UpdatePolicy` directly:

```swift
try await store.save(user, update: .modified)   // merge into an existing row
try await store.save(user, update: .all)        // overwrite it wholesale
try await store.save(user, update: .error)      // throw if it already exists
```

Check any 1.x call passing `update: false` — it was probably meant to be `.error`.

## 8. Results are frozen now

Reads return immutable snapshots, which is what allows them to leave the actor.

```swift
let users = try await store.all(User.self)   // StorageResults<User>, frozen
let user  = try await store.object(User.self, id: id)   // Frozen<User>?
```

`Frozen` reads through to the object, so `user?.firstName` still works. When you need the object itself, use `user?.object`; to mutate it, `thawed()` on the right actor, or go through `store.update(_:id:)`.

`StorageResults` is a lazy `RandomAccessCollection` — it does not materialise everything the way 1.x's `toArray()` did. Call `.array()` when you actually want an array.

### If you were binding results to a view

Frozen results do not auto-update, so SwiftUI and UIKit need either the change stream or the main-actor façade:

```swift
for try await change in await store.changes(of: User.self) {
    render(change.results)
}
```

```swift
@MainActor let store = MainRealmStore(configuration: configuration)
try await store.open()
let users = try store.objects(User.self)   // live, auto-updating Results
```

## 9. Check the defaults that changed

Several 1.x behaviours were unsafe and no longer happen by default:

- **The database is no longer deleted on failure.** 1.x caught *every* initialization error and deleted the file — a locked Keychain, a full disk or a transient permission error all destroyed user data. The default is now `.rethrow`. Opt back in with `corruptionPolicy: .deleteAndRecreate` if you want it, though it is deliberately narrow about what counts as corruption.
- **Data protection is on.** 1.x set `FileProtectionType.none` on the database's containing directory — with its default location, all of Documents. The default is now `.completeUntilFirstUserAuthentication`. If you genuinely need access before first unlock, set `fileProtection` explicitly.
- **The Keychain item is `afterFirstUnlockThisDeviceOnly`.** 1.x inherited KeychainSwift's `whenUnlocked`, so an app woken in the background on a locked device could not read the key — which is exactly what triggered the deletion above.
- **New databases are excluded from backup.** The key is device-only, so a restored backup would otherwise contain a file with no key to open it.

## Getting help

If something here does not cover your case, please [open an issue](https://github.com/AndrewKochulab/RealmStorage/issues) — gaps in this guide are worth fixing.
