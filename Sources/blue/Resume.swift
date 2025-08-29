// This file was generated from JSON Schema using quicktype
// To parse the JSON, add this file to your project and do:
//
//   let resume = try? JSONDecoder().decode(Resume.self, from: jsonData)
// https://jsonresume.org/schema

import Foundation

public typealias Model = Codable & Sendable & Identifiable & Hashable & Equatable

// MARK: - Resume
public struct Resume: Model {
    public var profileID: Int64
    public var id: Int64 { profileID }
    public var basics: Persona
    public var work, volunteer: [Volunteer]
    public var education: [Education]
    public var awards: [Award]
    public var certificates: [Certificate]
    public var publications: [Publication]
    public var skills: [Skill]
    public var languages: [Language]
    public var interests: [Interest]
    public var references: [Reference]
    public var projects: [Project]
}

// MARK: - Award
public struct Award: Model {
    public var profileID: Int64
    public var id: Int64 { profileID }
    public var title: String
    public var date: Date
    public var awarder: String
    public var summary: String
}

// MARK: - Persona
public struct Persona: Model {
    public var id: Int64
    public var accountID: Int64
    public var name: Name
    public var role: String
    public var image: URL?
    public var email: Email
    public var phone: Phone
    public var url: URL?
    public var summary: String
    public var location: Location
}

// MARK: - Location
public struct Location: Model {
    public var profileID: Int64
    public var id: Int64 { profileID }
    public var address: String
    public var postalCode: String
    public var city: String
    public var countryCode: String
    public var region: String
}


// MARK: - Certificate
public struct Certificate: Model {
    public var profileID: Int64
    public var id: Int64 { profileID }
    public var name: String
    public var date: Date
    public var issuer: String
    public var url: URL?
}

// MARK: - Interest
public struct Interest: Model {
    public var profileID: Int64
    public var id: Int64 { profileID }
    public var name: String
    public var keywords: [String]
}

// MARK: - Language
public struct Language: Model {
    public var profileID: Int64
    public var id: Int64 { profileID }
    public var language: String
    public var fluency: String
}

// MARK: - Publication
public struct Publication: Model {
    public var profileID: Int64
    public var id: Int64 { profileID }
    public var name: String
    public var publisher: String
    public var releaseDate: Date
    public var url: URL?
    public var summary: String
}

// MARK: - Reference
public struct Reference: Model {
    public var profileID: Int64
    public var id: Int64 { profileID }
    public var name: String
    public var reference: String
}

// MARK: - Skill
public struct Skill: Model {
    public var profileID: Int64
    public var id: Int64 { profileID }
    public var name: String
    public var level: String
    public var keywords: [String]
}

// MARK: - Volunteer
// Experience
public struct Volunteer: Model {
    // Who
    public var profileID: Int64
    public var id: Int64 { profileID }
    // Where: Domain / Space
    public var organization: String?
    // Role
    public var position: String
    public var url: URL?
    // When: timeframe
    public var dateInterval: DateInterval?
    // What: activity / expierence
    public var summary: String
    public var highlights: [String]
    public var name: String?
}

// MARK: - Project
public struct Project: Model {
    public var profileID: Int64
    public var id: Int64 { profileID }
    public var name: String
    public var dateInterval: DateInterval?
    public var description: String
    public var highlights: [String]
    public var url: URL?
}

// MARK: - Education - Milestone
public struct Education: Model {
    public var profileID: Int64
    public var id: Int64 { profileID }
    public var institution: String
    public var url: URL?
    public var area: String
    public var studyType: String
    public var dateInterval: DateInterval?
    public var score: String
    public var courses: [String]
}

extension RawRepresentable
where Self: Identifiable, ID == Int64, RawValue == String {
    public var id: Int64 { Int64(rawValue.hashValue) }
}

public struct Email: RawRepresentable, Model {
    public var rawValue: String
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct Phone: RawRepresentable, Model {
    public var rawValue: String
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct Name: RawRepresentable, Model {
    public var rawValue: String
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct Network: RawRepresentable, Model {
    public var rawValue: String
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}
