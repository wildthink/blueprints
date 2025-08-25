// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

public class Handlebars {
    
    var scope: Scope
    var steps: [Expression]
    
    init(scope: Scope, steps: [Expression]) {
        self.scope = scope
        self.steps = steps
    }
    
    func parse(_ url: URL) {
        
    }
    
    func run() throws {
        
        var str = ""
        
        for step in steps {
            try step.eval(in: &scope, output: &str)
        }
    }
}

