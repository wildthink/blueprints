//
//  File.swift
//  Blueprints
//
//  Created by Jason Jobe on 8/28/25.
//

import Foundation

struct Account: Identifiable {
    var id: Int64
    var alias: String
    var login: String
    var password: String
    var hint: String?
    var memo: String?
}

//struct Persona: Identifiable {
//    var id: Int64
//    var account: Int64
//    var alias: String
//}

struct Article: Identifiable {
    var id: Int64
    var author: Int64 // Persona
    var title: String
    var subtile: String
    var href: String?
}

public typealias Timeframe = DateInterval

struct Experience: Identifiable {
    var id: Int64
    var venue: String? // Where did it happen
    var who: Int64 // Persona Who is having the experience
    var role: String // What "part" did "who" play?
    var what: String // What happened
    var when: Timeframe
    var milestones: [String]?
    var summary: String?
}

// MARK: Sample Data

