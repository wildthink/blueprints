import Foundation

// Test template inheritance system
func testTemplateInheritance() {

    // Template storage
    var templates: [String: String] = [:]

    // Base template
    templates["base.xml"] = """
    <html xmlns:tal="http://xml.zope.org/namespaces/tal">
        <head>
            <title tal:content="title">Default Title</title>
        </head>
        <body>
            <header>
                <h1 tal:slot="header">Default Header</h1>
            </header>
            <main tal:slot="content">
                <p>Default content goes here</p>
            </main>
            <footer>
                <p tal:content="footer">© 2024</p>
            </footer>
        </body>
    </html>
    """

    // Child template
    templates["page.xml"] = """
    <div xmlns:tal="http://xml.zope.org/namespaces/tal" tal:extends="base.xml" tal:define="title 'My Page'; footer '© My Company'">
        <h1 tal:slot="header">Welcome to My Site</h1>
        <div tal:slot="content">
            <h2>Page Content</h2>
            <p tal:content="message">Page message here</p>
        </div>
    </div>
    """

    // Another child template
    templates["blog.xml"] = """
    <article xmlns:tal="http://xml.zope.org/namespaces/tal" tal:extends="base.xml" tal:define="title blogTitle">
        <h1 tal:slot="header" tal:content="blogTitle">Blog Title</h1>
        <article tal:slot="content">
            <h2 tal:content="postTitle">Post Title</h2>
            <p tal:content="postContent">Post content</p>
            <div tal:condition="showAuthor">
                <small>By: <span tal:content="author">Author</span></small>
            </div>
        </article>
    </article>
    """

    do {
        // Create engine with template resolver
        let engine = TALEngineXML { templateName in
            return templates[templateName]
        }

        // Test 1: Basic page template
        let context1: [String: Any] = [
            "message": "Hello from the page template!"
        ]

        let result1 = try engine.render(template: "page.xml", context: context1)
        print("Test 1 - Basic template inheritance:")
        print(result1)
//        print("\n" + "="*50 + "\n")

        // Test 2: Blog template
        let context2: [String: Any] = [
            "blogTitle": "Tech Blog",
            "postTitle": "Understanding TAL Templates",
            "postContent": "Template Attribute Language makes web templating powerful and flexible...",
            "author": "John Doe",
            "showAuthor": true
        ]

        let result2 = try engine.render(template: "blog.xml", context: context2)
        print("Test 2 - Blog template with inheritance:")
        print(result2)
        print()

        // Test 3: Show pretty-printed version
        print("Test 3 - Pretty-printed DocumentTree:")
        let tree = try DocumentTree(xml: templates["base.xml"]!)
        print(tree.toPrettyXML())

    } catch {
        print("Error: \(error)")
    }
}
