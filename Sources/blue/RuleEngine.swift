//
//  RuleEngine.swift
//  Foundry
//
//  Created by Jason Jobe on 7/31/25.
//

protocol BuiltinRule<Scope> {
    associatedtype Scope
    associatedtype Body: Rule
    func resolve(in: Scope) throws
}
typealias Builtin = BuiltinRule & Rule


/**
 The `RuleEngine` provides the context for resolving the `Rule`
 graph into a sequence of Lowest level "Builtin" rules. These Builtins
 specifiy values to be evaluated and output (or rendered). The Engine
 provides the implementation to evalute and output/render.
 */
public struct RuleEngine<S> {
    typealias Scope = S
    var scope: Scope
    
    /// Inject @Envirornment-like values before the
    /// body is evaluated
    func prepare(_ rule: any Rule) {
        
    }
    
    public func resolveBody(_ node: any Rule) throws -> any Rule {
        try resolveBody(node, in: scope)
    }
    
    func resolveBody(_ node: any Rule, in env: Scope) throws -> any Rule {
        // If node already type-erased, return as is
        // Builtin ?
        
        if let bob = node as? any BuiltinRule<Scope> {
            try bob.resolve(in: env)
            return EmptyRule()
        }
        
        // If the node has no body (leaf node)
        if node.isLeaf {
            return node
        }
        
        // If it's a GroupNode, recursively resolve its children
        if let group = node as? GroupRule {
            let resolvedChildren = try group.children.map {
                $0.isLeaf ? $0 : try resolveBody($0.body, in: env)
            }
            return GroupRule(resolvedChildren)
        }
        return try resolveBody(node.body, in: env)
    }
}
