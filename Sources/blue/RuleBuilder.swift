//
//  Rule.swift
//  NewRules
//
//  Created by Jason Jobe on 7/31/25.
//
import Foundation

/**
 
 A `Rule` is defined similar to Views such that you can use the
 `RuleBuilder` to compose Rules using the `@resultBuilder`
 syntax. All the flow constructs are supported including `switch` and
 `for loops`.
 
 Depending on your context you can extend acceptance of your particular types.

 ```
    extension Double: LiteralRule {}
    extension Date: LiteralRule {}
    extension String: LiteralRule {}

    struct AnyRule: Rule {
        var value: Any?
    }
 
    extension RuleBuilder {
        public static func buildExpression<A>(_ expression: A) -> some Rule {
            AnyRule(value: expression)
        }
    }
 
 ```
*/

public protocol Rule<Body> {
    associatedtype Body: Rule = Never
    @RuleBuilder var body: Body { get }
}

public struct EmptyRule: Rule {}
extension Never: Rule {}

extension Rule where Body == Never {
    public var body: Never {
        fatalError("init(body:) has not been implemented")
    }
}

public struct GroupRule: Rule {
    public var children: [any Rule]
    public init(_ children: (any Rule)...) {
        self.children = children
    }
    public init(_ children: [any Rule]) {
        self.children = children
    }

    /// WARNING: Rules are NOT resolved in any way
    public func flattened() -> [any Rule] {
        var list: [any Rule] = []
        for kid in children {
            if let group = kid as? GroupRule {
                list.append(contentsOf: group.flattened())
            } else {
                list.append(kid)
            }
        }
        return list
    }
}

public extension Rule {
    var isLeaf: Bool {
        return type(of: self).Body == Never.self
    }
}

public protocol LiteralRule: Rule {}
extension Optional: Rule where Wrapped: Rule {}

@resultBuilder
public enum RuleBuilder {
    
    public static func buildBlock<each Content: Rule>(_ rules: repeat each Content) -> GroupRule {
        var av: [any Rule] = []
        for rule in repeat (each rules) {
            av.append(rule)
        }
        return GroupRule(av)
    }
    
    // MARK: Rule from Expression
    public static func buildExpression<R: Rule>(_ exp: R) -> some Rule {
        exp
    }
    
    // Optionals - Do we also need "-> (some Rule)??
    public static func buildExpression<R: Rule>(_ exp: R?) -> (some Rule)? {
        exp
    }

    // Empty Rule
    public static func buildRule() -> some Rule { Optional<EmptyRule>.none }
    
    // Empty partial Rule. Useful for switch cases to represent no Rules.
    public static func buildPartialBlock(first: Void) -> some Rule {
        Optional<EmptyRule>.none
    }
    
    // Rule for an 'if' condition.
    public static func buildIf<Content>(_ content: Content?
    ) -> Content? where Content : Rule {
        content
    }
    
    // Rule for an 'if' condition which also have an 'else' branch.
    public static func buildEither<R: Rule>(first rule: R) -> R {
        rule
    }
    
    // Rule for the 'else' branch of an 'if' condition.
    public static func buildEither<R: Rule>(second rule: R) -> R {
        rule
    }
    
    // DO NOT USE: Useful for 'for' loops BUT see above NOTE
//    public static func buildArray(_ components: [any Rule]) -> GroupRule {
//        GroupRule(components.compactMap(\.self))
//    }
    public static func buildArray(_ components: [any Rule]) -> GroupRule {
        GroupRule(components.compactMap(\.self))
    }

}

// MARK: Pretty Print
public extension Rule {
    func prettyPrint(indent: String = "", isLast: Bool = true) -> String {
        if let group = self as? GroupRule {
            group.prettyPrint(indent: indent, isLast: isLast)
        } else if let seq = self as? (any Collection<any Rule>) {
            seq.prettyPrint(indent: indent, isLast: isLast)
        } else if let lit = self as? any LiteralRule {
            lit.prettyPrint(indent: indent, isLast: isLast)
        } else {
            defaultPrint(indent: indent, isLast: isLast)
        }
    }
    
    func defaultPrint(indent: String = "", isLast: Bool = true) -> String {
        let branch = isLast ? "└── " : "├── "
        var result = indent + branch
        result += String(describing: self)
        result += "\n"
        return result
    }
}

public extension Collection where Element == any Rule {
    func prettyPrint(name: String = "Bag", indent: String = "", isLast: Bool = true) -> String {
        let branch = isLast ? "└── " : "├── "
        var result = indent + branch
        
        result += "\(name)\n"
        let newIndent = indent + (isLast ? "    " : "│   ")
        for (index, child) in self.enumerated() {
            let last = index == self.count - 1
            result += child.prettyPrint(indent: newIndent, isLast: last)
        }
        return result
    }
}

public extension GroupRule {
    func prettyPrint(indent: String = "", isLast: Bool = true) -> String {
        let branch = isLast ? "└── " : "├── "
        var result = indent + branch
        
        let flat = self.flattened()
        let str = flat.prettyPrint(name: "Group", indent: indent, isLast: isLast)
        result += str
        return result
    }
}
public extension LiteralRule {
    func prettyPrint(indent: String = "", isLast: Bool = true) -> String {
        let branch = isLast ? "└── " : "├── "
        var result = indent + branch
        result += String(describing: self)
        result += "\n"
        return result
    }
}
