import Foundation

// MARK: - Usage Examples

func exampleUsage() async throws {

    // Option 3: Smart Path Resolution - Completely automatic (IMPLEMENTED)
    let autoSite = try await SiteBuilder.autoConfigured()
    try await autoSite.build()

    // Option 4: Convention-based with custom project root (IMPLEMENTED)
    let projectRoot = URL(fileURLWithPath: "/path/to/my/project")
    let scanner = ProjectScanner(projectRoot: projectRoot)
    let conventionSite = try await scanner.createSiteBuilder(name: "Custom Site")
    try await conventionSite.build()

    // Option 5: Template Patterns for common site types (IMPLEMENTED)
    let blogSite = try await SiteBuilder.blog(name: "Tech Blog")
    try await blogSite.build()

    let portfolioSite = try await SiteBuilder.portfolio(name: "Design Portfolio")
    try await portfolioSite.build()

    let businessSite = try await SiteBuilder.business(name: "Acme Corp")
    try await businessSite.build()
}

// MARK: - One-Line Usage Examples

func oneLineUsage() async throws {
    // Build entire site in one line!
    try await SiteBuilder.autoConfigured(name: "3rd Space").build()

    // Or use a template pattern
    try await SiteBuilder.blog(name: "My Blog").build()
    try await SiteBuilder.portfolio(name: "My Work").build()
    try await SiteBuilder.business(name: "My Company").build()
}

// MARK: - Additional Helper Functions
// Note: Main template patterns are defined in SiteBuilder.swift

func createCustomBlogSite(name: String) async -> SiteBuilder {
    return await EasySiteBuilder(name: name)
        .withPages("index", "blog", "post", "about", "contact")
        .withNavigation([
            "home": "Home",
            "blog": "Blog",
            "about": "About",
            "contact": "Contact"
        ])
        .build()
}