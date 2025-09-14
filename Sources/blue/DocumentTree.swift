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
        let doc = try XMLDocument(xmlString: xml, options: [.nodePreserveAll, .nodeCompactEmptyElement])
        try self.init(xmlDocument: doc)
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
        attributes.remove(at: ndx)
    }

    func replace(attribute: DTFValue, with newValue: DTFValue) {
        let ndx = attributes.firstIndex(of: attribute)
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
