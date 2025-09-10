//
//  WelcomePage.swift
//  Blueprints
//
//  Created by Jason Jobe on 8/27/25.
//

import Foundation

public protocol HTML: Rule {
    func render() -> String
}

typealias HTMLBuilder = RuleBuilder
extension RuleArray: HTML {
    public func render() -> String {
        // FIXME:
        ""
    }
}

struct HxToken: Sendable, Hashable, Equatable {
    var name: String
    init(_ tag: String) {
        self.name = tag
    }
}

extension HxToken {
    static let viewport: HxToken = "viewport"
    static let stylesheet: HxToken = "stylesheet"
    static let href: HxToken = "href"
}

extension HxToken: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        name = value
    }
}

let meta: HTMLRaw = "meta"
let link: HTMLRaw = "link"

let a: HTMLRaw = "link"
let nav: HTMLRaw = "nav"

let h1: HTMLRaw = "h1"
let h2: HTMLRaw = "h2"
let h3: HTMLRaw = "h3"
let p: HTMLRaw = "p"
let div: HTMLRaw = "div"

let main: HTMLRaw = "main"
let header: HTMLRaw = "header"
let footer: HTMLRaw = "footer"

let section: HTMLRaw = "section"
let article: HTMLRaw = "article"
let aside: HTMLRaw = "aside"

extension String: HTML {
    public func render() -> String {
        self
    }
}

// Removed extension HTMLRaw with callAsFunction overloads to avoid ambiguity

func tester() {
    let _ = "asff".data(using: .utf8)
    let tag: HTMLRaw = "fpp"
    _ = tag.render()
    _ = StyleHTML(href: "site.css").render()
}

@dynamicCallable
struct HTMLRaw: HTML {
    
    var tag: String
    init(_ tag: String) {
        self.tag = tag
    }
    
    func render() -> String { tag }
    
    func dynamicallyCall(withKeywordArguments: KeyValuePairs<String,Any>) -> some HTML {
        self
    }
}

@HTMLBuilder
var bob: some HTML {
    hx(foo: 23) {
        "okay"
    }
}

extension HTML {
    @discardableResult
    func `class`(_ cls: Class) -> Self {
        self
    }
}

extension HTMLRaw: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        tag = value
    }
}

public struct Class: Sendable, ExpressibleByStringLiteral, CustomStringConvertible, Hashable, Equatable {
    public var rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    public init(stringLiteral value: StringLiteralType) {
        rawValue = value
    }
    public var description: String { rawValue }
}


public extension Class {
    static let brand: Class = "brand"
    static let grow: Class = "grow"
    static let nav: Class = "nav"
    static let pill: Class = "pill"
    
    static let hero: Class = "hero"
    static let card: Class = "card"
    static let grid: Class = "grid"
    static let container: Class = "container"
}

struct StyleHTML: HTML {
    var href: String = "style.css"
    func render() -> String {
        HTMLRaw(#"<link rel=\"stylesheet\" href=\"\#(href)\">"#).render()
    }
}

let hx: HTMLRaw = "hx"

struct WelcomePage: Rule {
    let userName: String
    
    @HTMLBuilder
    var head: some HTML {
        HTMLRaw("<meta charset=\"utf-8\">")
        HTMLRaw("<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">")
        HTMLRaw("<link rel=\"stylesheet\" href=\"site.css\">")
    }
    
    var body: some Rule {
        header {
            nav {
                a(href: "/") { "Blueprints" }
                    .class(.brand)
                div { }
                    .class(.grow)
                nav {
                    a(href: "/about") { "About" }
                        .class(.pill)
                    a(href: "/contact") { "Contact" }
                        .class(.pill)
                }
            }
            .class(.nav)
        }
        
        div { // container
            main {
                section { // hero
                    h1 { "Welcome, \(userName)!" }
                    p { "Build fast. Ship clean. Iterate in public." }
                }
                .class(.hero)
                
                section { // content grid
                    article { h3 { "Docs" }; p { "Guides, patterns, and reference." } }
                        .class(.card)
                    article { h3 { "Components" }; p { "Reusable building blocks." } }
                        .class(.card)
                    article { h3 { "Templates" }; p { "Jumpstart new modules." } }
                        .class(.card)
                    article { h3 { "Changelog" }; p { "What’s new and improved." } }
                        .class(.card)
                    article { h3 { "Playgrounds" }; p { "Interactive examples." } }
                        .class(.card)
                    article { h3 { "Roadmap" }; p { "What’s next." } }
                        .class(.card)
                }
                .class(.grid)

                aside {
                    div { "Tip: Use ⌘K to search anything." }
                        .class("well")
                    div { "You’re signed in as \(userName)." }
                        .class("well")
                }
            }
            .class(.container)
        }
        
        footer {
            div {
                p { "© \(Calendar.current.component(.year, from: Date())) Blueprints. All rights reserved." }
            }
            .class("container")
        }
    }

}

