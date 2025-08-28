import Handlebars
import Foundation
import PointFreeHTML
import HTMLTypesFoundation

@main
struct BlueMain {
    static func main() throws {
        print("Hello, world")
        
        let output = URL(fileURLWithPath: #filePath)
            .appendingPathComponent("../../../")
            .appending(components: "site", "index.html")
            .standardized
        
//        return try String(Greeting(name: name))

        // Render the page
        let page = WelcomePage(userName: "Alice")
        let html = try String(page)
        try html.write(to: output, atomically: true, encoding: .utf8)

//        let html = Data(site().render())
    }
}

// struct MyDocument: HTMLDocument {
//     var head: some HTML {
//         title { "My Web Page" }
//         meta().charset("utf-8")
//         meta().name("viewport").content("width=device-width, initial-scale=1")
//     }
//
//     var body: some HTML {
//         div {
//             h1 { "Welcome to My Website" }
//             p { "This is a complete HTML document." }
//         }
//     }
// }

struct TestHTML: HTML {
    var body: some HTML {
        HTMLText("test content")
//            .inlineStyle("color", "white", media: .dark)
    }
}

//struct Greeting: HTML {
//    let name: String
//    var body: some HTML {
//        h1 { "Hello, \(name)!" }
//    }
//}


//import Html

//let document: Node = .document(
//    .html(
//        .body(
//            .h1("Welcome!"),
//            .p("You’ve found our site!")
//        )
//    )
//)

// Type-safe HTML with SwiftUI-like syntax

//struct Button: HTML {
//    let title: String
//    let action: String
//    
//    var body: some HTML {
//        a(href: action) { title }
//            .display(.inlineBlock)
//            .padding(.vertical(.rem(0.5)), .horizontal(.rem(1)))
//            .backgroundColor(.blue)
//            .color(.white)
//            .borderRadius(.px(6))
//            .textDecoration(.none)
//            .transition(.all, duration: .ms(150))
//    }
//}

// Use it anywhere
//@HTMLBuilder
//func site() -> some HTML {
//    HTMLDocument {
//        div {
//            h1 { "Welcome to swift-html" }
//                .color(.red)
//                .fontSize(.rem(2.5))
//            
//            p { "Build beautiful, type-safe web pages with Swift" }
//                .color(light: .gray800, dark: .gray200)
//                .lineHeight(1.6)
//                       
//            div {
//                header { "Mobile First" }
//                nav { "Navigation" }
//                main { "Content" }
//            }
//            .display(.grid)
////            .gridTemplateColumns(.fr(1))
//            .gap(.rem(1))
//            
////            Button(title: "Learn More", action: "/docs")
//
//            div { "Styled content" }
//                .padding(.rem(2))                    // Type-safe units
////                .backgroundColor(.systemBackground)   // Semantic colors
//                .borderRadius(.px(8))                // Multiple unit types
////                .boxShadow
//            
////            .padding(.rem(1))
////            .backgroundColor(.yellow)
////            .color(.blue)
////            .borderRadius(.px(8))
////            .textDecoration(TextDecoration.none)
//        }
//        .padding(.rem(2))
//        .maxWidth(.px(800))
//        .margin(.auto)
//    } head: {
//        title { "swift-html - Type-safe HTML in Swift" }
//        meta(charset: .utf8)()
//        meta(name: .viewport, content: "width=device-width, initial-scale=1")()
//    }
//}
//
