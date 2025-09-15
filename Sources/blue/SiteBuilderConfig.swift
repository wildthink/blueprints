import Foundation

/// Simplified site builder configuration using conventions
public struct SiteBuilderConfig {
    public let name: String
    public let baseURL: String
    public let projectRoot: URL

    // Auto-computed paths based on conventions
    public var templatesDir: URL { projectRoot.appending(path: "Resources/templates") }
    public var pagesDir: URL { templatesDir.appending(path: "pages") }
    public var layoutsDir: URL { templatesDir.appending(path: "layouts") }
    public var assetsDir: URL { projectRoot.appending(path: "Resources/assets") }
    public var outputDir: URL { projectRoot.appending(path: "deploy") }
    public var contextFile: URL { projectRoot.appending(path: "Resources/sample-context.json") }

    public init(name: String, baseURL: String = "https://example.com", projectRoot: URL? = nil) {
        self.name = name
        self.baseURL = baseURL

        // Auto-detect project root if not provided
        if let projectRoot = projectRoot {
            self.projectRoot = projectRoot
        } else {
            // Walk up from current file to find Package.swift
            var current = URL(fileURLWithPath: #filePath)
            while current.path != "/" {
                current = current.deletingLastPathComponent()
                if FileManager.default.fileExists(atPath: current.appending(path: "Package.swift").path) {
                    self.projectRoot = current
                    return
                }
            }
            // Fallback to current directory
            self.projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        }
    }
}

/// Fluent builder for easy site configuration
public class EasySiteBuilder {
    private var config: SiteBuilderConfig
    private var pages: [String] = []
    private var globalContext: [String: Any] = [:]

    public init(name: String, baseURL: String = "https://example.com") {
        self.config = SiteBuilderConfig(name: name, baseURL: baseURL)
        setupDefaults()
    }

    private func setupDefaults() {
        // Set up reasonable defaults
        globalContext = [
            "site": [
                "name": config.name,
                "url": config.baseURL
            ],
            "nav": [
                "home": "Home",
                "about": "About",
                "contact": "Contact"
            ]
        ]
    }

    // Fluent interface
    public func withPages(_ pageNames: String...) -> Self {
        pages.append(contentsOf: pageNames)
        return self
    }

    public func withStandardPages() -> Self {
        return withPages("index", "about", "contact", "login", "signup")
    }

    public func withContext(_ key: String, _ value: Any) -> Self {
        globalContext[key] = value
        return self
    }

    public func withNavigation(_ nav: [String: String]) -> Self {
        globalContext["nav"] = nav
        return self
    }

    public func build() async -> SiteBuilder {
        // Create the full SiteBuilder.Config
        let fullConfig = SiteConfig(
            name: config.name,
            templatesPath: config.templatesDir.path,
            outputPath: config.outputDir.path,
            assetsPath: config.assetsDir.path
        )

        let builder = SiteBuilder(config: fullConfig)

        // Set global context (convert to XtContext for Sendable compliance)
        var xtGlobalContext = XtContext()
        for (key, value) in globalContext {
            if let xtValue = value as? (any XtValue) {
                xtGlobalContext[key] = xtValue
            }
        }
        await builder.updateGlobalContext(xtGlobalContext)

        // Add configured pages
        for pageName in pages {
            let page = Page(
                path: "\(pageName).html",
                template: "pages/\(pageName).html",
                context: [:]
            )
            await builder.addPage(page)
        }

        return builder
    }
}