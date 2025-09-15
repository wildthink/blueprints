import Foundation

/// Automatically scans project structure and sets up sensible defaults
public struct ProjectScanner {
    public let projectRoot: URL

    public init(projectRoot: URL? = nil) {
        if let projectRoot = projectRoot {
            self.projectRoot = projectRoot
        } else {
            self.projectRoot = Self.findProjectRoot()
        }
    }

    /// Scan the project and create a fully configured SiteBuilder
    public func createSiteBuilder(name: String? = nil) async throws -> SiteBuilder {
        let siteName = name ?? extractSiteName()
        let context = try loadContextFile()

        // Auto-discover templates
        let templates = discoverTemplates()
        let assets = discoverAssets()

        let config = SiteConfig(
            name: siteName,
            templatesPath: templatesDir.path,
            outputPath: outputDir.path,
            assetsPath: assetsDir.path
        )

        let builder = SiteBuilder(config: config)

        // Auto-add discovered pages
        for template in templates.pages {
            let pageName = template.deletingPathExtension().lastPathComponent
            let page = Page(
                path: "\(pageName).html",
                template: "pages/\(template.lastPathComponent)",
                context: [:]
            )
            await builder.addPage(page)
        }

        return builder
    }

    // MARK: - Discovery Methods

    private func discoverTemplates() -> (pages: [URL], layouts: [URL]) {
        let pagesDir = templatesDir.appending(path: "pages")
        let layoutsDir = templatesDir.appending(path: "layouts")

        let pages = scanDirectory(pagesDir, for: "html")
        let layouts = scanDirectory(layoutsDir, for: "html")

        return (pages, layouts)
    }

    private func discoverAssets() -> [URL] {
        return scanDirectory(assetsDir, for: ["css", "js", "png", "jpg", "jpeg", "gif", "svg"])
    }

    private func scanDirectory(_ dir: URL, for extensions: [String]) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil) else {
            return []
        }

        return enumerator.compactMap { item in
            guard let url = item as? URL else { return nil }
            return extensions.contains(url.pathExtension.lowercased()) ? url : nil
        }
    }

    private func scanDirectory(_ dir: URL, for ext: String) -> [URL] {
        return scanDirectory(dir, for: [ext])
    }

    private func loadContextFile() throws -> XtContext {
        let contextFile = projectRoot.appending(path: "Resources/sample-context.json")
        guard FileManager.default.fileExists(atPath: contextFile.path) else {
            return [:]
        }

        let data = try Data(contentsOf: contextFile)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

        // Convert to XtContext
        var context: [String: any XtValue] = [:]
        for (key, value) in json {
            if let xtValue = value as? (any XtValue) {
                context[key] = xtValue
            }
        }

        let kvPairs = Array(context)
        var xtContext = XtContext()
        for (key, value) in kvPairs {
            xtContext[key] = value
        }
        return xtContext
    }

    // MARK: - Path Properties

    public var templatesDir: URL { projectRoot.appending(path: "Resources/templates") }
    public var assetsDir: URL { projectRoot.appending(path: "Resources/assets") }
    public var outputDir: URL { projectRoot.appending(path: "deploy") }

    // MARK: - Helper Methods

    private static func findProjectRoot() -> URL {
        var current = URL(fileURLWithPath: #filePath)
        while current.path != "/" {
            current = current.deletingLastPathComponent()
            if FileManager.default.fileExists(atPath: current.appending(path: "Package.swift").path) {
                return current
            }
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    private func extractSiteName() -> String {
        // Try to extract from Package.swift
        let packageFile = projectRoot.appending(path: "Package.swift")
        if let content = try? String(contentsOf: packageFile),
           let nameMatch = content.range(of: #"name:\s*"([^"]+)""#, options: .regularExpression) {
            let nameRange = content[nameMatch].range(of: #""([^"]+)""#, options: .regularExpression)
            if let nameRange = nameRange {
                let name = String(content[nameRange]).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                return name
            }
        }

        // Fallback to directory name
        return projectRoot.lastPathComponent
    }
}

// MARK: - Convenience Extensions
// Note: Extensions are defined in SiteBuilder.swift to avoid duplication