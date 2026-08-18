//
//  Models.swift
//  RealmStorageTests
//

import Foundation
import RealmSwift
@testable import RealmStorage

/// A model using the modern `@Persisted` syntax that v1's base classes made impossible.
final class User: Object, IdentifiableStorage {
    @Persisted(primaryKey: true) var id: String
    @Persisted var firstName: String
    @Persisted var lastName: String
    @Persisted var age: Int
    @Persisted var createdAt: Date
    @Persisted var updatedAt: Date?
    @Persisted var isActive: Bool
    @Persisted var events: List<Event>

    convenience init(
        id: String,
        firstName: String = "",
        lastName: String = "",
        age: Int = 0,
        createdAt: Date = Date(timeIntervalSince1970: 0),
        updatedAt: Date? = nil,
        isActive: Bool = true
    ) {
        self.init()
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.age = age
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isActive = isActive
    }
}

final class Event: Object, IdentifiableStorage {
    @Persisted(primaryKey: true) var id: String
    @Persisted var name: String
    @Persisted var date: Date?

    convenience init(id: String, name: String = "", date: Date? = nil) {
        self.init()
        self.id = id
        self.name = name
        self.date = date
    }
}

/// A model with a `UUID` primary key, proving identity is no longer `String`-only.
final class Device: Object, IdentifiableStorage {
    @Persisted(primaryKey: true) var id: UUID
    @Persisted var label: String

    convenience init(id: UUID, label: String = "") {
        self.init()
        self.id = id
        self.label = label
    }
}

enum TestModels {
    static let all: [Object.Type] = [User.self, Event.self, Device.self]
}
