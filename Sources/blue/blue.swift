import Handlebars
import Foundation
//import PointFreeHTML
//import HTMLTypesFoundation

@main
struct BlueMain {
    static func main() async throws {
        try await createExampleSite()
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
