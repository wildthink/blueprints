//
//  SiteBuilder.swift
//  Blueprints
//
//  A comprehensive site building system using TALEngine
//  with template inheritance, custom modifiers, and asset management.
//

import Foundation

// MARK: - TAL Sendable Context

public protocol XtValue: Sendable {}
extension String: XtValue {}
extension Int: XtValue {}
extension Double: XtValue {}
extension Bool: XtValue {}
extension Optional: XtValue where Wrapped: XtValue {}
extension Array: XtValue where Element: XtValue {}
extension Dictionary: XtValue where Key == String, Value == any XtValue {}

//public typealias XtContext = [String: XtValue]

public struct XtContext: Sendable, ExpressibleByDictionaryLiteral {
    
    var values: [String: XtValue] = [:]
    
    public init(dictionaryLiteral elements: (String, any XtValue)...) {
        values = Dictionary(uniqueKeysWithValues: elements)
    }

//    public init(dictionaryLiteral elements: (String, Any)...) {
//    }

    @_disfavoredOverload
    subscript(key: String) -> [String : XtValue]? {
        get { values[key] as? [String : XtValue] }
        set { values[key] = newValue }
    }

    subscript(key: String) -> (any XtValue)? {
        get { values[key] }
        set { values[key] = newValue }
    }

//    var pageInfo:
    subscript<V: XtValue>(key: String) -> V? {
        get { values[key] as? V }
        set { values[key] = newValue }
    }
    
    func mapValues<T>(_ transform: (any XtValue) throws -> T) rethrows -> Dictionary<String, T> {
        try values.mapValues(transform)
    }
    
    func toAnyDictionary() -> [String:Any] {
        values.toAnyDictionary()
    }
}

extension XtContext: Sequence {
    public func makeIterator() -> Dictionary<String, any XtValue>.Iterator {
        values.makeIterator()
    }
}

// Helpers to bridge XtContext -> [String: Any] safely within an actor
//fileprivate func talToAny(_ value: XtValue) -> Any {
//    switch value {
//        case let v as String: return v
//        case let v as Int: return v
//        case let v as Double: return v
//        case let v as Bool: return v
//            // jmj
////        case let v:
////            return v.mapValues { talToAny($0) }
//        case let v as [XtValue]:
//            return v.map { talToAny($0) }
//        case Optional<Any>.none:
//            return NSNull()
//        default:
//            // Fallback: stringify unknown XtValue-conforming types
//            return String(describing: value)
//    }
//}

fileprivate extension Dictionary where Key == String, Value == XtValue {
    func toAnyDictionary() -> [String: Any] {
        var out: [String: Any] = [:]
        for (k, v) in self { out[k] = v }
        return out
    }
}

// MARK: - Site Configuration
let file_dir: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent() // blue
    .standardizedFileURL

var project_dir: URL { file_dir
    .deletingLastPathComponent() // Sources
    .deletingLastPathComponent() // Project
    .standardizedFileURL
}

public struct SiteConfig: @unchecked Sendable {
    public let name: String
    public let baseURL: String
    public let templatesPath: String
    public let outputPath: String
    public let assetsPath: String?
    public let defaultContext: XtContext
    public let prettyPrintHTML: Bool

    public init(
        name: String,
        baseURL: String = "https://localhost:8080",
        templatesPath: String = "Resources/templates",
        outputPath: String = "deploy",
        assetsPath: String? = "Resources/assets",
        defaultContext: XtContext = [:],
        prettyPrintHTML: Bool = false
    ) {
        self.name = name
        self.baseURL = baseURL
        self.defaultContext = defaultContext
        self.prettyPrintHTML = prettyPrintHTML
        // FIXME: jmj
        self.templatesPath = project_dir
            .appending(path: templatesPath)
            .standardizedFileURL.path
        self.outputPath = project_dir
            .appending(path: outputPath)
            .standardizedFileURL.path
        self.assetsPath = project_dir
            .appending(path: assetsPath ?? "")
            .standardizedFileURL.path
    }
}

// MARK: - Page Definition

public struct Page: @unchecked Sendable {
    public let path: String
    public let template: String
    public let context: XtContext
    public let outputPath: String?
    
    public init(
        path: String,
        template: String,
        context: [String:Any] = [:],
        outputPath: String? = nil
    ) {
        self.path = path
        self.template = template
        self.context = [:] // jmj context
        self.outputPath = outputPath
    }

    public init(
        path: String,
        template: String,
        context: XtContext = [:],
        outputPath: String? = nil
    ) {
        self.path = path
        self.template = template
        self.context = context
        self.outputPath = outputPath
    }
}

// MARK: - Engine Adapter (Actor)
public actor TALEngineActor {
    private let engine: TALEngineXML
    public init(resolver: @escaping (String) -> String?) {
        self.engine = TALEngineXML(resolver)
    }
//    nonisolated
    public func renderAsync(template: String, context: XtContext) async throws -> String {
        // Bridge to [String: Any] *inside* this actor to avoid crossing with non-Sendable payloads
        let anyContext = context.toAnyDictionary()
        return try engine.render(template: template, context: anyContext, prettyPrint: config.prettyPrintHTML)
//        return try await engine.renderAsync(template: template, context: anyContext)
    }
}

// MARK: - Site Builder

public actor SiteBuilder {
    private let config: SiteConfig
    private let engine: TALEngineActor
    private var pages: [Page] = []
    private var globalContext: XtContext = [:]
    
    public init(config: SiteConfig) {
        self.config = config
        
        // Setup template resolver
        self.engine = TALEngineActor { [config] templateName in
            let fullPath = "\(config.templatesPath)/\(templateName)"
            return try? String(contentsOfFile: fullPath, encoding: .utf8)
        }
        
        // Initialize global context
        self.globalContext = config.defaultContext
        self.globalContext["site"] = [
            "name": config.name,
            "url": config.baseURL,
            "buildTime": ISO8601DateFormatter().string(from: Date())
        ]
        
        Task {
            await self.setupDefaultModifiers()
        }
    }
    
    // MARK: - Setup
    
    private func setupDefaultModifiers() async {
        let registry = OutputModifierRegistry.shared
        
        // Date formatting
        await registry.register(name: "date") { text in
            guard let timestamp = Double(text) else { return text }
            let date = Date(timeIntervalSince1970: timestamp)
            return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
        }
        
        // Simple template substitution
        await registry.register(name: "template") { text in
            var result = text
            // Replace ${variable} patterns
            let pattern = #"\$\{([^}]+)\}"#
            let regex = try! NSRegularExpression(pattern: pattern, options: [])
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
            
            for match in matches.reversed() {
                if let range = Range(match.range, in: text) {
                    let placeholder = String(text[range])
                    // For now, just remove the placeholder syntax
                    result = result.replacingOccurrences(of: placeholder, with: "")
                }
            }
            return result
        }
        
        // Currency formatting
        await registry.register(name: "currency") { text in
            guard let value = Double(text) else { return text }
            return NumberFormatter.currency.string(from: NSNumber(value: value)) ?? text
        }
        
        // Percentage formatting
        await registry.register(name: "percentage") { text in
            guard let value = Double(text) else { return text }
            return NumberFormatter.percent.string(from: NSNumber(value: value)) ?? text
        }
        
        // Truncate text
        await registry.register(name: "truncate") { text in
            let maxLength = 100 // Could be parameterized
            return text.count > maxLength ? String(text.prefix(maxLength)) + "..." : text
        }
        
        // Slug generation
        await registry.register(name: "slug") { text in
            return text.lowercased()
                .replacingOccurrences(of: #"[^a-z0-9\s-]"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"\s+"#, with: "-", options: .regularExpression)
                .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        }
        
        // Markdown to HTML (basic implementation)
        await registry.register(name: "markdown", isRaw: true) { text in
            var html = text
            // Basic markdown patterns
            html = html.replacingOccurrences(of: #"\*\*(.*?)\*\*"#, with: "<strong>$1</strong>", options: .regularExpression)
            html = html.replacingOccurrences(of: #"\*(.*?)\*"#, with: "<em>$1</em>", options: .regularExpression)
            html = html.replacingOccurrences(of: #"\[(.*?)\]\((.*?)\)"#, with: "<a href=\"$2\">$1</a>", options: .regularExpression)
            html = html.replacingOccurrences(of: "\n\n", with: "</p><p>")
            return "<p>\(html)</p>"
        }
    }
    
    // MARK: - Page Management
    
    public func addPage(_ page: Page) {
        pages.append(page)
    }
    
    public func addPages(_ newPages: [Page]) {
        pages.append(contentsOf: newPages)
    }
    
    public func setGlobalContext(_ key: String, value: some XtValue) {
        globalContext[key] = value
    }
    
    @_disfavoredOverload
    public func updateGlobalContext(_ updates: [String:Any]) {
        for (key, value) in updates {
            if let xtValue = value as? (any XtValue) {
                globalContext[key] = xtValue
            }
        }
    }

    @_disfavoredOverload
    public func updateGlobalContext(_ updates: [String:any XtValue]) {
        for (key, value) in updates {
            globalContext[key] = value
        }
    }

    public func updateGlobalContext(_ updates: XtContext) {
        for (key, value) in updates {
            globalContext[key] = value
        }
    }
    
    // MARK: - Building
    
    public func build() async throws {
        print("🏗️  Building site: \(config.name)")
        
        // Create output directory
        try createOutputDirectory()
        
        // Build pages
        var successCount = 0
        var errorCount = 0
        
        for page in pages {
            do {
                try await buildPage(page)
                successCount += 1
                print("✅ Built: \(page.path)")
            } catch {
                errorCount += 1
                print("❌ Failed to build \(page.path): \(error)")
            }
        }
        
        // Copy assets if configured
        if let assetsPath = config.assetsPath {
            try copyAssets(from: assetsPath)
        }
        
        print("🎉 Build complete: \(successCount) pages built, \(errorCount) errors")
    }
    
    private func buildPage(_ page: Page) async throws {
        // Merge contexts
        var pageContext: XtContext = globalContext
        for (key, value) in page.context {
            pageContext[key] = value
        }
        
        // Add page-specific context
        let existingPageInfo = (pageContext["page"]) ?? [:]
        var pageInfo: [String: XtValue] = existingPageInfo as! [String : any XtValue]
        pageInfo["path"] = page.path
        pageInfo["template"] = page.template
        pageContext["page"] = pageInfo
        
        // Render the page
        let html = try await engine.renderAsync(template: page.template, context: pageContext, prettyPrint: config.prettyPrintHTML)
        
        // Determine output path
        let outputPath = page.outputPath ?? page.path
        let fullOutputPath = "\(config.outputPath)/\(outputPath)"
        
        // Ensure output directory exists
        let outputDir = URL(fileURLWithPath: fullOutputPath).deletingLastPathComponent().path
        try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true, attributes: nil)
        
        // Write the file
        try html.write(toFile: fullOutputPath, atomically: true, encoding: .utf8)
    }
    
    private func createOutputDirectory() throws {
        let fileManager = FileManager.default
        
        if fileManager.fileExists(atPath: config.outputPath) {
            try fileManager.removeItem(atPath: config.outputPath)
        }
        
        try fileManager.createDirectory(atPath: config.outputPath, withIntermediateDirectories: true, attributes: nil)
    }
    
    private func copyAssets(from assetsPath: String) throws {
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: assetsPath) else {
            print("⚠️  Assets directory not found: \(assetsPath)")
            return
        }
        
        let outputAssetsPath = "\(config.outputPath)/assets"
        
        if fileManager.fileExists(atPath: outputAssetsPath) {
            try fileManager.removeItem(atPath: outputAssetsPath)
        }
        
        try fileManager.copyItem(atPath: assetsPath, toPath: outputAssetsPath)
        print("📁 Copied assets to: \(outputAssetsPath)")
    }
    
    // MARK: - Development Server
    
    public func serve(port: Int = 8080) async throws {
        print("🚀 Starting development server on port \(port)")
        print("📝 Templates will be rebuilt on request")
        
        // This would integrate with a web server framework
        // For now, just demonstrate the concept
        print("Server would be running at: http://localhost:\(port)")
        print("Use Ctrl+C to stop the server")
        
        // Keep the server running
        try await Task.sleep(for: .seconds(3600)) // 1 hour timeout for demo
    }
    
    // MARK: - Convenience Methods
    
    public func buildSinglePage(template: String, context: XtContext = [:]) async throws -> String {
        var pageContext = globalContext
        for (key, value) in context { pageContext[key] = value }
        return try await engine.renderAsync(template: template, context: pageContext, prettyPrint: config.prettyPrintHTML)
    }
}

// MARK: - Site Builder Extensions

public extension SiteBuilder {
    /// Create a SiteBuilder by scanning the current project (Smart Path Resolution)
    static func autoConfigured(name: String? = nil) async throws -> SiteBuilder {
        let scanner = ProjectScanner()
        return try await scanner.createSiteBuilder(name: name)
    }

    /// Create a SiteBuilder with pretty-printed HTML output
    static func autoConfiguredPretty(name: String? = nil) async throws -> SiteBuilder {
        let scanner = ProjectScanner()
        var builder = try await scanner.createSiteBuilder(name: name)

        // Update config to enable pretty printing
        let prettyConfig = SiteConfig(
            name: builder.config.name,
            baseURL: builder.config.baseURL,
            templatesPath: builder.config.templatesPath,
            outputPath: builder.config.outputPath,
            assetsPath: builder.config.assetsPath,
            defaultContext: builder.config.defaultContext,
            prettyPrintHTML: true
        )
        builder = SiteBuilder(config: prettyConfig)
        return builder
    }

    // MARK: - Template Patterns (Option 5)

    /// Quick setup for blog sites
    static func blog(name: String) async throws -> SiteBuilder {
        let scanner = ProjectScanner()
        let builder = try await scanner.createSiteBuilder(name: name)

        // Add blog-specific pages
        await builder.addPages([
            Page(path: "index.html", template: "pages/index.html", context: [:]),
            Page(path: "blog.html", template: "pages/blog.html", context: [:]),
            Page(path: "post.html", template: "pages/post.html", context: [:]),
            Page(path: "about.html", template: "pages/about.html", context: [:]),
            Page(path: "contact.html", template: "pages/contact.html", context: [:])
        ])

        await builder.updateGlobalContext([
            "nav": [
                "home": "Home",
                "blog": "Blog",
                "about": "About",
                "contact": "Contact"
            ],
            "site_type": "blog"
        ] as XtContext)

        return builder
    }

    /// Quick setup for portfolio sites
    static func portfolio(name: String) async throws -> SiteBuilder {
        let scanner = ProjectScanner()
        let builder = try await scanner.createSiteBuilder(name: name)

        await builder.addPages([
            Page(path: "index.html", template: "pages/index.html", context: [:]),
            Page(path: "portfolio.html", template: "pages/portfolio.html", context: [:]),
            Page(path: "about.html", template: "pages/about.html", context: [:]),
            Page(path: "contact.html", template: "pages/contact.html", context: [:])
        ])

        await builder.updateGlobalContext([
            "nav": [
                "home": "Home",
                "work": "Portfolio",
                "about": "About",
                "contact": "Contact"
            ],
            "site_type": "portfolio"
        ] as XtContext)

        return builder
    }

    /// Quick setup for business/company sites
    static func business(name: String) async throws -> SiteBuilder {
        let scanner = ProjectScanner()
        let builder = try await scanner.createSiteBuilder(name: name)

        await builder.addStandardPages()
        await builder.addPages([
            Page(path: "services.html", template: "pages/services.html", context: [:]),
            Page(path: "pricing.html", template: "pages/pricing.html", context: [:])
        ])

        await builder.updateGlobalContext([
            "nav": [
                "home": "Home",
                "services": "Services",
                "pricing": "Pricing",
                "about": "About",
                "contact": "Contact"
            ],
            "site_type": "business"
        ] as XtContext)

        return builder
    }
    
    /// Quick setup for common site structures
    static func createStandardSite(name: String, baseURL: String = "https://localhost:8080") async -> SiteBuilder {
        let config = SiteConfig(
            name: name,
            baseURL: baseURL,
            defaultContext: [
                "nav": [
                    "home": "Home",
                    "about": "About",
                    "contact": "Contact"
                ],
                "footer": [
                    "copyright": "© \(Calendar.current.component(.year, from: Date())) \(name). All rights reserved."
                ]
            ]
        )
        
        return SiteBuilder(config: config)
    }
    
    /// Add common pages for a standard website
    func addStandardPages() {
        let standardPages = [
            Page(path: "index.html", template: "pages/index.html", context: [
                "page": ["title": "\(config.name) - Home"]
            ] as XtContext),
            Page(path: "about.html", template: "pages/about.html", context: [
                "page": ["title": "About - \(config.name)"]
            ] as XtContext),
            Page(path: "contact.html", template: "pages/contact.html", context: [
                "page": ["title": "Contact - \(config.name)"]
            ] as XtContext),
            Page(path: "login.html", template: "pages/login.html", context: [
                "page": ["title": "Login - \(config.name)"]
            ] as XtContext),
            Page(path: "signup.html", template: "pages/signup.html", context: [
                "page": ["title": "Sign Up - \(config.name)"]
            ] as XtContext)
        ]
        
        addPages(standardPages)
    }
}

// MARK: - Formatters

extension NumberFormatter {
    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter
    }()
    
    static let percent: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        return formatter
    }()
}

// MARK: - Example Usage

public func createExampleSite() async throws {
    // Option 1: Completely automatic discovery (Smart Path Resolution + Auto-Discovery)
    let autoSite = try await SiteBuilder.autoConfigured(name: "3rd Space")
    try await autoSite.build()

    print("\n" + String(repeating: "=", count: 50))
    print("✨ Successfully built site using auto-configuration!")
    print("📁 Templates discovered automatically from Resources/templates")
    print("🚀 Output written to deploy/ directory")
    print("🔍 Context loaded from Resources/sample-context.json")
    print(String(repeating: "=", count: 50))
}
