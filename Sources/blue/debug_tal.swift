import Foundation

// Create a minimal test to debug the issue
func debugTAL() {
    do {
        let engine = TALEngineXML()

        // Test simple tal:condition
        let xml = """
<div xmlns:tal="http://xml.zope.org/namespaces/tal">
    <span tal:condition="show">Should be visible</span>
    <span tal:condition="hide">Should be hidden</span>
</div>
"""
        let ctx: [String: Any] = ["show": true, "hide": false]
        print("Context: \(ctx)")

        let result = try engine.render(xml: xml, context: ctx)
        print("Result:")
        print(result)

    } catch {
        print("Error: \(error)")
    }
}