import Handlebars
import Foundation
//import PointFreeHTML
//import HTMLTypesFoundation

@main
struct BlueMain {
    static func main() async throws {
        print("Hello, world")
        
        let output_dir = URL(fileURLWithPath: #filePath)
            .appendingPathComponent("../../../")
            .appending(components: "site")
            .standardized

        let output = URL(fileURLWithPath: #filePath)
            .appendingPathComponent("../../../")
            .appending(components: "site", "index.html")
            .standardized
        
        try await createExampleSite()

//        return try String(Greeting(name: name))

        // Render the page
//        let page = WelcomePage(userName: "Alice")
        
        let site = Site {
            "Okay"
            WelcomePage(userName: "Alice")
//                .page(name: "index")
        }
        try site.builtin.run(environment: .init())
//        try site.save(to: output_dir)
        
//        let html = try String(page)
//        try html.write(to: output, atomically: true, encoding: .utf8)

//        let html = Data(site().render())
    }
}
extension RuleBuilder {
    static func buildExpression(_ expression: String) -> RuleCollection {
        RuleArray(elements: [])
//        HTMLRule(html: expression)
    }
}

struct Site<Content: Rule>: Rule {
    @RuleBuilder var content: () -> Content
    
    init(@RuleBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    var body: some Rule {
        content()
    }
    
//    func save(to dir: URL) throws {
//        let eng = RuleEngine(scope: SiteEnvironment(root: dir))
//        let out = try eng.resolveBody(body)
//        print(out)
//    }

}

extension RuleBuilder {
    static func buildExpression<H: HTML>(_ expression: H) -> some Rule {
        HTMLRule(html: expression)
    }
}

struct HTMLRule: Builtin {
    func run(environment: EnvironmentValues) throws {
        let str = html.render()
        print(str)
    }
    
//    typealias Scope = SiteEnvironment
    var html: any HTML

    init(html: any HTML) {
        self.html = html
    }

}
