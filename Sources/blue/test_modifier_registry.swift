import Foundation

// Test the new OutputModifierRegistry for better concurrency
func testModifierRegistry() async {
    do {
        let registry = OutputModifierRegistry.shared

        // Register custom modifiers through the registry
        await registry.register(name: "shout") { text in
            text.uppercased() + "!!!"
        }

        await registry.register(name: "whisper") { text in
            text.lowercased() + "..."
        }

        await registry.register(name: "reverse") { text in
            String(text.reversed())
        }

        // Register a raw HTML modifier
        await registry.register(name: "emphasize", isRaw: true) { text in
            "<em>\(text)</em>"
        }

        // Register multiple modifiers at once
        let batchModifiers: [String: OutputModifier] = [:]
        await registry.register(batchModifiers)

        print("=== OutputModifierRegistry Test ===")
        print()

        // Test individual modifier lookup
        if let shoutModifier = await registry.named("shout") {
            let result = shoutModifier.apply(to: "hello world")
            print("Shout modifier: '\(result)'")
        }

        // Test built-in modifier lookup
        if let upperModifier = await registry.named("upper") {
            let result = upperModifier.apply(to: "hello world")
            print("Built-in upper: '\(result)'")
        }

        // Show all available modifiers
        let available = await registry.availableNames
        print("Available modifiers: \(available.sorted())")
        print()

        // Test with TAL engine (sync version - uses built-ins only)
        let engine = TALEngineXML()
        let context: [String: Any] = [
            "message": "Hello World",
            "content": "<strong>Bold text</strong>"
        ]

        let xml = """
        <div xmlns:tal="http://xml.zope.org/namespaces/tal">
            <p tal:content="message|upper|trim">Default</p>
            <div tal:content="content|raw">Default content</div>
        </div>
        """

        let result = try engine.render(xml: xml, context: context)
        print("TAL Engine Result:")
        print(result)
        print()

        // Demonstrate registry isolation in different tasks
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await registry.register(name: "task1") { "Task1: \($0)" }
                if let modifier = await registry.named("task1") {
                    print("Task 1: \(modifier.apply(to: "test"))")
                }
            }

            group.addTask {
                await registry.register(name: "task2") { "Task2: \($0)" }
                if let modifier = await registry.named("task2") {
                    print("Task 2: \(modifier.apply(to: "test"))")
                }
            }
        }

        // Both modifiers should be available after tasks complete
        let finalList = await registry.availableNames
        print("Final modifier count: \(finalList.count)")

        // Clean up
        await registry.unregister("task1")
        await registry.unregister("task2")

    } catch {
        print("Error: \(error)")
    }
}