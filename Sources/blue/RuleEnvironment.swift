//
//  Rule.swift
//  BobiBuilder
//
//  Created by Jason Jobe on 8/29/25.
//

import Foundation

public protocol RuleEnvironmentKey {
    associatedtype Value
    static var defaultValue: Value { get }
}

extension RuleEnvironmentKey {
    static var id: ObjectIdentifier { ObjectIdentifier(Self.Value.self) }
}

public struct EnvironmentValues {
    var userDefined: [ObjectIdentifier:Any] = [:]

    public subscript<Key: RuleEnvironmentKey>(key: Key.Type = Key.self) -> Key.Value {
        get { userDefined[Key.id] as? Key.Value ?? Key.defaultValue }
        set { userDefined[Key.id] = newValue }
    }
}

struct EnvironmentModifier<A, Content: Rule>: Builtin {
    
    init(content: Content, keyPath: WritableKeyPath<EnvironmentValues, A>, modify: @escaping (inout A) -> ()) {
        self.content = content
        self.keyPath = keyPath
        self.modify = modify
    }
    
    var content: Content
    var keyPath: WritableKeyPath<EnvironmentValues, A>
    var modify: (inout A) -> ()
    
    func run(environment: EnvironmentValues) throws {
        var copy = environment
        modify(&copy[keyPath: keyPath])
        try content.builtin.run(environment: copy)
    }
}

public extension Rule {
    func environment<A>(keyPath: WritableKeyPath<EnvironmentValues, A>, value: A) -> some Rule {
        EnvironmentModifier(content: self, keyPath: keyPath, modify: { $0 = value })
    }
    
    func modifyEnvironment<A>(keyPath: WritableKeyPath<EnvironmentValues, A>, modify: @escaping (inout A) -> ()) -> some Rule {
        EnvironmentModifier(content: self, keyPath: keyPath, modify: modify )
    }
}

extension EnvironmentValues {
    func install<A>(on: A) {
        let m = Mirror(reflecting: on)
        for child in m.children {
            if let e = child.value as? SetEnvironment {
                e.set(environment: self)
            }
        }
    }
}

@propertyWrapper
class Box<A> {
    var wrappedValue: A
    init(wrappedValue: A) {
        self.wrappedValue = wrappedValue
    }
}

protocol SetEnvironment {
    func set(environment: EnvironmentValues)
}

@propertyWrapper
public struct Environment<Value>: SetEnvironment {
    var keyPath: KeyPath<EnvironmentValues, Value>
    @Box fileprivate var values: EnvironmentValues?
    
    public init(_ keyPath: KeyPath<EnvironmentValues, Value>) {
        self.keyPath = keyPath
    }
    
    public var wrappedValue: Value? {
        values![keyPath: keyPath]
    }
    
    func set(environment: EnvironmentValues) {
        values = environment
    }
}
