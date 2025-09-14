//
//  TALValue.swift
//  Blueprints
//
//  Created by Jason Jobe on 9/10/25.
//


//
//  TALValue.swift
//  Blueprints
//
//  Created by Jason Jobe on 9/10/25.
//


// TALEngine.swift
// Minimal TAL processor for XML/HTML using FoundationXML
import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

public struct TALValue {
    public let raw: Any?
    public var bool: Bool {
        if let b = raw as? Bool { return b }
        if let n = raw as? NSNumber { return n != 0 }
        if let s = raw as? String { return !s.isEmpty && s.lowercased() != "false" && s != "0" }
        if raw == nil { return false }
        return true
    }
    public var string: String {
        switch raw {
        case nil: return ""
        case let s as String: return s
        case let n as NSNumber: return n.stringValue
        case let a as [Any]: return a.map { TALValue(raw: $0).string }.joined(separator: ",")
        case let d as Date: return ISO8601DateFormatter().string(from: d)
        default: return String(describing: raw!)
        }
    }
}

public final class TALContext {
    private var stack: [[String: Any]] = []
    public init(_ root: [String: Any] = [:]) { stack = [root] }
    public func push(_ dict: [String: Any]) { stack.append(dict) }
    public func pop() { _ = stack.popLast() }
    public func merged() -> [String: Any] { stack.reduce([:]) { $0.merging($1) { _, new in new } } }
    public subscript(_ keyPath: String) -> TALValue {
        TALValue(raw: resolve(keyPath))
    }
    private func resolve(_ keyPath: String) -> Any? {
        let parts = keyPath.split(separator: ".").map(String.init)
        for scope in stack.reversed() {
            if let val = dive(scope, parts: parts) { return val }
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
            // KeyPath on object via KVC-like mirror
            let m = Mirror(reflecting: any)
            if let child = m.children.first(where: { $0.label == parts[0] }) {
                return dive(child.value, parts: Array(parts.dropFirst()))
            }
        }
        return nil
    }
}

public enum TALAttr: String {
    case content = "tal:content"
    case replace = "tal:replace"
    case condition = "tal:condition"
    case repeat_ = "tal:repeat"
    case attributes = "tal:attributes"
}

// jmj
extension XMLNode {
    @_disfavoredOverload
    func insertChild(_ ch: XMLNode, at ndx: Int) {
        guard let me = self as? XMLElement
        else { return }
        me.insertChild(ch, at: ndx)
    }
    
    @_disfavoredOverload
    func replaceChild(at ndx: Int, with ch: XMLNode, ) {
        guard let me = self as? XMLElement
        else { return }
        me.replaceChild(at: ndx, with: ch)
    }
}

public final class TALEngine {
    public init() {}

    public func render(xml: String, context: [String: Any]) throws -> String {
        let doc = try XMLDocument(
            xmlString: xml,
            options: [.nodePreserveAll, .nodeCompactEmptyElement, .documentTidyHTML])
        guard let root = doc.rootElement() else { return xml }
        let ctx = TALContext(context)
        try process(node: root, ctx: ctx)
        doc.characterEncoding = "UTF-8"
        return doc.xmlString(options: [.nodePrettyPrint])
    }

    // MARK: - Core processing
    private func process(node: XMLElement, ctx: TALContext) throws {
        // condition
        if let cond = node.attribute(forName: TALAttr.condition.rawValue)?.stringValue {
            if !evalBool(cond, ctx) {
                node.detach()
                return
            }
            node.removeAttribute(forName: TALAttr.condition.rawValue)
        }

        // repeat
        if let rep = node.attribute(forName: TALAttr.repeat_.rawValue)?.stringValue {
            let (varName, path) = parseRepeat(rep)
            let listVal = ctx[path].raw
            node.removeAttribute(forName: TALAttr.repeat_.rawValue)
            guard let arr = listVal as? [Any] else {
                // if not array, drop node when non-iterable
                node.detach()
                return
            }
            // Clone template before mutation
            let template = node.copy() as! XMLElement
            // Insert clones before original, then remove original
            for item in arr.enumerated() {
                let clone = template.copy() as! XMLElement
                ctx.push([varName: item.element, "\(varName)__index": item.offset])
                try process(node: clone, ctx: ctx)
                ctx.pop()
                node.parent?.insertChild(clone, at: node.index)
            }
            node.detach()
            return
        }

        // attributes
        if let attrs = node.attribute(forName: TALAttr.attributes.rawValue)?.stringValue {
            applyAttributesDirective(attrs, to: node, ctx: ctx)
            node.removeAttribute(forName: TALAttr.attributes.rawValue)
        }

        // content / replace
        if let replace = node.attribute(forName: TALAttr.replace.rawValue)?.stringValue {
            let txt = evalString(replace, ctx)
            if let text = XMLNode.text(withStringValue: txt) as? XMLNode {
                node.parent?.replaceChild(at: node.index, with: text)
            }
            return
        }
        if let content = node.attribute(forName: TALAttr.content.rawValue)?.stringValue {
            let txt = evalString(content, ctx)
            node.setChildren([XMLNode.text(withStringValue: txt) as! XMLNode])
            node.removeAttribute(forName: TALAttr.content.rawValue)
        }

        // Recurse children
        for child in node.children ?? [] {
            if let el = child as? XMLElement {
                try process(node: el, ctx: ctx)
            }
        }
    }

    // MARK: - Eval
    private func evalBool(_ expr: String, _ ctx: TALContext) -> Bool {
        parseExpr(expr, ctx).bool
    }
    private func evalString(_ expr: String, _ ctx: TALContext) -> String {
        parseExpr(expr, ctx).string
    }
    private func parseExpr(_ expr: String, _ ctx: TALContext) -> TALValue {
        let e = expr.trimmingCharacters(in: .whitespacesAndNewlines)
        if e.hasPrefix("'") || e.hasPrefix("\"") {
            return TALValue(raw: stripQuotes(e))
        }
        if let n = Double(e) { return TALValue(raw: n) }
        if e.lowercased() == "true" { return TALValue(raw: true) }
        if e.lowercased() == "false" { return TALValue(raw: false) }
        // simple ternary: cond ? a : b
        if let qIdx = e.firstIndex(of: "?"), let cIdx = e.firstIndex(of: ":"),
           qIdx < cIdx {
            let cond = String(e[..<qIdx]).trimmingCharacters(in: .whitespaces)
            let a = String(e[e.index(after: qIdx)..<cIdx]).trimmingCharacters(in: .whitespaces)
            let b = String(e[e.index(after: cIdx)...]).trimmingCharacters(in: .whitespaces)
            return evalBool(cond, ctx) ? parseExpr(a, ctx) : parseExpr(b, ctx)
        }
        // Path or fallback
        return ctx[e]
    }

    // MARK: - Directives
    private func parseRepeat(_ raw: String) -> (String, String) {
        // "item path.to.array" or "item in path.to.array"
        let parts = raw.split(whereSeparator: \.isWhitespace).map(String.init)
        if parts.count >= 3, parts[1].lowercased() == "in" {
            return (parts[0], parts.dropFirst(2).joined(separator: " "))
        }
        return (parts.first ?? "item", parts.dropFirst().joined(separator: " "))
    }

    private func applyAttributesDirective(_ raw: String, to node: XMLElement, ctx: TALContext) {
        // "href path.to.url; title 'Hello'; data-ix user.id"
        let clauses = raw.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        for clause in clauses {
            let parts = clause.split(whereSeparator: \.isWhitespace).map(String.init)
            guard parts.count >= 2 else { continue }
            let name = parts[0]
            let expr = parts.dropFirst().joined(separator: " ")
            let val = evalString(expr, ctx)
            if val.isEmpty {
                node.removeAttribute(forName: name)
            } else {
                node.addAttribute(XMLNode.attribute(withName: name, stringValue: val) as! XMLNode)
            }
        }
    }

    // MARK: - Utils
    private func stripQuotes(_ s: String) -> String {
        guard let first = s.first, let last = s.last, first == last, first == "'" || first == "\"" else { return s }
        return String(s.dropFirst().dropLast())
    }
}

// MARK: - Example usage (wrap in test function per your preference)
public func testTALExample() throws {
    let engine = TALEngine()
    let xml = """
    <xml xmlns:tal="http://xml.zope.org/namespaces/tal">
    <ul>
      <li tal:repeat="p in people" tal:attributes="data-index p__index">
        <a tal:attributes="href p.url; title p.name"
           tal:content="p.name">Name</a>
        <span tal:condition="p.active ? 'true' : ''">Active</span>
      </li>
      <p tal:condition="people ? true : false" tal:replace="'Total: '">X</p>
      <strong tal:content="people.count">N</strong>
    </ul>
    </xml>
    """
    let ctx: [String: Any] = [
        "people": [
            ["name": "Ada", "url": "https://example.com/ada", "active": true],
            ["name": "Linus", "url": "https://example.com/linus", "active": false],
        ],
        "people.count": 2 // optional convenience slot
    ]
    let rendered = try engine.render(xml: xml, context: ctx)
    print(rendered)
}
