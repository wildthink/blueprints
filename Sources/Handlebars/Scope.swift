//
//  Scope.swift
//  Handlebars
//
//  Created by Jason Jobe on 8/25/25.
//


public struct AnyValue {}

struct Scope {
    subscript(_ key: String) -> [AnyValue] {
        get { [] }
        set { }
    }
}

struct Expression {
    let _eval: (inout Scope, inout String) throws -> Void

    func eval(in env: inout Scope, output: inout String) throws {
        try _eval(&env, &output)
    }
}

struct HBError: Error {
    var msg: String
    var file: String
    var line: Int
    
    init(msg: String, file: String = #fileID, line: Int = #line) {
        self.msg = msg
        self.file = file
        self.line = line
    }
}

extension Expression {
    
    static func output<S: StringProtocol>(_ str: S) -> Expression {
        Expression { e, s in
            s.append(contentsOf: str)
        }
    }
    
    static func foreach(_ key: String, do fn: Expression) -> Expression {
        Expression { env, s in
            let list = env[key]
            
            var stack = env
            for item in list {
                stack[key] = [item]
                try fn.eval(in: &stack, output: &s)
            }
//            foreach(key, in: env[key], do: fn)
        }
    }
    
//    static func foreach(_ key: String, in list: [AnyValue], do fn: Expression
//    ) -> Expression {
//        Expression { env, s in
//            guard let it = list.first
//            else { return }
//            var next = try fn.eval(in: &env, output: &s)
//            while next != nil {
//                next = try fn.eval(in: &env, output: &s)
//            }
//            foreach(key, in: Array(list.dropFirst()), do: fn)
//        }
//    }

    static func insert(key: String) -> Expression {
        Expression { env, s in
            if let v = env[key].first {
                s.append(contentsOf: String(describing: v))
            }
        }
    }

    static func insert<V>(key: String, else it: V) -> Expression {
        Expression { env, s in
            let v = env[key] as? V ?? it
            s.append(contentsOf: String(describing: v))
        }
    }

}
