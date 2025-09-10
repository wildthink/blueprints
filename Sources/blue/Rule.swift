//
//  Rule.swift
//  BobiBuilder
//
//  Created by Jason Jobe on 8/29/25.
//

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

extension Optional: Rule where Wrapped: Rule {
//    public typealias Body = Never
}

extension Never: Rule {
    public typealias Body = Never
}

extension Rule where Body == Never {
    public var body: Never {
        fatalError("init(body:) has not been implemented")
    }
}

public struct RuleArray: Builtin {
    public func run(environment: EnvironmentValues) throws {
        for el in elements {
            try el.builtin.run(environment: environment)
        }
    }
    
    var elements: [any Rule]
    public init(elements: [any Rule]) {
        self.elements = elements
    }
    
    public init(_ element: any Rule) {
        self.elements = [element]
    }
    
    public mutating func append(_ item: any Rule) {
        if let ra = item as? RuleArray {
            self.append(contentsOf: ra)
        } else {
            self.elements.append(item)
        }
    }

    public mutating func append<R: Rule>(_ item: R) {
        append(item as any Rule)
    }

    public mutating func append(contentsOf other: RuleArray) {
        self.elements.append(contentsOf: other.elements)
    }
}

@resultBuilder
public struct RuleBuilder {
    public typealias RuleCollection = RuleArray
    
    public static func buildBlock() -> RuleCollection {
        RuleCollection(elements: [])
    }
    
    @inlinable
    public static func buildPartialBlock(first: some Rule) -> RuleCollection {
        RuleCollection(first)
    }

    @inlinable
    public static func buildPartialBlock(first: RuleCollection) -> RuleCollection {
        first
    }
    
    public static func buildPartialBlock<R: Rule>(accumulated: RuleCollection, next: R) -> RuleCollection {
        var accumulated = accumulated
        accumulated.append(next)
        return accumulated
    }
    
    public static func buildArray(_ components: [RuleCollection]) -> RuleCollection {
        var result = RuleCollection(elements: [])
        for c in components {
            result.append(contentsOf: c)
        }
        return result
    }
    
    @inlinable
    public static func buildEither(first component: RuleCollection) -> RuleCollection {
        component
    }
    
    @inlinable
    public static func buildEither(second component: RuleCollection) -> RuleCollection {
        component
    }
    
    // Wrap a single Rule element into a RuleArray
    @inlinable
    public static func buildExpression<R: Rule>(_ component: R) -> RuleCollection {
        RuleCollection(component)
    }
    
    // Pass-through when the expression already is a RuleArray
    @inlinable
    public static func buildExpression(_ component: RuleCollection) -> RuleCollection {
        component
    }
    
    @inlinable
    public static func buildLimitedAvailability(_ component: RuleCollection) -> RuleCollection {
        component
    }
    
    public static func buildOptional(_ component: RuleCollection?) -> RuleCollection {
        component ?? RuleCollection(elements: [])
    }
}

// MARK: Builtin

extension Rule {
    var builtin: any BuiltinRule {
        (self as? BuiltinRule) ?? AnyBuiltin(self)
    }
}

public protocol BuiltinRule {
    func run(environment: EnvironmentValues) throws
}

public typealias Builtin = BuiltinRule & Rule


public struct AnyBuiltin: Builtin {
    let _run: (EnvironmentValues) throws -> ()
    
    public init<R: Rule>(_ value: R) {
        self._run = { env in
            env.install(on: value)
            try value.body.builtin.run(environment: env)
        }
    }

    public init(any value: any Rule) {
        if let b = value as? any Builtin {
            self._run = { try b.run(environment: $0) }
        } else {
            self._run = { env in
                env.install(on: value)
                try value.body.builtin.run(environment: env)
            }
        }
    }

    public func run(environment: EnvironmentValues) throws {
        try _run(environment)
    }
}

