import Foundation

// Test async TAL engine with custom modifiers
func testAsyncTAL() async {
    do {
        // Register custom modifiers through the registry
        await OutputModifierRegistry.shared.register(name: "currency") { text in
            guard let value = Double(text) else { return text }
            return String(format: "$%.2f", value)
        }

        await OutputModifierRegistry.shared.register(name: "percentage") { text in
            guard let value = Double(text) else { return text }
            return String(format: "%.1f%%", value * 100)
        }

        await OutputModifierRegistry.shared.register(name: "emphasize", isRaw: true) { text in
            "<strong>\(text)</strong>"
        }

        // Create engine
        let engine = TALEngineXML()

        // Test data
        let context: [String: Any] = [
            "price": "29.99",
            "discount": "0.15",
            "productName": "Amazing Widget",
            "description": "<p>This widget will change your life!</p>",
            "items": [
                ["name": "Item 1", "price": "10.50"],
                ["name": "Item 2", "price": "25.99"],
                ["name": "Item 3", "price": "5.75"]
            ]
        ]

        // Test 1: Basic async rendering with custom modifiers
        let xml1 = """
        <div xmlns:tal="http://xml.zope.org/namespaces/tal">
            <h1 tal:content="productName|emphasize">Product</h1>
            <p>Price: <span tal:content="price|currency">$0.00</span></p>
            <p>Discount: <span tal:content="discount|percentage">0%</span></p>
            <div tal:content="description|raw">Description</div>
        </div>
        """

        print("=== Async TAL Engine Test ===")
        print("Test 1 - Custom modifiers with async:")
        let result1 = try await engine.renderAsync(xml: xml1, context: context)
        print(result1)
        print()

        // Test 2: Async with template inheritance
        var templates: [String: String] = [:]
        templates["product_base.xml"] = """
        <html xmlns:tal="http://xml.zope.org/namespaces/tal">
        <head>
            <title tal:content="title">Default Title</title>
        </head>
        <body>
            <header tal:slot="header">Default Header</header>
            <main tal:slot="content">Default Content</main>
            <footer>© 2024</footer>
        </body>
        </html>
        """

        templates["product_page.xml"] = """
        <div xmlns:tal="http://xml.zope.org/namespaces/tal" tal:extends="product_base.xml" tal:define="title productName">
            <h1 tal:slot="header" tal:content="productName|emphasize">Product Name</h1>
            <div tal:slot="content">
                <p>Price: <span tal:content="price|currency">$0.00</span></p>
                <p>Save: <span tal:content="discount|percentage">0%</span></p>
                <div tal:content="description|raw">Product description</div>
                <ul>
                    <li tal:repeat="item items">
                        <span tal:content="item.name">Item</span> -
                        <span tal:content="item.price|currency">$0.00</span>
                    </li>
                </ul>
            </div>
        </div>
        """

        let engineWithResolver = TALEngineXML { templateName in
            return templates[templateName]
        }

        print("Test 2 - Async template inheritance:")
        let result2 = try await engineWithResolver.renderAsync(template: "product_page.xml", context: context)
        print(result2)
        print()

        // Test 3: Show difference between sync and async
        print("Test 3 - Sync vs Async modifier resolution:")

        let testXML = """
        <p xmlns:tal="http://xml.zope.org/namespaces/tal" tal:content="price|currency">Price</p>
        """

        let syncResult = try engine.render(xml: testXML, context: context)
        let asyncResult = try await engine.renderAsync(xml: testXML, context: context)

        print("Sync (built-ins only): \(syncResult)")
        print("Async (with custom):   \(asyncResult)")
        print()

        // Show available modifiers
        let available = await OutputModifierRegistry.shared.availableNames
        print("Available modifiers: \(available.sorted())")

    } catch {
        print("Error: \(error)")
    }
}