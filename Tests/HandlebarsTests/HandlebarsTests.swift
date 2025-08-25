import Testing
@testable import Handlebars
import Foundation

@Test func testResume() async throws {
    let resource_dir = ProcessInfo.processInfo.environment["TEST_RESOURCES"]
    guard let resource_dir
    else {
        #expect(Bool(false), "TEST_RESOURCES is not defined in test environment")
        return
    }
    let rurl = URL(fileURLWithPath: resource_dir)
    print(rurl)

    let data = try Data(contentsOf: rurl.appending(component: "resume.json"))
    let input = try JSONSerialization.jsonObject(with: data)
    let engine = MiniHandlebars()
    engine.setRootPaths(rootPaths: [resource_dir])
    
    let html = try engine.render(
        filePath: rurl.appending(component: "resume.handlebars").path,
        context: ["resume": input], options: .init())

//    let output = URL(filePath: "/Users/jason/dev/workspace/Packages/Handlebars/Generated")
    let output = rurl.appending(components: "../..", "Generated", "resume.html")
    try html.write(to: output, atomically: true, encoding: .utf8)
    
    print("DONE", #function)
}
