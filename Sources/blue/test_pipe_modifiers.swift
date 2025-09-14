import Foundation

// Test the new pipe modifier system
func testPipeModifiers() {
    do {
        let engine = TALEngineXML()

        // Test data with HTML content
        let context: [String: Any] = [
            "htmlContent": "<strong>Bold Text</strong>",
            "plainText": "  hello world  ",
            "userName": "john doe",
            "greeting": "Welcome!"
        ]

        // Test 1: Basic escaping (default behavior)
        let test1 = """
        <div xmlns:tal="http://xml.zope.org/namespaces/tal">
            <p tal:content="htmlContent">Default</p>
        </div>
        """
        let result1 = try engine.render(xml: test1, context: context)
        print("Test 1 - Default escaping:")
        print(result1)
        print()

        // Test 2: Raw modifier (no escaping)
        let test2 = """
        <div xmlns:tal="http://xml.zope.org/namespaces/tal">
            <p tal:content="htmlContent|raw">Default</p>
        </div>
        """
        let result2 = try engine.render(xml: test2, context: context)
        print("Test 2 - Raw modifier:")
        print(result2)
        print()

        // Test 3: Text transformation modifiers
        let test3 = """
        <div xmlns:tal="http://xml.zope.org/namespaces/tal">
            <p tal:content="userName|capitalize">Default</p>
            <p tal:content="userName|upper">Default</p>
            <p tal:content="plainText|trim">Default</p>
        </div>
        """
        let result3 = try engine.render(xml: test3, context: context)
        print("Test 3 - Text transformations:")
        print(result3)
        print()

        // Test 4: Chained modifiers
        let test4 = """
        <div xmlns:tal="http://xml.zope.org/namespaces/tal">
            <p tal:content="plainText|trim|upper">Default</p>
            <span tal:content="htmlContent|upper|raw">Default</span>
        </div>
        """
        let result4 = try engine.render(xml: test4, context: context)
        print("Test 4 - Chained modifiers:")
        print(result4)
        print()

        // Test 5: Modifiers with tal:replace
        let test5 = """
        <div xmlns:tal="http://xml.zope.org/namespaces/tal">
            <p tal:replace="htmlContent|raw">This will be replaced</p>
        </div>
        """
        let result5 = try engine.render(xml: test5, context: context)
        print("Test 5 - tal:replace with raw:")
        print(result5)
        print()

        // Test 6: Modifiers with tal:_attribute
        let test6 = """
        <div xmlns:tal="http://xml.zope.org/namespaces/tal">
            <input tal:_value="userName|capitalize" type="text"/>
        </div>
        """
        let result6 = try engine.render(xml: test6, context: context)
        print("Test 6 - tal:_attribute with modifier:")
        print(result6)
        print()

    } catch {
        print("Error: \(error)")
    }
}