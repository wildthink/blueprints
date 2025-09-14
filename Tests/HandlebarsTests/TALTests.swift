//
//  Test.swift
//  Blueprints
//
//  Created by Jason Jobe on 9/10/25.
//

import Testing
@testable import blue
import Foundation

struct Test {
    
    @Test func testPipes() {
        testPipeModifiers()
    }
    
    @Test  func testTALExample() throws {
        let engine = TALEngineXML()
        let xml = """
    <ul xmlns:tal="http://xml.zope.org/namespaces/tal">
      <li tal:repeat="p in people" tal:attributes="data-index p__index">
        <a tal:attributes="href p.url; title p.name" tal:content="p.name">Name</a>
        <span tal:condition="p.active ? 'true' : ''">Active</span>
      </li>
      <p tal:condition="people ? true : false" tal:replace="'Total: '"/>
      <strong tal:content="count">N</strong>
    </ul>
    """
        let ctx: [String: Any] = [
            "people": [
                ["name": "Ada", "url": "https://example.com/ada", "active": true],
                ["name": "Linus", "url": "https://example.com/linus", "active": false],
            ],
            "count": 2
        ]
        let out = try engine.render(xml: xml, context: ctx)
        print(out)
    }

    @Test func testTALEngine_1() {
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
            
        } catch {
            print("Error: \(error)")
        }
    }

    @Test func testTALEngine_2() {
        do {
            let engine = TALEngineXML()
            
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

}
