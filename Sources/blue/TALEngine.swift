// TALEngineXML.swift
// TAL templating with XMLParser (no XMLDocument)
// Supports tal:content, tal:replace, tal:condition, tal:repeat, tal:attributes
// https://en.wikipedia.org/wiki/Template_Attribute_Language
import Foundation

// MARK: - Output Modifiers

public struct OutputModifier: Sendable {
    public let name: String
    public let isRaw: Bool // Flags whether this modifier disables HTML escaping
    public let transform: @Sendable (String) -> String

    public init(name: String, isRaw: Bool = false, transform: @Sendable @escaping (String) -> String) {
        self.name = name
        self.isRaw = isRaw
        self.transform = transform
    }

    func apply(to value: String) -> String {
        transform(value)
    }
}

// MARK: - Built-in Modifiers

public extension OutputModifier {
    /// No HTML escaping (for trusted content)
    static let raw = OutputModifier(name: "raw", isRaw: true) { $0 }

    /// Convert to uppercase
    static let upper = OutputModifier(name: "upper") { $0.uppercased() }

    /// Convert to lowercase
    static let lower = OutputModifier(name: "lower") { $0.lowercased() }

    /// Trim leading/trailing whitespace
    static let trim = OutputModifier(name: "trim") { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Capitalize first letter of each word
    static let capitalize = OutputModifier(name: "capitalize") { $0.capitalized }

    /// Built-in modifier registry for lookup by name
    static let builtins: [String: OutputModifier] = [
        "raw": .raw,
        "upper": .upper,
        "lower": .lower,
        "trim": .trim,
        "capitalize": .capitalize
    ]
}

// MARK: - Output Modifier Registry

public actor OutputModifierRegistry: Sendable {
    private var customModifiers: [String: OutputModifier] = [:]

    public static let shared = OutputModifierRegistry()

    private init() {}

    /// Register a custom modifier
    public func register(name: String, isRaw: Bool = false, transform: @Sendable @escaping (String) -> String) {
        let modifier = OutputModifier(name: name, isRaw: isRaw, transform: transform)
        customModifiers[name] = modifier
    }

    /// Register multiple modifiers at once
    public func register(_ modifiers: [String: OutputModifier]) {
        for (name, modifier) in modifiers {
            customModifiers[name] = modifier
        }
    }

    /// Look up a modifier by name (checks builtins first, then custom)
    public func named(_ name: String) -> OutputModifier? {
        return OutputModifier.builtins[name] ?? customModifiers[name]
    }

    /// Get all available modifier names
    public var availableNames: [String] {
        get async {
            Array(OutputModifier.builtins.keys) + Array(customModifiers.keys)
        }
    }

    /// Remove a custom modifier
    public func unregister(_ name: String) {
        customModifiers.removeValue(forKey: name)
    }

    /// Clear all custom modifiers
    public func clearCustom() {
        customModifiers.removeAll()
    }
}

// MARK: - Convenience Extensions

public extension OutputModifier {
    /// Register a custom modifier via the shared registry
    static func register(name: String, isRaw: Bool = false, transform: @Sendable @escaping (String) -> String) async {
        await OutputModifierRegistry.shared.register(name: name, isRaw: isRaw, transform: transform)
    }

    /// Look up a modifier by name via the shared registry
    static func named(_ name: String) async -> OutputModifier? {
        await OutputModifierRegistry.shared.named(name)
    }

    /// Get all available modifier names via the shared registry
    static var availableNames: [String] {
        get async {
            await OutputModifierRegistry.shared.availableNames
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
        !modifiers.contains { $0.isRaw }
    }
}

public final class TALContext {
    private var stack: [[String: Any]] = []
    public init(_ root: [String: Any] = [:]) { stack = [root] }
    public func push(_ dict: [String: Any]) { stack.append(dict) }
    public func pop() { _ = stack.popLast() }
    public subscript(_ keyPath: String) -> TALValue { TALValue(raw: resolve(keyPath)) }

    /// Evaluates an expression with pipe modifiers: "variable|modifier1|modifier2"
    public func evaluate(_ expression: String) async -> TALValue {
        let parts = expression.split(separator: "|").map(String.init)
        guard !parts.isEmpty else { return TALValue(raw: nil) }

        let variablePath = parts[0].trimmingCharacters(in: .whitespaces)
        let modifierStrings = parts.dropFirst().map { $0.trimmingCharacters(in: .whitespaces) }

        var modifiers: [OutputModifier] = []
        for modifierName in modifierStrings {
            if let modifier = await OutputModifierRegistry.shared.named(modifierName) {
                modifiers.append(modifier)
            }
        }

        let rawValue = resolve(variablePath)
        return TALValue(raw: rawValue, modifiers: modifiers)
    }

    /// Synchronous fallback for compatibility
    public func evaluate(_ expression: String) -> TALValue {
        let parts = expression.split(separator: "|").map(String.init)
        guard !parts.isEmpty else { return TALValue(raw: nil) }

        let variablePath = parts[0].trimmingCharacters(in: .whitespaces)
        let modifierStrings = parts.dropFirst().map { $0.trimmingCharacters(in: .whitespaces) }

        // Use only built-in modifiers for sync version
        let modifiers = modifierStrings.compactMap { OutputModifier.builtins[$0] }

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
    case define = "tal:define"
    case extends = "tal:extends"
    case slot = "tal:slot"
    
    /// The precedence order in which the directives are
    /// applied on a given Node (higher number = higher precedence)
    public var rank: Int {
        switch self {
            case .extends: return 10   // Highest - template inheritance
            case .define: return 9     // Define variables early
            case .condition: return 4  // Can remove element
            case .repeat_: return 3    // Can create multiple elements
            case .replace: return 2    // Replaces entire element
            case .attributes: return 1 // Modifies attributes
            case .slot: return 1       // Slot replacement (same level as attributes)
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
            case "define": self = .define
            case "extends": self = .extends
            case "slot": self = .slot
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

    /// Template resolver closure for inheritance
    public var templateResolver: ((String) -> String?)?

    public init(_ templateResolver: ((String) -> String?)? = nil) {
        self.templateResolver = templateResolver
    }

    public func render(xml: String, context: [String: Any]) throws -> String {
        do {
            let tree = try DocumentTree(xml: xml)
            let ctx = TALContext(context)
            let processed = try process(elem: tree.root, ctx: ctx) // may return nil if removed by condition
            guard let out = processed else { return "" }
            return serialize(elem: out)
        } catch {
            // If XML parsing fails, output the raw content with a debug comment
            print("⚠️  XML parsing failed, outputting raw content: \(error)")
            return """
            <!-- XML Parsing Error: \(error) -->
            <!-- Raw content follows: -->
            \(xml)
            """
        }
    }

    /// Async render with full modifier support
    public func renderAsync(xml: String, context: [String: Any]) async throws -> String {
        do {
            let tree = try DocumentTree(xml: xml)
            let ctx = TALContext(context)
            let processed = try await processAsync(elem: tree.root, ctx: ctx)
            guard let out = processed else { return "" }
            return serialize(elem: out)
        } catch {
            // If XML parsing fails, output the raw content with a debug comment
            print("⚠️  XML parsing failed, outputting raw content: \(error)")
            return """
            <!-- XML Parsing Error: \(error) -->
            <!-- Raw content follows: -->
            \(xml)
            """
        }
    }

    /// Render with template inheritance support
    public func render(template: String, context: [String: Any]) throws -> String {
        guard let templateContent = templateResolver?(template) else {
            throw DTFError(message: "Template '\(template)' not found")
        }
        // Note: render(xml:context:) now handles parse errors gracefully by returning raw content
        return try render(xml: templateContent, context: context)
    }

    /// Async render with template inheritance support
    public func renderAsync(template: String, context: [String: Any]) async throws -> String {
        guard let templateContent = templateResolver?(template) else {
            throw DTFError(message: "Template '\(template)' not found")
        }
        // Note: renderAsync(xml:context:) now handles parse errors gracefully by returning raw content
        return try await renderAsync(xml: templateContent, context: context)
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
            case .extends:
                // tal:extends - template inheritance
                return try processExtends(node: node, directive: directive, ctx: ctx)

            case .define:
                // tal:define - define local variables
                processDefine(directive: directive, ctx: ctx)

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

            case .slot:
                // tal:slot - template slot replacement
                node = processSlot(node: node, directive: directive, ctx: ctx)

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

    /// Async version with full custom modifier support
    private func processAsync(elem: some Element, ctx: TALContext) async throws -> (any Element)? {
        guard var node = elem as? DTFNode else { return elem }

        let directives = node.attributes
            .compactMap(TALDirective.init)
            .sorted(by: { $0.rank > $1.rank }) // Higher rank = higher precedence

        // Process TAL directives in order of precedence
        for directive in directives {
            switch directive.tag {
            case .extends:
                // tal:extends - template inheritance
                return try await processExtendsAsync(node: node, directive: directive, ctx: ctx)

            case .define:
                // tal:define - define local variables
                await processDefineAsync(directive: directive, ctx: ctx)

            case .condition:
                // tal:condition - may remove element entirely
                let result = await evaluateExpressionAsync(directive, ctx: ctx)
                if !result.bool {
                    return nil // Remove element
                }

            case .repeat_:
                // tal:repeat - may create multiple elements
                return try await processRepeatAsync(node: node, directive: directive, ctx: ctx)

            case .replace:
                // tal:replace - replaces entire element
                let result = await evaluateExpressionAsync(directive, ctx: ctx)
                return DTFValue(qname: QName(name: "text"), value: result.string, shouldEscape: result.shouldEscape)

            case .attributes:
                // tal:attributes - modifies attributes
                node = await processAttributesAsync(node: node, directive: directive, ctx: ctx)

            case .slot:
                // tal:slot - template slot replacement
                node = processSlot(node: node, directive: directive, ctx: ctx) // Slots don't need async

            case .content:
                // tal:content - replaces element content
                let result = await evaluateExpressionAsync(directive, ctx: ctx)
                node = DTFNode(tag: node.qname, attributes: node.attributes,
                              children: [DTFValue(qname: QName(name: "text"), value: result.string, shouldEscape: result.shouldEscape)])
            }
        }

        // If no tal:content directive, process children recursively
        if !directives.contains(where: { $0.tag == .content }) {
            var processedChildren: [any AnyDTFNode] = []
            for child in node.children {
                if let processed = try await processAsync(elem: child, ctx: ctx) {
                    processedChildren.append(processed)
                }
            }
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

    // MARK: - Template Inheritance

    private func processExtends(node: DTFNode, directive: TALDirective, ctx: TALContext) throws -> DTFNode? {
        let templateName = directive.argv.joined(separator: " ").trimmingCharacters(in: CharacterSet(charactersIn: "'\""))

        guard let templateContent = templateResolver?(templateName) else {
            throw DTFError(message: "Base template '\(templateName)' not found")
        }

        // Parse the base template
        let baseTree = try DocumentTree(xml: templateContent)

        // Collect slots from the current template
        let slots = collectSlots(from: node, ctx: ctx)

        // Add slots to context for replacement
        ctx.push(["__slots__": slots])
        defer { ctx.pop() }

        // Process the base template with slot replacements
        return try process(elem: baseTree.root, ctx: ctx) as? DTFNode
    }

    private func processDefine(directive: TALDirective, ctx: TALContext) {
        // Parse "var value; var2 value2" syntax
        let expression = directive.argv.joined(separator: " ")
        let assignments = expression.split(separator: ";")

        var definitions: [String: Any] = [:]
        for assignment in assignments {
            let parts = assignment.split(separator: " ", maxSplits: 1)
            guard parts.count == 2 else { continue }

            let varName = String(parts[0]).trimmingCharacters(in: .whitespaces)
            let expr = String(parts[1]).trimmingCharacters(in: .whitespaces)
            let value = evaluateExpression(expr, ctx: ctx)

            definitions[varName] = value.raw
        }

        if !definitions.isEmpty {
            ctx.push(definitions)
        }
    }

    private func processSlot(node: DTFNode, directive: TALDirective, ctx: TALContext) -> DTFNode {
        let slotName = directive.argv.joined(separator: " ").trimmingCharacters(in: CharacterSet(charactersIn: "'\""))

        // Check if we have slot content to replace
        if let slots = ctx["__slots__"].raw as? [String: DTFNode],
           let slotContent = slots[slotName] {
            return slotContent
        }

        // Return original node if no replacement found
        return node
    }

    private func collectSlots(from node: DTFNode, ctx: TALContext) -> [String: DTFNode] {
        var slots: [String: DTFNode] = [:]

        // Look for elements with tal:slot attribute
        func traverse(_ node: DTFNode) {
            // Check if this node defines a slot
            for attr in node.attributes {
                if attr.qname.ns == "tal" && attr.qname.name == "slot" {
                    let slotName = attr.value.trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
                    // Remove the tal:slot attribute from the collected content
                    let cleanedAttributes = node.attributes.filter { $0.qname != QName(ns: "tal", name: "slot") }
                    let slotNode = DTFNode(tag: node.qname, attributes: cleanedAttributes, children: node.children)
                    slots[slotName] = slotNode
                    return // Don't traverse children if this is a slot definition
                }
            }

            // Recursively check children
            for child in node.children {
                if let childNode = child as? DTFNode {
                    traverse(childNode)
                }
            }
        }

        traverse(node)
        return slots
    }

    // MARK: - Async Helper Methods

    private func evaluateExpressionAsync(_ directive: TALDirective, ctx: TALContext) async -> TALValue {
        let expr = directive.argv.joined(separator: " ")
        return await evaluateExpressionAsync(expr, ctx: ctx)
    }

    private func evaluateExpressionAsync(_ expr: String, ctx: TALContext) async -> TALValue {
        // Handle ternary operator: "expr ? true_val : false_val"
        if expr.contains("?") && expr.contains(":") {
            return await evaluateTernaryAsync(expr, ctx: ctx)
        }

        // Use async pipe-aware evaluation
        return await ctx.evaluate(expr.trimmingCharacters(in: .whitespaces))
    }

    private func evaluateTernaryAsync(_ expr: String, ctx: TALContext) async -> TALValue {
        let parts = expr.split(separator: "?", maxSplits: 1)
        guard parts.count == 2 else { return await ctx.evaluate(expr) }

        let condition = String(parts[0]).trimmingCharacters(in: .whitespaces)
        let rest = String(parts[1])

        let valueParts = rest.split(separator: ":", maxSplits: 1)
        guard valueParts.count == 2 else { return await ctx.evaluate(expr) }

        let trueVal = String(valueParts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
        let falseVal = String(valueParts[1]).trimmingCharacters(in: .whitespacesAndNewlines)

        let condResult = ctx[condition] // Simple lookup for condition (no modifiers needed for bool check)
        let resultExpr = condResult.bool ? trueVal : falseVal

        // Remove quotes if present and evaluate with pipe modifiers
        let cleanResult = resultExpr.trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
        return await ctx.evaluate(cleanResult)
    }

    private func processExtendsAsync(node: DTFNode, directive: TALDirective, ctx: TALContext) async throws -> DTFNode? {
        let templateName = directive.argv.joined(separator: " ").trimmingCharacters(in: CharacterSet(charactersIn: "'\""))

        guard let templateContent = templateResolver?(templateName) else {
            throw DTFError(message: "Base template '\(templateName)' not found")
        }

        // Parse the base template
        let baseTree = try DocumentTree(xml: templateContent)

        // Collect slots from the current template
        let slots = collectSlots(from: node, ctx: ctx)

        // Add slots to context for replacement
        ctx.push(["__slots__": slots])
        defer { ctx.pop() }

        // Process the base template with slot replacements
        return try await processAsync(elem: baseTree.root, ctx: ctx) as? DTFNode
    }

    private func processDefineAsync(directive: TALDirective, ctx: TALContext) async {
        // Parse "var value; var2 value2" syntax
        let expression = directive.argv.joined(separator: " ")
        let assignments = expression.split(separator: ";")

        var definitions: [String: Any] = [:]
        for assignment in assignments {
            let parts = assignment.split(separator: " ", maxSplits: 1)
            guard parts.count == 2 else { continue }

            let varName = String(parts[0]).trimmingCharacters(in: .whitespaces)
            let expr = String(parts[1]).trimmingCharacters(in: .whitespaces)
            let value = await evaluateExpressionAsync(expr, ctx: ctx)

            definitions[varName] = value.raw
        }

        if !definitions.isEmpty {
            ctx.push(definitions)
        }
    }

    private func processRepeatAsync(node: DTFNode, directive: TALDirective, ctx: TALContext) async throws -> DTFNode? {
        // Parse "var in collection" syntax from expression
        let expression = directive.argv.joined(separator: " ")
        let parts = expression.split(separator: " in ", maxSplits: 1)
        guard parts.count == 2 else { return node }

        let varName = String(parts[0]).trimmingCharacters(in: .whitespaces)
        let collectionExpr = String(parts[1]).trimmingCharacters(in: .whitespaces)

        let collection = await evaluateExpressionAsync(collectionExpr, ctx: ctx)
        guard let array = collection.raw as? [Any] else { return node }

        // Create repeated elements
        var results: [any AnyDTFNode] = []

        // WARNING: MUST remove the repeat to avoid infinite recursion
        var step = node
        step.removeAttribute(named: "tal:repeat")

        for (index, item) in array.enumerated() {
            ctx.push([varName: item, "\(varName)__index": index])
            if let processed = try await processAsync(elem: step, ctx: ctx) {
                results.append(processed)
            }
            ctx.pop()
        }

        // Return a container with all repeated elements
        return DTFNode(tag: QName(name: "repeat-container"), attributes: [], children: results)
    }

    private func processAttributesAsync(node: DTFNode, directive: TALDirective, ctx: TALContext) async -> DTFNode {
        var newAttributes = node.attributes.filter { $0.qname.ns != "tal" }

        if let targetAttr = directive.targetAttribute {
            // Handle tal:_attributeName="expression" pattern
            let result = await evaluateExpressionAsync(directive, ctx: ctx)
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
                let value = await evaluateExpressionAsync(expr, ctx: ctx)

                newAttributes.append(DTFValue(qname: QName(name: attrName), value: value.string, shouldEscape: value.shouldEscape))
            }
        }

        return DTFNode(tag: node.qname, attributes: newAttributes, children: node.children)
    }

    private func serialize(elem: any Element) -> String {
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
            let attrName = attr.qname.name  // Use local name only for HTML output
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
