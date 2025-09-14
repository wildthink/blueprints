//#!/usr/bin/env swift

import Foundation

// Simple test for TAL engine
func testTALEngine() {
    do {
        let engine = TALEngineXML()

        // Test tal:_attribute syntax
        let xml1 = """
    <div xmlns:tal="http://xml.zope.org/namespaces/tal">
        <a tal:_href="baseURL" tal:_title="linkTitle">Click here</a>
    </div>
    """
        let ctx1: [String: Any] = ["baseURL": "https://example.com", "linkTitle": "Example Site"]
        let result1 = try engine.render(xml: xml1, context: ctx1)
        print("Test 1 - tal:_attribute syntax:")
        print(result1)
        print("")

        // Test simple tal:content
        let xml2 = """
    <div xmlns:tal="http://xml.zope.org/namespaces/tal">
        <span tal:content="greeting">Default text</span>
    </div>
    """
        let ctx2: [String: Any] = ["greeting": "Hello, World!"]
        let result2 = try engine.render(xml: xml2, context: ctx2)
        print("Test 2 - tal:content:")
        print(result2)
        print("")

        // Test tal:condition
        let xml3 = """
    <div xmlns:tal="http://xml.zope.org/namespaces/tal">
        <span tal:condition="show">Visible</span>
        <span tal:condition="hide">Hidden</span>
    </div>
    """
        let ctx3: [String: Any] = ["show": true, "hide": false]
        let result3 = try engine.render(xml: xml3, context: ctx3)
        print("Test 3 - tal:condition:")
        print(result3)
        print("")

    } catch {
        print("Error: \(error)")
    }
}

// Run the test
//testTALEngine()
