import Handlebars
import Foundation
import PointFreeHTML
import HTMLTypesFoundation

@main
struct BlueMain {
    static func main() throws {
        print("Hello, world")
        
        let output_dir = URL(fileURLWithPath: #filePath)
            .appendingPathComponent("../../../")
            .appending(components: "site")
            .standardized

        let output = URL(fileURLWithPath: #filePath)
            .appendingPathComponent("../../../")
            .appending(components: "site", "index.html")
            .standardized
        
//        return try String(Greeting(name: name))

        // Render the page
//        let page = WelcomePage(userName: "Alice")
        
        let site = Site {
            WelcomePage(userName: "Alice")
                .page(name: "index")
        }
        try site.save(to: output_dir)
        
//        let html = try String(page)
//        try html.write(to: output, atomically: true, encoding: .utf8)

//        let html = Data(site().render())
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
    
    func save(to dir: URL) throws {
        let eng = RuleEngine(scope: SiteEnvironment(root: dir))
        let out = try eng.resolveBody(body)
        print(out)
    }

}

class SiteEnvironment {
    var root: URL
    var stack: [String:Any]
    
    init(root: URL, stack: [String : Any] = [:]) {
        self.root = root
        self.stack = stack
    }
    
    subscript<M>(_ key: String, as t: M.Type = M.self) -> M? {
        get { stack[key] as? M }
        set { stack[key] = newValue }
    }
    
    func output(html: any HTML, to file: String) throws {
        let str = try String(html)
        let fout = root.appendingPathComponent(file + ".html")
        try str.write(to: fout, atomically: true, encoding: .utf8)
    }
}

extension HTML {
    func page(name: String) -> some Rule {
        ScopeModifier {
            HTMLRule(html: self)
        } modifier: {
            $0["page"] = name
        }
    }
}

extension RuleBuilder {
    static func buildExpression<H: HTML>(_ expression: H) -> some Rule {
        HTMLRule(html: expression)
    }
}

struct ModifiedRule<Content: Rule>: Builtin {
    typealias Scope = SiteEnvironment
    @RuleBuilder var content: () -> Content
    
    init(content: @escaping () -> Content) {
        self.content = content
    }
    
    func resolve(in env: Scope) throws {
        let content = self.content()
    }
}

struct ScopeModifier<Content: Rule>: Rule {
    typealias Scope = SiteEnvironment
    var modifier: (inout SiteEnvironment) -> Void
    @RuleBuilder var content: () -> Content
    
init(
        @RuleBuilder content: @escaping () -> Content,
        modifier: @escaping (inout SiteEnvironment) -> Void
    ) {
        self.content = content
        self.modifier = modifier
    }
    
    var body: some Rule {
        content()
    }
    func resolve(in env: Scope) throws {
        var cp = env
        modifier(&cp)
        content().resolve(in: cp)
    }
}

struct HTMLRule: Builtin {
    typealias Scope = SiteEnvironment
    var html: any HTML
    
    init(html: any HTML) {
        self.html = html
    }
    
    func resolve(in env: Scope) throws {
        guard let page: String = env["page"]
        else { throw BuildError("No page name set") }
        try env.output(html: html, to: page)
    }
}

struct BuildError: Error {
    var msg: String
    var file: String
    var line: Int
    
    fileprivate init(_ msg: String, file: String = #file, line: Int = #line) {
        self.msg = msg
        self.file = file
        self.line = line
    }
}

//struct WriteHTML<Content: Rule>: Builtin {
//    typealias Scope = HTML
//    @RuleBuilder var content: () -> Content
//    
//    init(content: @escaping () -> Content) {
//        self.content = content
//    }
//        
//    func resolve(in: any Scope) throws {
//        
//    }
//}
