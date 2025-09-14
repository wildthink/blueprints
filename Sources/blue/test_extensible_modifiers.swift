import Foundation

// Test the new extensible modifier system
func testExtensibleModifiers() async {

    // Register custom modifiers
    await OutputModifier.register(name: "truncate") { text in
        text.count > 20 ? String(text.prefix(17)) + "..." : text
    }

    await OutputModifier.register(name: "reverse") { text in
        String(text.reversed())
    }

    // Custom modifier that produces raw HTML
    await OutputModifier.register(name: "bold", isRaw: true) { text in
        "<strong>\(text)</strong>"
    }

    do {
        let engine = TALEngineXML()

        let context: [String: Any] = [
            "longText": "This is a very long piece of text that should be truncated by our custom modifier",
            "message": "Hello World",
            "content": "Important"
        ]

        // Test custom modifiers
        let test1 = """
        <div xmlns:tal="http://xml.zope.org/namespaces/tal">
            <p tal:content="longText|truncate">Default</p>
            <p tal:content="message|reverse">Default</p>
            <p tal:content="content|bold">Default</p>
        </div>
        """
        let result1 = try engine.render(xml: test1, context: context)
        print("Test 1 - Custom modifiers:")
        print(result1)
        print()

        // Test chaining with custom modifiers
        let test2 = """
        <div xmlns:tal="http://xml.zope.org/namespaces/tal">
            <p tal:content="longText|upper|truncate">Default</p>
            <span tal:content="message|reverse|upper">Default</span>
        </div>
        """
        let result2 = try engine.render(xml: test2, context: context)
        print("Test 2 - Chained with custom modifiers:")
        print(result2)
        print()

        // Show available modifiers
        print("Available modifiers: \(await OutputModifier.availableNames.sorted())")
        print()

    } catch {
        print("Error: \(error)")
    }
}
