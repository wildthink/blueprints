//
//  OCXMLNode.swift
//  3rdspace-server
//
//  Created by Jason Jobe on 9/13/25.
//
// https://github.com/arennow/CLFXMLDocument/blob/main/README.md

import Foundation

public protocol OCXMLNode: Sendable {
    var XML: String { get }
}

public protocol OCXMLContainer: OCXMLNode {
    var childNodes: [any OCXMLNode] { get }
}

public struct OCXMLDocument: OCXMLContainer {
    public let documentElement: OCXMLElement
    public var childNodes: [any OCXMLNode] { [documentElement] }
    public var XML: String { documentElement.documentXML }
    
    public init(_ rootElement: OCXMLElement) {
        documentElement = rootElement
    }
}

public protocol XMLAttributeValue: Sendable, Hashable {
}

extension String: XMLAttributeValue {}

public typealias XMLAttributesPairs =  KeyValuePairs<String, any XMLAttributeValue>

public struct XMLAttributes: Sendable, Hashable {
    
    var values: [String: any XMLAttributeValue]

    public var isEmpty: Bool { values.isEmpty }
    
    public subscript(key: String) -> (any XMLAttributeValue)? {
        get { values[key] }
        set { values[key] = newValue }
    }
    
    public subscript<V: XMLAttributeValue>(key: String, as vt: V.Type = V.self) -> V? {
        values[key] as? V
    }

    public static func == (lhs: XMLAttributes, rhs: XMLAttributes) -> Bool {
        lhs.hashValue == rhs.hashValue
    }
    
    private func normalize() -> XMLAttributes {
        values.reduce(XMLAttributes()) {
            var d = $0
            d[$1.key.lowercased()] = $1.value
            return d
        }
    }

    var xmlString: String {
        guard !values.isEmpty
        else { return "" }
        func xencode<V>(_ val: V) -> String {
            String(describing: val).ocXMLEntityEncoded
        }
        return values.map { xencode($0) + "=" + xencode($1) }
                        .joined(separator: " ")
    }

    public func hash(into hasher: inout Hasher) {
        for (k, v) in values {
            hasher.combine(k)
            hasher.combine(v)
        }
    }
}

extension XMLAttributes: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, any XMLAttributeValue)...) {
        values = .init(uniqueKeysWithValues: elements)
    }
}

public struct OCXMLElement: OCXMLNode, OCXMLContainer {
    public let name: String
    public let childNodes: [any OCXMLNode]
    private let attributes: XMLAttributes
    fileprivate let normalizedName: String
    
    public init(_ name: String, attributes: XMLAttributes = [:], @OCXMLBuilder childNodes: () -> [any OCXMLNode] = { [] }) {
        self.init(name, attributes: attributes, childNodes: childNodes())
    }

    public init(_ name: String, attributes: XMLAttributes = [:], childNodes: [any OCXMLNode]) {
        self.name = name
        self.normalizedName = name.normalizeName
        self.attributes = attributes //.normalizedAttributes()
        self.childNodes = childNodes
    }

    public func attribute(_ attributeName: String) -> (any XMLAttributeValue)? { attributes[attributeName.normalizeName] }

    public var documentXML: String { "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n\(XML)" }

    public var XML: String {
        var xml = "<\(name)"
        
        if !attributes.isEmpty {
            xml += " " + attributes.xmlString
        }
        
        // content
        let encodedChildren = childNodes.map { $0.XML }.joined()
        if !encodedChildren.isEmpty {
            xml += ">\(encodedChildren)</\(name)>"
        } else {
            xml += "/>"
        }
        
        return xml
    }
}

fileprivate extension String {
    var normalizeName: String { self.lowercased() }

    var ocXMLEntityEncoded: String {
        var xml = replacingOccurrences(of: "&" , with: "&amp;",  options: .literal)
        xml = xml.replacingOccurrences(of: "<" , with: "&lt;",   options: .literal)
        xml = xml.replacingOccurrences(of: ">" , with: "&gt;",   options: .literal)
        xml = xml.replacingOccurrences(of: "\"", with: "&quot;", options: .literal)
        xml = xml.replacingOccurrences(of: "'" , with: "&apos;", options: .literal)
        xml = xml.replacingOccurrences(of: "\n", with: "&#10;",  options: .literal)
        return xml
    }
}

// Strings are used as children directly for text (instead of having separate Text nodes)
extension String: OCXMLNode {
    public var XML: String { ocXMLEntityEncoded }
    public var textValue: String { self }
}

public struct OCXMLDocumentFragment: OCXMLContainer {
    public var childNodes: [any OCXMLNode]
    public var XML: String { childNodes.map { $0.XML }.joined() }
}

@resultBuilder
public struct OCXMLBuilder {
    public static func buildBlock(_ components: any OCXMLNode...) -> [any OCXMLNode]    { components }
    public static func buildEither(first components: [any OCXMLNode]) -> any OCXMLNode  { OCXMLDocumentFragment(childNodes: components) }
    public static func buildEither(second components: [any OCXMLNode]) -> any OCXMLNode { OCXMLDocumentFragment(childNodes: components) }
    public static func buildArray(_ components: [[any OCXMLNode]]) -> any OCXMLNode     { OCXMLDocumentFragment(childNodes: components.flatMap { $0 }) }
    public static func buildExpression(_ expression: any OCXMLNode) -> any OCXMLNode    { OCXMLDocumentFragment(childNodes: [expression]) }
    public static func buildExpression(_ expression: [any OCXMLNode]) -> any OCXMLNode  { OCXMLDocumentFragment(childNodes: expression) }
    public static func buildOptional(_ components: [any OCXMLNode]?) -> any OCXMLNode   { OCXMLDocumentFragment(childNodes: components ?? []) }
}


// MARK: - Optional add-on: Querying

public extension OCXMLNode {
    var textValue: String {
        if let string = self as? String { string }
        else if let container = self as? OCXMLContainer { container.childNodes.map { ($0 as? String) ?? "" }.joined() }
        else { "" }
    }
}

public extension OCXMLElement {
    fileprivate func attribute(normalizedAttributeName: String) -> (any XMLAttributeValue)? { attributes[normalizedAttributeName] }
}

public extension OCXMLContainer {
    var childElements: [OCXMLElement] { childNodes.compactMap { $0 as? OCXMLElement } }

    var allDescendants: [OCXMLElement] {
        childElements + childElements.flatMap { $0.allDescendants }
    }

    func childElements(named elementName: String) -> [OCXMLElement] {
        let normalizedName = elementName.normalizeName
        return childElements.filter { $0.normalizedName == normalizedName }
    }

    func firstChild(named elementName: String) -> OCXMLElement? { childElements(named: elementName).first }

    func allDescendants(named elementName: String) -> [OCXMLElement] {
        let normalizedName = elementName.normalizeName
        return allDescendants.filter { $0.normalizedName == normalizedName }
    }
    
    func allDescendantAttributeValues(named attributeName: String) -> [any XMLAttributeValue] {
        let normalizedName = attributeName.normalizeName
        return allDescendants.compactMap { $0.attribute(normalizedAttributeName: normalizedName) }
    }
    
    var textValue: String { childNodes.map { ($0 as? String) ?? "" }.joined() }

}


// MARK: - Optional add-on: XML parsing
// A VERY simple parser that doesn't support namespaces and performs no real error handling.

public extension OCXMLDocument {
    init?(xml: String) {
        guard let data = xml.data(using: .utf8) else { return nil }
        let delegate = OCXMLParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        
        guard let rootElement = delegate.xmlNode as? OCXMLElement else { return nil }
        documentElement = rootElement
    }
}

fileprivate class OCXMLReadingNode {
    fileprivate enum NodeType {
        case element(name: String, attributes: XMLAttributes)
        case text(content: String)
    }

    let type: NodeType
    var childNodes: [OCXMLReadingNode] = []
    weak var parentNode: OCXMLReadingNode? = nil
    
    init(text: String) { self.type = .text(content: text) }
    init(name: String, attributes: XMLAttributes) { self.type = .element(name: name, attributes: attributes) }
    
    var xmlNode: any OCXMLNode {
        switch type {
            case .element(let name, let attributes): OCXMLElement(name, attributes: attributes, childNodes: childNodes.map { $0.xmlNode })
            case .text(let content): content
        }
    }
}

fileprivate class OCXMLParserDelegate : NSObject, XMLParserDelegate {
    private var rootElement: OCXMLReadingNode? = nil
    private var inProgressElement: OCXMLReadingNode? = nil
    
    var xmlNode: (any OCXMLNode)? { rootElement?.xmlNode }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String:String] = [:]) {
        let newElement = OCXMLReadingNode(
            name: elementName,
            attributes: .init(values: attributeDict))
        newElement.parentNode = inProgressElement
        inProgressElement?.childNodes.append(newElement)
        self.inProgressElement = newElement
        if rootElement == nil { rootElement = newElement }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        inProgressElement = inProgressElement?.parentNode
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        inProgressElement?.childNodes.append(OCXMLReadingNode(text: string))
    }
}

// MARK: Foundation XML

//@resultBuilder
//public struct XMLBuilder {
//    public typealias Element = XMLElement
//    
//    public static func buildBlock(_ components: Element...) -> [ Element]    { components }
//    public static func buildEither(first components: [ Element]) -> Element  { Element }
//    public static func buildEither(second components: [ Element]) -> Element { XMLDocumentFragment(childNodes: components as! [XMLNode]) }
//    public static func buildArray(_ components: [[ Element]]) -> Element     { XMLDocumentFragment(childNodes: components.flatMap { $0 }) }
//    public static func buildExpression(_ expression: Element) -> Element    { XMLDocumentFragment(childNodes: [expression]) }
//    public static func buildExpression(_ expression: [ Element]) -> Element  { XMLDocumentFragment(childNodes: expression as! [XMLNode]) }
//    public static func buildOptional(_ components: [ Element]?) -> Element   { XMLDocumentFragment(childNodes: components ?? []) }
//}
