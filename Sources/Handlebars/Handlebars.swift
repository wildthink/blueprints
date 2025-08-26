//
//  Handlebars.swift
//  TemplateEngine
//
//  Created by Jason Jobe on 8/25/25.
//


import Foundation

extension NSMutableDictionary {
    @objc func boolValue(forKeyPath key: Substring?) -> Bool {
        guard let key else { return false }
        let flag = self.value(forKeyPath: key.description)
        return switch flag {
        case let it as Int: (it != 0)
        case let it as Bool: it
        case .none: false
        case .some(_): true // Any non-nil will do
        }
    }
    
    var dot: NSObject? {
        self.value(forKeyPath: ".") as? NSObject
    }
}

public enum KituraMiniHandlebarsError: Error {
    case RangeError
    case KeyForArrayMissing
    case UnableToEncodeValue
    case UnableToCastJSONtoDictionary
}

public struct KituraMiniHandlebarsOptions: RenderingOptions {
    
    /// Constructor
    public init () {}
}

public class Handlebars {
    
    public let fileExtension: String = "html";
    
    public init () {}
    
    /// Public method to generate HTML.
    ///
    /// - Parameters:
    ///   - filePath: The path of the template file.
    ///   - context: A set of variables in the form of a Dictionary of Key/Value pairs.
    /// - Returns: String containing a HTML.
    /// - Throws: Template reading error.
    public func render (filePath: String, context: [String: Any]) throws -> String {
        return try render(filePath: filePath, context: context, options: KituraMiniHandlebarsOptions())
    }
    
    /// Public method to generate HTML.
    ///
    /// - Parameters:
    ///   - filePath: The path of the template file.
    ///   - context: A set of variables in the form of a Dictionary of Key/Value pairs.
    ///   - options: KituraMiniHandlebarsOptions. *Note:* no options available at the time.
    /// - Returns: String containing a HTML.
    /// - Throws: Template reading error.
    public func render (filePath: String, context: [String: Any], options: KituraMiniHandlebarsOptions) throws -> String {
        
        let html: String = try String(contentsOf: URL(fileURLWithPath: filePath), encoding: .utf8);
        
        return try render(from: html, context: context);
    }
    
    /// Public method to generate HTML with using encodable structure.
    ///
    /// - Parameters:
    ///   - filePath: The path of the template file.
    ///   - value: Encodable structure.
    ///   - key: Key to itarate encodagle structure in template file with in case of array in the value field.
    ///   - options: KituraMiniHandlebarsOptions. *Note:* no options available at the time.
    ///   - templateName: *Note:* no available at the time.
    /// - Returns: String containing a HTML.
    /// - Throws: Template reading error.
//    public func render<T: Encodable>(filePath: String, with value: T, forKey key: String?, options: RenderingOptions, templateName: String) throws -> String {
//        
//        // Throw an error in case that value is an array and key which to map the array to is not present.
//        let valueIsArray: Bool = value is Array<Any>
//        
//        if key == nil && valueIsArray {
//            throw KituraMiniHandlebarsError.KeyForArrayMissing
//        }
//        
//        var data: Data = Data()
//        
//        do {
//            data = try JSONEncoder().encode(value)
//        } catch {
//            throw KituraMiniHandlebarsError.UnableToEncodeValue
//        }
//        
//        let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
//        var jsonArray: [[String: Any]]?
//        var jsonBasic: [String: Any]?
//        
//        if valueIsArray {
//            jsonArray = json as? [[String: Any]]
//        } else {
//            jsonBasic = json as? [String: Any]
//        }
//        
//        if jsonArray == nil && jsonBasic == nil {
//            throw KituraMiniHandlebarsError.UnableToCastJSONtoDictionary
//        }
//        
//        var context: [String: Any]
//        
//        if jsonArray != nil {
//            let key = key!
//            context = [key: jsonArray!]
//        } else {
//            context = jsonBasic!
//        }
//        
//        return try self.render(filePath: filePath, context: context)
//    }
    
    /// Public static method to generate HTML.
    ///
    /// - Parameters:
    ///   - from: String from which to generate HTML.
    ///   - context: A set of variables in the form of a Dictionary of Key/Value pairs.
    /// - Returns: String containing a HTML.
    public func render (from: String, context: [String: Any]) throws -> String {
        
        if from.isEmpty {
            return from;
        }
        
        let commands = getAllCommands(from: from)
        var rendered: String = "";
        let cp = (context as NSDictionary).mutableCopy() as! NSMutableDictionary
        try render(commands: commands, context: cp, into: &rendered)
        return rendered
    }
        
    func render (
        commands: [Command],
        context: NSMutableDictionary,
        into rendered: inout String
    ) throws {

        var conds: [(Command,Bool)] = []
        var shouldOutput: Bool { (conds.last?.1) ?? true }

        // process commands
        var curs = Cursor(commands)
        
//        for cmd in commands {
        while let cmd = curs.next() {
            switch cmd.op {
            case .if:
                // if true process until else/endif
                let flag = context.boolValue(forKeyPath: cmd.argv.first)
                conds.append((cmd, flag))
            case .else:
                guard let (cmd, flag) = conds.last
                else {
                    throw CommandError.missing_if
                }
                // NOTE: flip the flag on its #if
                conds.removeLast()
                // CHECK: for "else" vs "else if cond"
                if cmd.argv.isEmpty {
                    conds.append((cmd, !flag))
                } else {
                    let myflag = context.boolValue(forKeyPath: cmd.argv.last)
                    conds.append((cmd, myflag))
                }

            case .endif:
                guard let _ = conds.last
                else {
                    throw CommandError.missing_if
                }
                conds.removeLast()

            case _ where !shouldOutput:
                continue
                
            case .text:
                rendered.append(cmd.raw.description)
                
            case .eval:
                guard let key = cmd.argv.first?.description
                else {
                    continue
                }
                if let value = context.value(forKeyPath: key) {
                    rendered.append(String(describing: value))
                } else if let value = context.dot?.value(forKeyPath: key) {
                    rendered.append(String(describing: value))
                } else {
                    print("NO VALUE for", key)
                }
            case .each:
                print("EACH", cmd.argv.first)
                // FIXME: Should wrap a Cursor around the array
                // FIXME: ONLY uses the first item
                guard let list = context.value(forKeyPath: cmd.argv.first?.description ?? "") as? Array<Any>
                else { continue }
                context["."] = list.first
//                var ctx = context
//                for item in list {
//                    ctx["."] = item
//                    try render(commands: &commands, context: ctx, into: &rendered)
//                }
            case .include:
                rendered.append(cmd.raw.description)
            }
        }
    }
    

    /// Iterates over a template and finds all valid commands of the KituraMiniHandlebars.
    ///
    /// - Parameter from: String of an template.
    /// - Returns: All KituraMiniHandlebars commands to be found in the string.

    private func getAllCommands (from: String) -> Array<Command> {
        
        var commands: [Command] = []
        
        var curs = StringScanner(from)
        
        var cpos = curs.index
        
        while curs.hasInput {
            switch curs {
            case "{{":
                let run = from[cpos..<curs.index]
                let cmd = Command(op: .text, raw: run, range: cpos..<curs.index)
                cpos = curs.index
                commands.append(cmd)
                curs.advance(by: 2)

            case "}}":
                curs.advance(by: 2)
                let run = from[cpos..<curs.index]
                let cmd = Command(op: .eval, raw: run, range: cpos..<curs.index)
                cpos = curs.index
                commands.append(cmd)
                
            default:
                curs.advance()
            }
        }
        return commands
    }
    
}

func foo(_ cmds: [Command]) {
    var engine = Cursor(cmds)
    var str = ""
    try? engine.run(in: Environment())
    print(str)
}

extension Dictionary where Key == String {
    subscript(key: Substring) -> Value? {
        get { self[key.description] }
        set { self[key.description] = newValue }
    }
}

@dynamicMemberLookup
struct Environment {
    typealias Value = Any
    var values: [String:Value] = [:]
    
    subscript(dynamicMember key: String) -> Value? {
        get { values[key] }
        set { values[key] = newValue }
    }
    
    subscript(key: Substring?) -> Value? {
        get {
            if let key { values[key] }
            else { nil }
        }
        set { if let key { values[key] = newValue }}
    }

    subscript(key: String?) -> Value? {
        get {
            if let key { values[key] }
            else { nil }
        }
        set { if let key { values[key] = newValue }}
    }

    func mod(_ key: String, to: Any) -> Self {
        var cp = self
        cp.values[key] = to
        return cp
    }
}

//extension Environment {
//    func run(_ eng: Cursor<[Command]>, pout: inout String) {
//        while let cmd = eng.next() {
//            switch cmd.op {
//            case .if:
//                self
//                    .mod("foo", to: 23)
//                    .run(eng, pout: &pout)
//        default:
//            continue
//        }
//    }
//}

struct Engine {
    init(template: String) throws {
    }
    mutating func run(in env: Environment) {
    }
    
    mutating func emit(_ value: Any?) throws {
        
    }
}

extension Cursor<[Command]> {
    mutating func run(in env: Environment) throws {
        while let cmd = next() {
            switch cmd.op {
            case .if:
                run(in: env) {
                    $0.active = env[cmd.argv.first]
                }
                
            case .else:
                run(in: env) { _ in
//                    $0.active.toggle()
                }
            case .endif:
                return
            
            case .each:
                for el in [1] {
                    run(in: env) {
                        $0.dot = el
                    }
                }
            case .text:
                // enigine.emit(cmd.eval(in: env))
            case .eval:
                if let value = cmd.eval(in: env) {
                    // emit
                }
            case .include:
                var eng = try Engine(template: "")
                eng.run(in: env)
                
            default:
                continue
            }
        }
    }
    
    mutating func run(in env: Environment, fn: (inout Environment) -> Void) {
    }
}

// MARK:

enum CommandError: Error {
    case missing_if
    case unknown(String)
}

enum CommandOperator {
    case text, eval
    case `if`, `else`, endif
    case each
    case include
}

struct Command {
    var op: CommandOperator
    var raw: Substring
    var range: Range<String.Index>
    var argv: [Substring]
    var index: Int { raw.distance(from: raw.startIndex, to: range.lowerBound) }

    func eval(in: Environment) -> Any? {
        nil
    }
    
    init(op: CommandOperator, raw: Substring, range: Range<String.Index>) {
        self.op = op
        self.raw = raw
        self.range = range
        self.argv = []
        if op != .text {
            parse()
        }
    }
    
    mutating func parse() {
        var curs = StringScanner(raw)
        
        while curs.hasInput {
            curs.skip(CharacterSet.whitespaces)
            switch curs {
            case "#if":
                op = .if
                curs.advance(by: 3)

            case "/if":
                op = .if
                curs.advance(by: 3)

            case "#each":
                op = .each
                curs.advance(by: 5)
                
            case "else":
                op = .else
                curs.advance(by: 4)
                
            case "#":
                op = .include
                curs.advance()
                
            case "{{", "}}":
                curs.advance(by: 2)
                
            case symbolset:
                let str = curs.scan(symbolset)
                argv.append(str)
                
            default:
                curs.advance()
            }
        }
    }
    
    var symbolset: CharacterSet { Self.symbolset }
    
    static let symbolset: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: ".")
        return set}()
}

extension Command: CustomStringConvertible {
    var description: String {
        switch op {
        case .text:
            "TEXT " + String(raw.prefix(12))
        case .eval:
            raw.description
        default:
            "\(op)(\(argv.joined(separator: ", ")))"
        }
    }
}
