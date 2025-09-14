//#!/usr/bin/env swift

import Foundation

// Simple test for TAL engine
func testTALEngine() {
    do {
        let engine = TALEngineXML()
        
        // Test simple tal:content
        let xml1 = """
    <div xmlns:tal="http://xml.zope.org/namespaces/tal">
        <span tal:content="greeting">Default text</span>
    </div>
    """
        let ctx1: [String: Any] = ["greeting": "Hello, World!"]
        let result1 = try engine.render(xml: xml1, context: ctx1)
        print("Test 1 - tal:content:")
        print(result1)
        print("")
        
        // Test tal:condition
        let xml2 = """
    <div xmlns:tal="http://xml.zope.org/namespaces/tal">
        <span tal:condition="show">Visible</span>
        <span tal:condition="hide">Hidden</span>
    </div>
    """
        let ctx2: [String: Any] = ["show": true, "hide": false]
        let result2 = try engine.render(xml: xml2, context: ctx2)
        print("Test 2 - tal:condition:")
        print(result2)
        print("")
        
    } catch {
        print("Error: \(error)")
    }
}
