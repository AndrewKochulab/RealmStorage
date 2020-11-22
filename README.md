# RealmStorage

Modern wrapper for Realm Database [iOS, macOS, tvOS &amp; watchOS]

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

### Example

#### Create Tables

````swift
import RealmSwift
import RealmStorage

final class User: IdentifiableStorageObject, PredicateSchema, StorageSchemaProvidable {
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

final class Event: IdentifiableStorageObject, PredicateSchema, StorageSchemaProvidable {
  dynamic var date: Date?
  dynamic var name = ""
  dynamic var author: User?
    
  let members = List<EventMember>()
}

final class EventMember: IdentifiableStorageObject, PredicateSchema, StorageSchemaProvidable {
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

## License

This code is distributed under the MIT license. See the  `LICENSE`  file for more info.
