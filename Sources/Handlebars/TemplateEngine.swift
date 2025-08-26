//
//  RenderingOptions.swift
//  Handlebars
//
//  Created by Jason Jobe on 8/25/25.
//


public protocol RenderingOptions {}

public struct NullRenderingOptions: RenderingOptions {
    public init() {}
}

/// Template Engine protocol
///
/// - Note: Influenced by http://expressjs.com/en/guide/using-template-engines.html
public protocol TemplateEngine {

    /// The file extension of files in the views directory that will be
    /// rendered by a particular templating engine.
    var fileExtension: String { get }

    /// Take a template file and a set of "variables" in the form of a context
    /// and generate content to be sent back to the client.
    ///
    /// - Parameter filePath: The path of the template file to use when generating
    ///                      the content.
    /// - Parameter context: A set of variables in the form of a Dictionary of
    ///                     Key/Value pairs, that can be used when generating the content.
//    func render(filePath: String, context: [String: Any]) throws -> String

    /// Take a template file and a set of "variables" in the form of a context
    /// and generate content to be sent back to the client.
    ///
    /// - Parameter filePath: The path of the template file to use when generating
    ///                      the content.
    /// - Parameter context: A set of variables in the form of a Dictionary of
    ///                     Key/Value pairs, that can be used when generating the content.
    /// - Parameter options: rendering options, different per each template engine
    ///
//    func render(filePath: String, context: [String: Any],
//                options: RenderingOptions) throws -> String

    /// Take a template file and a set of "variables" in the form of a context
    /// and generate content to be sent back to the client.
    ///
    /// - Parameter filePath: The path of the template file to use when generating
    ///                      the content.
    /// - Parameter context: A set of variables in the form of a Dictionary of
    ///                     Key/Value pairs, that can be used when generating the content.
    /// - Parameter options: rendering options, different per each template engine
    ///
    /// - Parameter templateName: the name of the template
    ///
//    func render(filePath: String, context: [String: Any],
//                options: RenderingOptions, templateName: String) throws -> String

    /// Take a template file and an Encodable type and generate the content to be sent back to the client.
    ///
    /// - Parameter filePath: The path of the template file to use when generating
    ///                      the content.
    /// - Parameter with: A value that conforms to Encodable which is used to generate the content.
    ///
    /// - Parameter forKey: A value used to match the Encodable values to the correct variable in a template file.
    ///                                 The `forKey` value should match the desired variable in the template file.
    /// - Parameter options: rendering options, different per each template engine.
    ///
    /// - Parameter templateName: the name of the template.
    ///
    func render<T: Encodable>(filePath: String, with: T, forKey: String?,
                options: RenderingOptions, templateName: String) throws -> String

    /// Set root paths for the template engine - the paths where the included templates can be
    /// searched
    ///
    /// - Parameter rootPaths: the paths where the included templates can be
    func setRootPaths(rootPaths: [String])
}

//extension TemplateEngine {
//    // Implementation of render with options parameter for TemplateEngines
//    // that do not implement it
//    public func render(filePath: String, context: [String: Any],
//                       options: RenderingOptions) throws -> String {
//        return try render(filePath: filePath, context: context)
//    }
//
//    // Implementation of render with options and templateName parameter for TemplateEngines
//    // that do not implement it
//    public func render(filePath: String, context: [String: Any],
//                       options: RenderingOptions, templateName: String) throws -> String {
//        return try render(filePath: filePath, context: context, options: options)
//    }
//
//    // Implementation of setRootPaths for TemplateEngines that do not implement it
//    public func setRootPaths(rootPaths: [String]) {}
//}
