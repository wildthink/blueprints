//
//  WelcomePage.swift
//  Blueprints
//
//  Created by Jason Jobe on 8/27/25.
//

import Foundation
import PointFreeHTML
import HTML

struct StyleHTML: HTML {
//    typealias Content = HTMLText
    var href: String = "style.css"
    
    var body: some HTML {
        //     <link rel="stylesheet" href="dist/css/style.css">
        HTMLRaw(#"<link rel="stylesheet" href="\#(href)">"#)
    }
    
//    static func _render(_ html: Self, into printer: inout HTMLPrinter) {
//    }
}

extension HTMLElementTypes.Style {
    public func callAsFunction(@StringBuilder _ content: () -> String) -> some HTML {
        style(media: media, blocking: blocking, nonce: nonce, title: title) {
            HTMLText(content())
        }
    }
}

struct WelcomePage: HTMLDocumentProtocol {
    let userName: String
    
    var head: some HTML {
        meta(charset: .utf8)
        meta(name: .viewport, content: "width=device-width, initial-scale=1")
        StyleHTML(href: "site.css")
    }
    
    var body: some HTML {
        header {
            div { // nav
                a(href: "/") { span { "Blueprints" } }
                    .attribute("class", "brand")
                div { }
                    .attribute("class", "grow")
                nav {
                    a(href: "/about") { span { "About" } }
                        .attribute("class", "pill")
                    a(href: "/contact") { span { "Contact" } }
                        .attribute("class", "pill")
                }
            }
            .attribute("class", "nav")
        }
        
        div { // container
            main {
                section { // hero
                    h1 { "Welcome, \(userName)!" }
                    p { "Build fast. Ship clean. Iterate in public." }
                }
                .attribute("class", "hero")
                
                section { // content grid
                    article { h3 { "Docs" }; p { "Guides, patterns, and reference." } }
                        .attribute("class", "card")
                    article { h3 { "Components" }; p { "Reusable building blocks." } }
                        .attribute("class", "card")
                    article { h3 { "Templates" }; p { "Jumpstart new modules." } }
                        .attribute("class", "card")
                    article { h3 { "Changelog" }; p { "What’s new and improved." } }
                        .attribute("class", "card")
                    article { h3 { "Playgrounds" }; p { "Interactive examples." } }
                        .attribute("class", "card")
                    article { h3 { "Roadmap" }; p { "What’s next." } }
                        .attribute("class", "card")
                }
                .attribute("class", "grid")
                
                aside {
                    div { "Tip: Use ⌘K to search anything." }
                        .attribute("class", "well")
                    div { "You’re signed in as \(userName)." }
                        .attribute("class", "well")
                }
            }
            .attribute("class", "container")
        }
        
        footer {
            div {
                small { "© \(Calendar.current.component(.year, from: Date())) Blueprints. All rights reserved." }
            }
            .attribute("class", "container")
        }
    }
    
}

/*
 meta(name: "style", content:
 """
 :root {
 --bg: #0b0c10;
 --surface: #111217;
 --text: #e6e6e6;
 --muted: #a0a0a0;
 --accent: #4f8cff;
 --accent-2: #7a5cff;
 --radius: 12px;
 --maxw: 1100px;
 }
 * { box-sizing: border-box; }
 html, body { height: 100%; }
 body {
 margin: 0; padding: 0; background: var(--bg); color: var(--text);
 font: -apple-system-body; font-family: -apple-system, system-ui, Segoe UI, Roboto, Helvetica, Arial, sans-serif;
 }
 a { color: var(--text); text-decoration: none; }
 a:hover { color: var(--accent); }
 
 header {
 position: sticky; top: 0; z-index: 10;
 backdrop-filter: saturate(180%) blur(12px);
 background: color-mix(in oklab, var(--surface) 85%, transparent);
 border-bottom: 1px solid #22252b;
 }
 .nav { max-width: var(--maxw); margin: 0 auto; padding: 12px 20px; display: flex; align-items: center; gap: 16px; }
 .nav .grow { flex: 1; }
 .brand { display: inline-flex; align-items: center; gap: 10px; font-weight: 600; }
 .pill { padding: 6px 12px; border: 1px solid #2a2d35; border-radius: 999px; background: #14161c; }
 
 .container { max-width: var(--maxw); margin: 0 auto; padding: 24px 20px; }
 main { display: grid; gap: 20px; grid-template-columns: 1fr; }
 .hero { padding: 20px; border: 1px solid #1b1e25; border-radius: var(--radius);
 background: linear-gradient(180deg, #151822, #111217); }
 .hero h1 { margin: 0 0 8px 0; font-size: clamp(22px, 4vw, 36px); }
 .hero p { margin: 0; color: var(--muted); }
 
 .grid { display: grid; gap: 16px; grid-template-columns: repeat(1, minmax(0, 1fr)); }
 .card { border: 1px solid #1b1e25; border-radius: var(--radius); padding: 16px; background: #0f1117; }
 .card h3 { margin: 0 0 6px 0; font-size: 16px; }
 .card p { margin: 0; color: var(--muted); }
 
 aside { display: grid; gap: 12px; }
 .well { border: 1px dashed #2a2d35; border-radius: var(--radius); padding: 14px; color: var(--muted); }
 
 footer { border-top: 1px solid #22252b; color: var(--muted); }
 footer .container { padding-top: 18px; padding-bottom: 18px; }
 
 @media (min-width: 720px) {
 main { grid-template-columns: 2fr 1fr; align-items: start; }
 .grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
 }
 @media (min-width: 1024px) {
 .grid { grid-template-columns: repeat(3, minmax(0, 1fr)); }
 }
 """
 )
 */
