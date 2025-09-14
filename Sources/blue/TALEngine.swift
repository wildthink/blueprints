// TALEngineXML.swift
// TAL templating with XMLParser (no XMLDocument)
// Supports tal:content, tal:replace, tal:condition, tal:repeat, tal:attributes
// https://en.wikipedia.org/wiki/Template_Attribute_Language
import Foundation

// MARK: - Output Modifiers

public enum OutputModifier: String, CaseIterable {
    case raw = "raw"           // No HTML escaping
    case upper = "upper"       // Uppercase
    case lower = "lower"       // Lowercase
    case trim = "trim"         // Trim whitespace
    case capitalize = "capitalize" // Capitalize first letter

    func apply(to value: String) -> String {
        switch self {
        case .raw: return value          // No transformation, just flag for no escaping
        case .upper: return value.uppercased()
        case .lower: return value.lowercased()
        case .trim: return value.trimmingCharacters(in: .whitespacesAndNewlines)
        case .capitalize: return value.capitalized
        }
    }
}

// MARK: - Context

public struct TALValue {
    public let raw: Any?
    public let modifiers: [OutputModifier]

    public init(raw: Any?, modifiers: [OutputModifier] = []) {
        self.raw = raw
        self.modifiers = modifiers
    }

    public var bool: Bool {
        if let b = raw as? Bool { return b }
        if let n = raw as? NSNumber { return n != 0 }
        if let s = raw as? String { return !s.isEmpty && s.lowercased() != "false" && s != "0" }
        return raw != nil
    }

    public var string: String {
        let baseString: String
        switch raw {
            case nil: baseString = ""
            case let s as String: baseString = s
            case let n as NSNumber: baseString = n.stringValue
            case let a as [Any]: baseString = a.map { TALValue(raw: $0).string }.joined(separator: ",")
            case let d as Date: baseString = ISO8601DateFormatter().string(from: d)
            default: baseString = String(describing: raw!)
        }

        // Apply modifiers in sequence
        return modifiers.reduce(baseString) { result, modifier in
            modifier.apply(to: result)
        }
    }

    public var shouldEscape: Bool {
        !modifiers.contains(.raw)
    }
}

public final class TALContext {
    private var stack: [[String: Any]] = []
    public init(_ root: [String: Any] = [:]) { stack = [root] }
    public func push(_ dict: [String: Any]) { stack.append(dict) }
    public func pop() { _ = stack.popLast() }
    public subscript(_ keyPath: String) -> TALValue { TALValue(raw: resolve(keyPath)) }

    /// Evaluates an expression with pipe modifiers: "variable|modifier1|modifier2"
    public func evaluate(_ expression: String) -> TALValue {
        let parts = expression.split(separator: "|").map(String.init)
        guard !parts.isEmpty else { return TALValue(raw: nil) }

        let variablePath = parts[0].trimmingCharacters(in: .whitespaces)
        let modifierStrings = parts.dropFirst().map { $0.trimmingCharacters(in: .whitespaces) }

        let modifiers = modifierStrings.compactMap { OutputModifier(rawValue: $0) }

        let rawValue = resolve(variablePath)
        return TALValue(raw: rawValue, modifiers: modifiers)
    }
    
    private func resolve(_ keyPath: String) -> Any? {
        let parts = keyPath.split(separator: ".").map(String.init)
        for scope in stack.reversed() {
            if let v = dive(scope, parts: parts) { return v }
        }
        return nil
    }
    private func dive(_ any: Any, parts: [String]) -> Any? {
        guard !parts.isEmpty else { return any }
        if let dict = any as? [String: Any] {
            let head = parts[0]
            guard let next = dict[head] else { return nil }
            return dive(next, parts: Array(parts.dropFirst()))
        } else if let arr = any as? [Any], let idx = Int(parts[0]), idx >= 0, idx < arr.count {
            return dive(arr[idx], parts: Array(parts.dropFirst()))
        } else {
            let m = Mirror(reflecting: any)
            if let child = m.children.first(where: { $0.label == parts[0] }) {
                return dive(child.value, parts: Array(parts.dropFirst()))
            }
        }
        return nil
    }
}

// MARK: - AST


// MARK: - Engine

public enum TALAttr: String {
    case content = "tal:content"
    case replace = "tal:replace"
    case condition = "tal:condition"
    case repeat_ = "tal:repeat"
    case attributes = "tal:attributes"
    
    /// The precedence order in which the directives are
    /// applied on a given Node (higher number = higher precedence)
    public var rank: Int {
        switch self {
            case .condition: return 4  // Highest precedence - can remove element
            case .repeat_: return 3    // Second - can create multiple elements
            case .replace: return 2    // Third - replaces entire element
            case .attributes: return 1 // Fourth - modifies attributes
            case .content: return 0    // Lowest - modifies content
        }
    }
    
    init?(_ qn: QName) {
        guard qn.ns == "tal" else { return nil }
        switch qn.name.lowercased() {
            case "content": self = .content
            case "replace": self = .replace
            case "condition": self = .condition
            case "repeat": self = .repeat_
            case "attributes": self = .attributes
            default:
                // Check for tal:_attributeName pattern
                if qn.name.hasPrefix("_") && qn.name.count > 1 {
                    self = .attributes
                } else {
                    return nil
                }
        }
    }
}

public struct TALDirective {
    /// The engine "instruction code"
    var tag: TALAttr
    /// An array of all the tokens of the Node's attribute (trimmed and cleaned)
    var argv: [String]
    /// For tal:_attributeName pattern, stores the target attribute name
    var targetAttribute: String?
    var rank: Int { tag.rank }

    subscript(ndx: Int) -> String {
        guard ndx < argv.count else { return "" }
        return argv[ndx]
    }

    init(_ tag: TALAttr, argv: Any...) {
        self.tag = tag
        self.argv = argv.map(String.init(describing:))
    }

    init(_ tag: TALAttr, argv: [String]) {
        self.tag = tag
        self.argv = argv
    }

    init?(_ kv: DTFValue) {
        guard let attr = TALAttr(kv.qname)
        else { return nil }
        tag = attr

        // Check if this is a tal:_attributeName pattern
        if kv.qname.name.hasPrefix("_") && kv.qname.name.count > 1 {
            targetAttribute = String(kv.qname.name.dropFirst()) // Remove the "_" prefix
        }

        // Clean up the value and split into arguments
        let cleanValue = kv.value.trimmingCharacters(in: .whitespacesAndNewlines)
        argv = cleanValue.split(separator: " ").map {
            String($0).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}

public final class TALEngineXML {
    private let TAL_NS = "http://xml.zope.org/namespaces/tal" // informational
    public typealias Element = AnyDTFNode
    public init() {}
    
    public func render(xml: String, context: [String: Any]) throws -> String {
        let tree = try DocumentTree(xml: xml)
        let ctx = TALContext(context)
        let processed = try process(elem: tree.root, ctx: ctx) // may return nil if removed by condition
        guard let out = processed else { return "" }
        return serialize(elem: out)
    }
    
    // MARK: - Processing
    
    private func process(elem: some Element, ctx: TALContext) throws -> (any Element)? {
        guard var node = elem as? DTFNode else { return elem }

        let directives = node.attributes
            .compactMap(TALDirective.init)
            .sorted(by: { $0.rank > $1.rank }) // Higher rank = higher precedence

        // Process TAL directives in order of precedence
        for directive in directives {
            switch directive.tag {
            case .condition:
                // tal:condition - may remove element entirely
                let result = evaluateExpression(directive, ctx: ctx)
                if !result.bool {
                    return nil // Remove element
                }

            case .repeat_:
                // tal:repeat - may create multiple elements
                return processRepeat(node: node, directive: directive, ctx: ctx)

            case .replace:
                // tal:replace - replaces entire element
                let result = evaluateExpression(directive, ctx: ctx)
                return DTFValue(qname: QName(name: "text"), value: result.string, shouldEscape: result.shouldEscape)

            case .attributes:
                // tal:attributes - modifies attributes
                node = processAttributes(node: node, directive: directive, ctx: ctx)

            case .content:
                // tal:content - replaces element content
                let result = evaluateExpression(directive, ctx: ctx)
                node = DTFNode(tag: node.qname, attributes: node.attributes,
                              children: [DTFValue(qname: QName(name: "text"), value: result.string, shouldEscape: result.shouldEscape)])
            }
        }

        // If no tal:content directive, process children recursively
        if !directives.contains(where: { $0.tag == .content }) {
            let processedChildren = node.children.compactMap { try? process(elem: $0, ctx: ctx) }
            node = DTFNode(tag: node.qname, attributes: node.attributes, children: processedChildren)
        }

        return node
    }

    private func processRepeat(node: DTFNode, directive: TALDirective, ctx: TALContext) -> DTFNode? {
         // eg. "p in people"
        guard let array = ctx[directive[2]].raw as? [Any]
        else { return node }
        let varName = directive[0]
        
        // Create repeated elements
        var results: [any AnyDTFNode] = []
        
        // WARNING: MUST remove the repeat to avoid infinite recursion
        var step = node
        step.removeAttribute(named: "tal:repeat")
        
        for (index, item) in array.enumerated() {
            ctx.push([varName: item, "\(varName)__index": index])
            if let processed = try? process(elem: step, ctx: ctx) {
                results.append(processed)
            }
            ctx.pop()
        }
        // Return a container with all repeated elements
        return DTFNode(tag: QName(name: "repeat-container"), attributes: [], children: results)
    }

    /// Attribute Substitution
    /// tal:_src="baseURL" -> src="https://example.com"
    /// tal:attributes="href p.url; title p.name" -> href="..." title="..."
    private func processAttributes(
        node: DTFNode,
        directive: TALDirective,
        ctx: TALContext
    ) -> DTFNode {
        var newAttributes = node.attributes.filter { $0.qname.ns != "tal" }

        if let targetAttr = directive.targetAttribute {
            // Handle tal:_attributeName="expression" pattern
            let result = evaluateExpression(directive, ctx: ctx)
            newAttributes.append(DTFValue(qname: QName(name: targetAttr), value: result.string, shouldEscape: result.shouldEscape))
        } else {
            // Handle tal:attributes="attr expr; attr expr" pattern
            let expression = directive.argv.joined(separator: " ")
            let assignments = expression.split(separator: ";")
            for assignment in assignments {
                let parts = assignment.split(separator: " ", maxSplits: 1)
                guard parts.count == 2 else { continue }

                let attrName = String(parts[0]).trimmingCharacters(in: .whitespaces)
                let expr = String(parts[1]).trimmingCharacters(in: .whitespaces)
                let value = evaluateExpression(expr, ctx: ctx)

                newAttributes.append(DTFValue(qname: QName(name: attrName), value: value.string, shouldEscape: value.shouldEscape))
            }
        }

        return DTFNode(tag: node.qname, attributes: newAttributes, children: node.children)
    }

    private func evaluateExpression(_ expr: String, ctx: TALContext) -> TALValue {
        // Handle ternary operator: "expr ? true_val : false_val"
        if expr.contains("?") && expr.contains(":") {
            return evaluateTernary(expr, ctx: ctx)
        }

        // Use new pipe-aware evaluation
        return ctx.evaluate(expr.trimmingCharacters(in: .whitespaces))
    }

    private func evaluateTernary(_ expr: String, ctx: TALContext) -> TALValue {
        let parts = expr.split(separator: "?", maxSplits: 1)
        guard parts.count == 2 else { return ctx.evaluate(expr) }

        let condition = String(parts[0]).trimmingCharacters(in: .whitespaces)
        let rest = String(parts[1])

        let valueParts = rest.split(separator: ":", maxSplits: 1)
        guard valueParts.count == 2 else { return ctx.evaluate(expr) }

        let trueVal = String(valueParts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
        let falseVal = String(valueParts[1]).trimmingCharacters(in: .whitespacesAndNewlines)

        let condResult = ctx[condition] // Simple lookup for condition (no modifiers needed for bool check)
        let resultExpr = condResult.bool ? trueVal : falseVal

        // Remove quotes if present and evaluate with pipe modifiers
        let cleanResult = resultExpr.trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
        return ctx.evaluate(cleanResult)
    }

    private func evaluateExpression(_ directive: TALDirective, ctx: TALContext) -> TALValue {
        let expr = directive.argv.joined(separator: " ")
        return evaluateExpression(expr, ctx: ctx)
    }

    private func serialize(elem: Element) -> String {
        if let dtfValue = elem as? DTFValue {
            // This is a text node or attribute - respect the shouldEscape flag
            if dtfValue.qname.name == "text" {
                return dtfValue.shouldEscape ? dtfValue.value.escape() : dtfValue.value
            } else {
                // This is an attribute value, always escape for safety in attributes
                return dtfValue.shouldEscape ? dtfValue.value.escape() : dtfValue.value
            }
        }

        guard let dtfNode = elem as? DTFNode else { return "" }

        // Special case: repeat-container should render its children without the container tag
        if dtfNode.qname.name == "repeat-container" {
            return dtfNode.children.map { serialize(elem: $0) }.joined()
        }

        let tagName = dtfNode.qname.name
        var result = "<\(tagName)"

        // Add attributes (excluding TAL attributes)
        for attr in dtfNode.attributes where attr.qname.ns != "tal" {
            let attrName = attr.qname.description
            let attrValue = attr.shouldEscape ? attr.value.escape() : attr.value
            result += " \(attrName)=\"\(attrValue)\""
        }

        if dtfNode.children.isEmpty {
            result += "/>"
        } else {
            result += ">"
            for child in dtfNode.children {
                result += serialize(elem: child)
            }
            result += "</\(tagName)>"
        }

        return result
    }
}

extension String {
    fileprivate func escape() -> String {
        var out = ""
        out.reserveCapacity(count + 8)
        for ch in self {
            switch ch {
                case "&": out += "&amp;"
                case "<": out += "&lt;"
                case ">": out += "&gt;"
                case "\"": out += "&quot;"
                case "'": out += "&#39;"
                default: out.append(ch)
            }
        }
        return out
    }
}

// MARK: - Example (wrap in `test` function)

public func testTALXMLParser() throws {
    let engine = TALEngineXML()
    let xml = """
    <ul xmlns:tal="http://xml.zope.org/namespaces/tal">
      <li tal:repeat="p in people" tal:attributes="data-index p__index">
        <a tal:attributes="href p.url; title p.name" tal:content="p.name">Name</a>
        <span tal:condition="p.active ? 'true' : ''">Active</span>
      </li>
      <p tal:condition="people ? true : false" tal:replace="'Total: '"/>
      <strong tal:content="people.count">N</strong>
    </ul>
    """
    let ctx: [String: Any] = [
        "people": [
            ["name": "Ada", "url": "https://example.com/ada", "active": true],
            ["name": "Linus", "url": "https://example.com/linus", "active": false],
        ],
        "people.count": 2
    ]
    let out = try engine.render(xml: xml, context: ctx)
    print(out)
}
