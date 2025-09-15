//
//  File.swift
//  Blueprints
//
//  Created by Jason Jobe on 9/14/25.
//

import Foundation

/*
 Return Value
 The MIME type for the receiver (for example, “text/xml”).
 Discussion
 MIME types are assigned by IANA
 see http://www.iana.org/assignments/media-types/index.html
 */

public struct DocumentTree {
    public var qname: QName
    public var namespace: [String: String]?
    public var attributes: [DTFValue]
    public var root: any AnyDTFNode
}

public typealias MimeType = String

public extension DocumentTree {

    init (xmlDocument: XMLDocument) throws {
        guard let rootEl = xmlDocument.rootElement(),
            let rootNode = rootEl.toDTFNode() as? DTFNode
        else {
            throw DTFError(message: "XMLDocument has no root element or root is not an element")
        }
        self.qname = rootNode.qname
        self.attributes = rootNode.attributes
        self.root = rootNode
    }

    init (xml: String) throws {
        // Try to parse as-is first
        var xmlString = xml
        do {
            let doc = try XMLDocument(xmlString: xmlString, options: [.nodePreserveAll, .nodeCompactEmptyElement])
            try self.init(xmlDocument: doc)
            return
        } catch {
            // If parsing fails, try to fix common XML issues
            xmlString = try Self.fixXMLIssues(xml)
        }

        // Try again with namespace fixes
        let doc = try XMLDocument(xmlString: xmlString, options: [.nodePreserveAll, .nodeCompactEmptyElement])
        try self.init(xmlDocument: doc)
    }

    /// Attempts to fix common XML issues to make parsing more forgiving
    private static func fixXMLIssues(_ xml: String) throws -> String {
        var result = addMissingNamespaces(to: xml)
        result = fixUnclosedTags(result)
        return result
    }

    /// Attempts to add missing TAL namespace declarations to make XML parsing more forgiving
    private static func addMissingNamespaces(to xml: String) -> String {
        var result = xml

        // Check if TAL namespace is already declared
        let hasXmlnsTal = result.contains("xmlns:tal=")

        // If we find tal: attributes but no namespace declaration, add it
        if !hasXmlnsTal && result.contains("tal:") {
            // For fragments, wrap in a root element with the namespace
            if !result.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<?xml") {
                result = "<div xmlns:tal=\"http://xml.zope.org/namespaces/tal\">\n\(result)\n</div>"
            } else {
                // For full documents, try to add to the first tag with tal: attributes
                if let range = result.range(of: #"<[^>]*\btal:"#, options: .regularExpression) {
                    // Find the opening tag that contains this tal: attribute
                    let startIndex = result[..<range.lowerBound].lastIndex(of: "<") ?? range.lowerBound
                    if let endIndex = result[range.lowerBound...].firstIndex(of: ">") {
                        let tagRange = startIndex..<endIndex
                        let tagContent = String(result[tagRange])

                        // Insert the namespace declaration into this tag
                        if let spaceIndex = tagContent.firstIndex(of: " ") {
                            let tagName = String(tagContent[tagContent.index(after: tagContent.startIndex)..<spaceIndex])
                            let restOfTag = String(tagContent[spaceIndex...])
                            let newTag = "<\(tagName) xmlns:tal=\"http://xml.zope.org/namespaces/tal\"\(restOfTag)"
                            result.replaceSubrange(tagRange, with: newTag)
                        }
                    }
                }
            }
        }

        return result
    }

    /// Fixes common unclosed tag issues
    private static func fixUnclosedTags(_ xml: String) -> String {
        var result = xml

        // Fix unclosed <br> tags - replace with self-closing
        result = result.replacingOccurrences(
            of: #"<br\b([^>]*)>(?!</br>)"#,
            with: "<br$1/>",
            options: .regularExpression
        )

        // Fix unclosed <input> tags - replace with self-closing
        result = result.replacingOccurrences(
            of: #"<input\b([^>]*)>(?!</input>)"#,
            with: "<input$1/>",
            options: .regularExpression
        )

        // Fix unclosed <img> tags - replace with self-closing
        result = result.replacingOccurrences(
            of: #"<img\b([^>]*)>(?!</img>)"#,
            with: "<img$1/>",
            options: .regularExpression
        )

        // Fix HTML boolean attributes (required, checked, etc.) to have explicit values
        let booleanAttrs = ["required", "checked", "selected", "disabled", "readonly", "multiple", "autofocus"]
        for attr in booleanAttrs {
            result = result.replacingOccurrences(
                of: #"\b\#(attr)\b(?!=)"#,
                with: "\(attr)=\"\(attr)\"",
                options: .regularExpression
            )
        }

        return result
    }

    /// Converts the DocumentTree back to an XMLDocument for pretty-printing or further processing
    func toXMLDocument(prettyPrint: Bool = true) -> XMLDocument {
        let xmlDoc = XMLDocument()
        if let rootElement = dtfNodeToXMLElement(self.root) {
            xmlDoc.setRootElement(rootElement)
        }

        if prettyPrint {
            xmlDoc.characterEncoding = "UTF-8"
            xmlDoc.isStandalone = true
        }

        return xmlDoc
    }

    /// Converts the DocumentTree to a pretty-printed XML string
    func toPrettyXML() -> String {
        let xmlDoc = toXMLDocument(prettyPrint: true)
        return xmlDoc.xmlString(options: [.nodePrettyPrint, .nodeCompactEmptyElement])
    }

    /// Converts the DocumentTree to a compact XML string
    func toXML() -> String {
        let xmlDoc = toXMLDocument(prettyPrint: false)
        return xmlDoc.xmlString(options: [.nodeCompactEmptyElement])
    }
}

private extension DocumentTree {
    /// Recursively converts a DTFNode back to an XMLElement
    func dtfNodeToXMLElement(_ node: any AnyDTFNode) -> XMLElement? {
        if let dtfNode = node as? DTFNode {
            let element = XMLElement(name: dtfNode.qname.name)

            // Set namespace if present
            if let ns = dtfNode.qname.ns {
                element.addNamespace(XMLNode.namespace(withName: ns, stringValue: "http://xml.zope.org/namespaces/\(ns)") as! XMLNode)
            }

            // Add attributes
            for attr in dtfNode.attributes {
                let xmlAttr = XMLNode.attribute(withName: attr.qname.description, stringValue: attr.value) as! XMLNode
                element.addAttribute(xmlAttr)
            }

            // Add children
            for child in dtfNode.children {
                if let childElement = dtfNodeToXMLElement(child) {
                    element.addChild(childElement)
                } else if let textNode = child as? DTFValue, textNode.qname.name == "text" {
                    element.addChild(XMLNode.text(withStringValue: textNode.value) as! XMLNode)
                }
            }

            return element
        }
        return nil
    }
}

struct DTFError: Error {
    var message: String
    // TODO: Capture #file, #line
}

// MARK: QName - Fully qualified name
/// Fully qualified Name
public struct QName: Sendable, Codable, Hashable, Equatable,
            ExpressibleByStringLiteral, CustomStringConvertible {
    public var ns: String?
    public var name: String
    public var description: String {
        if let ns { "\(ns):\(name)" } else { name }
    }
    
    public init(ns: String? = nil, name: String) {
        self.ns = ns
        self.name = name
    }
    
    public init(stringLiteral value: String) {
        let parts = value.split(separator: ":")
        ns = parts.count == 2 ? String(parts[0]) : nil
        name = parts.last?.description ?? value
    }
    
    public init(_ value: String) {
        self = .init(stringLiteral: value)
    }
}

public extension QName {
    static var never: QName {
        .init(ns: nil, name: "")
    }
    
    static var unknown: QName {
        .init(ns: "unknown", name: "unknown")
    }
}

public protocol AnyDTFNode<Value>: Sendable {
    associatedtype Value = Sendable
    var qname: QName { get }
    var attributes: [DTFValue] { get }
    var mimeType: MimeType { get }
    var value: Value { get }
}

public extension AnyDTFNode {
    var mimeType: MimeType { "unknown/unknown" }
    var attributes: [DTFValue] { [] }
}

extension Never: AnyDTFNode {
    public var qname: QName { .never }
    public var value: Never { Optional<Never>.none! }
}

public struct DTFValue: AnyDTFNode, Equatable {
    public typealias Value = String
    public var qname: QName
    public var value: Value
    public var shouldEscape: Bool

    public init(qname: QName, value: Value, shouldEscape: Bool = true) {
        self.qname = qname
        self.value = value
        self.shouldEscape = shouldEscape
    }
}

extension DTFValue {
   public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.qname == rhs.qname // && lhs.value == rhs.value
    }
}

public struct DTFNode: AnyDTFNode {
    public var qname: QName
    public var attributes: [DTFValue]
    public var value: [any AnyDTFNode]
    public var children: [any AnyDTFNode] { value }
    
    public init(
        tag: QName,
        attributes: [DTFValue]?,
        children: [any AnyDTFNode]?
    ) {
        self.qname = tag
        self.attributes = attributes ?? []
        self.value = children ?? []
    }
    
    mutating func removeAttribute(named: String) {
        guard let ndx = attributes.firstIndex(where: { $0.qname == named })
        else { return }
//        attributes.removeAll { DTFValue in
//            <#code#>
//        }
        attributes.remove(at: ndx)
    }

    mutating func replace(attribute: DTFValue, with newValue: DTFValue) {
        attributes.replace([attribute], with: [newValue])
    }
}

extension QName {
    static func == (lhs: Self, rhs: String) -> Bool {
        guard !rhs.isEmpty else { return false }
        return lhs.description == rhs
    }
}

private extension XMLNode {
    @_disfavoredOverload
    func toDTFNode() -> (any AnyDTFNode)? {
        // Handle text nodes
        if self.kind == .text {
            guard let textValue = self.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !textValue.isEmpty else { return nil }
            return DTFValue(qname: QName(name: "text"), value: textValue, shouldEscape: true)
        }

        // Handle element nodes
        guard let name = self.name else { return nil }
        let qname = QName(name: name)

        let attrs = (self as? XMLElement)?.attributes?.compactMap { attr in
            return DTFValue(qname: QName(attr), value: attr.stringValue ?? "", shouldEscape: true)
        }
        let kids = self.children?.compactMap { $0.toDTFNode() }
        return DTFNode(tag: qname, attributes: attrs, children: kids)
    }
}

private extension QName {
    init (_ attr: XMLNode) {
        let local = attr.localName ?? attr.name ?? ""
        let nsURI = attr.prefix // We want the short ns NOT attr.uri
        self = QName(ns: nsURI, name: local)
    }
}
