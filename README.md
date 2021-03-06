# RealmStorage

Modern wrapper for Realm Database [iOS, macOS, tvOS &amp; watchOS]

## Quick usage

An easy way to write code like below, strong-typed fetch queries, fast-developing data layer, multithreading, and much more interesting things.

````swift
let users = DB.user().objects { query in
   query.add { $0.firstName.isEqual("Robert") }
        .and { $0.events.count().isGreater(thanOrEqual: 5) }
        .and(\.updatedAt.isNotNil)
}.get()
````

## Features

`RealmStorage` supports the following operations:

- Schemas autogeneration
- Built-in database migration
- Multithreading
- Strong-typed fetch queries
- Write transactions
- All CRUD operations 


## How to use
### Installation

To add `RealmStorage` to a  [Swift Package Manager](https://swift.org/package-manager/)  based project, add:

````swift
.package(url: "https://github.com/AndrewKochulab/RealmStorage.git")
````

Cocoapods:

````
pod 'RealmStorage'
````

Create a new build phase `Project -> Main Target -> Build Phases` and add the next code:

````
"$PODS_ROOT/Sourcery/bin/sourcery" --sources "$PODS_ROOT/RealmStorage/Sources/RealmStorage/PredicateFlow/Core/Classes/Utils/" --sources "$SRCROOT" --templates "$PODS_ROOT/RealmStorage/Sources/RealmStorage/PredicateFlow/Core/Templates/PredicateFlow.stencil" --output "$SRCROOT/PredicateFlow.generated.swift" --disableCache
````

Import `PredicateFlow.generated.swift` file to your Main target.

It will automatically generate all schemas needed for fetch database queries (see details below).

### Example

#### Create Tables

````swift
import RealmSwift
import RealmStorage

final class User: IdentifiableStorageObject, PredicateSchema {
  enum Gender: String {
    case male, female
  }
  
  dynamic var createdAt = Date()
  dynamic var updatedAt: Date?
    
  dynamic var firstName = ""
  dynamic var lastName = ""
    
  private dynamic var genderName = ""
    
  var gender: Gender? {
    get { Gender(rawValue: genderName) }
    set { genderName = newValue?.rawValue ?? "" }
  }
    
  let events = List<Event>()
}

final class Event: IdentifiableStorageObject, PredicateSchema {
  dynamic var date: Date?
  dynamic var name = ""
  dynamic var author: User?
    
  let members = List<EventMember>()
}

final class EventMember: IdentifiableStorageObject, PredicateSchema {
  dynamic var joinedAt = Date()
  dynamic var user: User? {
    didSet {
      updateCompoundID()
    }
  }
    
  dynamic var event: Event? {
    didSet {
      updateCompoundID()
    }
  }
    
  private func updateCompoundID() {
    guard let user = user,
      let event = event else {
        return
    }
        
    self.id = CompoundID(
      items: user.id.value, event.id.value,
      separator: "_"
    )
  }
}
````

#### Autogenerated-schema code looks like

Thanks, Andrea Del Fante for PredicateFlow library.
See repository: https://github.com/andreadelfante/PredicateFlow

````swift
/// The "User" Predicate Schema
internal struct UserSchema: GeneratedPredicateSchema {
    internal var identifier: StringPredicateProperty { return builder.string("identifier") }
    internal var createdAt: PredicateProperty<Date> { return builder.generic("createdAt") }
    internal var updatedAt: PredicateProperty<Date> { return builder.generic("updatedAt") }
    internal var firstName: StringPredicateProperty { return builder.string("firstName") }
    internal var lastName: StringPredicateProperty { return builder.string("lastName") }
    internal var genderName: StringPredicateProperty { return builder.string("genderName") }
    internal var events: CollectionProperty<EventSchema> { return builder.collection("events") }
}
````

#### Save objects in transaction

````swift
let user = User().apply {
  $0.id = Identifier(value: "user_id")
  $0.firstName = "Steve"
  $0.lastName = "Rogers"
  $0.gender = .male
}

let event = Event().apply {
  $0.id = Identifier(value: "event_id")
  $0.name = "Avengers Game"
  $0.date = Date().addingTimeInterval(3600 * 10)
  $0.author = user
}

let eventMember = EventMember().apply {
  $0.event = event
  $0.user = user
}.apply {
  event.members.append($0)
}

try DB.perform { transaction in
  transaction.add(
    objects: [user, event, eventMember],
    update: false
  )
}
````

#### Update objects in transaction

````swift
func update(user: User) throws {
  try DB.user().update(user) {
    $0.firstName = "Tony"
    $0.lastName = "Stark"
  }
}
    
func update(event: Event, newDate: Date) throws {
  try DB.event().update(event) {
    $0.date = newDate
  }
}
````

#### Sync fetch operations

````swift
let users = DB.user().objects { query in
   query.add { $0.firstName.isEqual("Robert") }
        .and { $0.events.count().isGreater(thanOrEqual: 5) }
        .and(\.updatedAt.isNotNil)
}.get()

let user = DB.user().object(by: Identifier(value: "user_id"))

let lastEvent = DB.event().last()
let allEvents = DB.event().all().get()
````


#### Async fetch operations

````swift
DB.event().first { event in
  if event != nil {
    // do actions
  }
}
        
DB.event().objects(matching: { query in
  query.add { $0.members.count() > 1000 }
  query.sort(by: { $0.date.ascending() })
}, completion: { operation in
  let events = operation.get()
  
  // do some actions
  for event in events {
    print(event.description)
  }
})
````

#### Create own read operations

````swift
final class ReadCurrentSubscriptionsDatabaseOperation: ReadObjectsDatabaseOperation<Subscription> {
  init(shouldThreadSafe isThreadSafe: Bool = false) {
    super.init(matching: { query in
      query.add(\.hasExpired.isFalse)
      query.sort(by: { $0.expiresAt.descending() })
    }, shouldThreadSafe: isThreadSafe)
  }
}

extension SubscriptionPersistence { 
  func current() -> [Subscription] { 
    ReadCurrentSubscriptionsDatabaseOperation().get()
  }
}

let currentSubscriptions = DB.subscription().current()

// or 

let currentSubscriptions = DB.subscription().objects(matching: { query in
  query.add(\.hasExpired.isFalse)
  query.sort(by: { $0.expiresAt.descending() })
}).get()
````


## Contribution

⭐️ If you like what you see, star us on GitHub.

Find a bug, a typo, or something that’s not documented well? We’d love for you to open an issue telling me what I can improve!

Contributions are welcome, and they are greatly appreciated!


## License

This code is distributed under the MIT license. See the  `LICENSE`  file for more info.
