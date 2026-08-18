# Contributing

Thanks for looking. Issues and pull requests are both welcome.

## Getting set up

```bash
git clone https://github.com/AndrewKochulab/RealmStorage.git
cd RealmStorage
swift test
```

The first build compiles Realm from source and takes a few minutes; later builds are fast.

You need **Xcode 26 or newer** — realm-swift 20.x requires it.

## Before opening a pull request

```bash
swift test
swift build -Xswiftc -warnings-as-errors
swiftlint --strict
```

CI runs all three, plus per-platform builds, an iOS simulator test run, and the suite under Thread Sanitizer.

## What the tests expect

Tests use [swift-testing](https://github.com/swiftlang/swift-testing) (`@Test`, `#expect`), not XCTest.

Most tests run against an in-memory database through `TestStore.make()`, which gives each test its own identifier so the suite runs in parallel. Two constraints are worth knowing:

- **Retain the store.** Realm destroys an in-memory database when its last reference is released, so a test that drops the store mid-way sees an empty database.
- **Encryption needs a file.** Realm rejects an in-memory identifier combined with an encryption key, so encryption tests use `TestStore.withTemporaryDirectory`.

For anything touching the Keychain, inject `InMemorySecretStore` rather than reaching for the system Keychain — it is not reliably available to a bare `swift test` process.

**A bug fix should come with a test that fails without it.** That is the only way to know the fix works and stays working.

## Things worth knowing about the design

A few constraints shape the code, and changes that ignore them tend not to work:

- **Live Realm objects cannot leave the actor.** They are not `Sendable`, and the Swift 6 compiler enforces it. Reads return frozen values wrapped in `StorageResults` or `Frozen`. If you find yourself wanting to return a live object, the answer is usually `MainRealmStore` or a `transform:` closure.
- **`@unchecked Sendable` goes on our types, never Realm's.** `StorageResults` and `Frozen` are `@unchecked` because they hold a *frozen* value — an invariant enforced in one initializer. Declaring `Object: @retroactive @unchecked Sendable` would also claim live objects are safe to share, which is false.
- **Everything goes through `QueryPlan`.** Realm has no native `LIMIT`, so `limited(to:)` is applied by that type. A call site that reaches for `realm.objects(_:)` directly silently ignores the limit — harmless for a read, destructive for a delete.
- **No global state.** The package never touches `Realm.Configuration.defaultConfiguration`. Configuration is passed explicitly, which is what lets two stores coexist and tests run in parallel.
- **Realm's own limits are real.** Its query engine rejects the `ALL` modifier and `MATCHES` (regular expressions) in every form, and reports unsupported predicates as an Objective-C exception rather than a Swift error — so they cannot be caught with `try`. Cover any raw predicate with a test.

## Commit messages

Explain why the change is needed, not just what it does. If you fixed a bug, say what went wrong and how it showed up.

## Releasing

Maintainers only:

1. Update `CHANGELOG.md`, and `MIGRATION.md` if anything on disk changed.
2. Bump the version in `RealmStorage.podspec`.
3. Merge, then tag: `git tag -a X.Y.Z -m "RealmStorage X.Y.Z" && git push origin refs/tags/X.Y.Z`
4. `gh release create X.Y.Z`
5. `pod trunk push RealmStorage.podspec`

The `1.x` branch is maintenance only — no new features.
