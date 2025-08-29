//
//  WelcomePage.swift
//  Blueprints
//
//  Created by Jason Jobe on 8/27/25.
//

import Foundation
import PointFreeHTML
import HTML

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
    
    var body: some HTML {
        HTMLRaw(#"<link rel="stylesheet" href="\#(href)">"#)
    }
}

struct WelcomePage: HTMLDocumentProtocol {
    let userName: String
    
    var head: some HTML {
        meta(charset: .utf8)
        meta(name: .viewport, content: "width=device-width, initial-scale=1")
        link(href: "site.css", rel: .stylesheet)
    }
    
    var body: some HTML {
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
                        .attribute("class", "well")
                    div { "You’re signed in as \(userName)." }
                        .attribute("class", "well")
                }
            }
            .class(.container)
        }
        
        footer {
            div {
                small { "© \(Calendar.current.component(.year, from: Date())) Blueprints. All rights reserved." }
            }
            .attribute("class", "container")
        }
    }

}
