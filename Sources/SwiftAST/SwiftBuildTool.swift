////////////////////////////////////////////////////////////////////////////
//
// Copyright 2019 Kishikawa Katsumi.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

import Foundation
import Basic
import SwiftASTCore

struct SwiftBuildTool {
    func run(source: String, arguments: [String], verbose: Bool = false) throws {
        let targetSource = URL(fileURLWithPath: source)
        let options = try SwiftBuildOptions(arguments)

        print("Reading project settings...")
        let swiftPackage = SwiftPackage(packagePath: options.packagePath, buildPath: options.buildPath)
        let packageDescription = try swiftPackage.describe(verbose: verbose)

        let dependency = try swiftPackage.showDependencies(verbose: verbose)
        let swiftOptions = constructSwiftOptions(swiftTestOptions: options, dependency: dependency)

        print("Build project target and dependencies...")
        let swiftBuild = SwiftBuild()
        try swiftBuild.build(arguments: options.rawOptions, verbose: verbose)

        print("Parsing...")
        for terget in packageDescription.targets {
            let path = URL(fileURLWithPath: terget.path)
            let sources = terget.sources.map { path.appendingPathComponent($0) }
            
            for source in sources {
                guard source == targetSource else {
                    continue
                }
                if Basic.localFileSystem.exists(AbsolutePath(source.path)) && Basic.localFileSystem.isFile(AbsolutePath(source.path)) {
                    let dependencies = sources.filter { $0 != source }
                    let processor = SwiftAST(buildOptions: swiftOptions + ["-module-name", terget.name], dependencies: dependencies)
                    let root = try processor.processFile(input: source, verbose: verbose)
                    ASTPrinter(sourceFile: source).print(root)
                }
            }
        }
    }

    private func constructSwiftOptions(swiftTestOptions: SwiftBuildOptions, dependency: Dependency) -> [String] {
        let configuration = swiftTestOptions.configuration ?? "debug"

        let buildPath: URL
        if let buildPathOption = swiftTestOptions.buildPath {
            buildPath = URL(fileURLWithPath: buildPathOption)
        } else {
            if let packagePath = swiftTestOptions.packagePath {
                buildPath = URL(fileURLWithPath: packagePath).appendingPathComponent(".build")
            } else {
                buildPath = URL(fileURLWithPath: "./.build")
            }
        }
        let buildDirectory = buildPath.appendingPathComponent(configuration).path

        let fileSystem = Basic.localFileSystem
        var modulemapPaths = [String]()
        func findModules(_ dependencies: [Dependency]) {
            for dependency in dependencies {
                let modulemapPath = URL(fileURLWithPath: dependency.path).appendingPathComponent("module.modulemap").path
                if fileSystem.exists(AbsolutePath(modulemapPath)) && fileSystem.isFile(AbsolutePath(modulemapPath)) {
                    modulemapPaths.append(modulemapPath)
                }
                findModules(dependency.dependencies)
            }
        }
        findModules(dependency.dependencies)

        var buildOptions = [String]()
        #if os(macOS)
        let sdk = try! SDK.macosx.path()
        buildOptions = ["-sdk", sdk, "-F", sdk + "/../../../Developer/Library/Frameworks"]
        let targetTriple = "x86_64-apple-macosx10.10"
        #else
        let targetTriple = "x86_64-unknown-linux"
        #endif
        buildOptions += ["-target", targetTriple, "-F", buildDirectory, "-I", buildDirectory]
        buildOptions += modulemapPaths.flatMap { ["-Xcc", "-fmodule-map-file=\($0)"] }

        return buildOptions
    }
}

struct SwiftBuildOptions {
    var configuration: String?
    var buildPath: String?
    var packagePath: String?
    var rawOptions: [String]

    var buildOptions: [String] {
        var options = [String]()
        if let configuration = configuration {
            options.append(contentsOf: ["--configuration", configuration])
        }
        if let buildPath = buildPath {
            options.append(contentsOf: ["--build-path", buildPath])
        }
        if let packagePath = packagePath {
            options.append(contentsOf: ["--package-path", packagePath])
        }
        return options
    }

    init(_ arguments: [String]) throws {
        var options: [String]
        if let first = arguments.first, first == "swift" {
            options = Array(arguments.dropFirst())
        } else {
            options = arguments
        }
        if let subcommand = options.first, !subcommand.hasPrefix("-") {
            guard subcommand == "build" || subcommand == "test" else {
                throw SwiftTestError.subcommandNotSupported(subcommand)
            }
            options = Array(options.dropFirst())
        }
        rawOptions = options

        var iterator = options.makeIterator()
        while let option = iterator.next() {
            switch option {
            case "--configuration", "-c":
                configuration = iterator.next()
            case "--build-path":
                buildPath = iterator.next()
            case "--package-path":
                packagePath = iterator.next()
            default:
                break
            }
        }
    }
}

private class SwiftTool {
    #if os(macOS)
    let exec = ["/usr/bin/xcrun", "swift"]
    #else
    let exec = ["swift"]
    #endif

    let toolName: String
    let redirectOutput: Bool

    init(toolName: String, redirectOutput: Bool = true) {
        self.toolName = toolName
        self.redirectOutput = redirectOutput
    }

    var options: [String] {
        return []
    }

    func run(_ arguments: [String], verbose: Bool = false) throws -> String {
        let process = Process(arguments: exec + [toolName] + options + arguments, redirectOutput: redirectOutput, verbose: verbose)
        try! process.launch()
        ProcessManager.default.add(process: process)
        let result = try! process.waitUntilExit()
        let output = try! result.utf8Output()
        switch result.exitStatus {
        case .terminated(let code) where code == 0:
            return output
        default:
            let errorOutput = try result.utf8stderrOutput()
            let command = process.arguments.map { $0.shellEscaped() }.joined(separator: " ")
            throw SwiftASTError.executingSubprocessFailed(command: command, output: errorOutput)
        }
    }
}

private class SwiftPackage: SwiftTool {
    let packagePath: String?
    let buildPath: String?

    init(packagePath: String?, buildPath: String?) {
        self.buildPath = buildPath
        self.packagePath = packagePath
        super.init(toolName: "package")
    }

    override var options: [String] {
        var options = [String]()
        if let packagePath = packagePath {
            options.append(contentsOf: ["--package-path", packagePath])
        }
        if let buildPath = buildPath {
            options.append(contentsOf: ["--build-path", buildPath])
        }
        return options
    }

    func describe(verbose: Bool = false) throws -> PackageDescription {
        let output = cleansingOutput(try run(["describe", "--type", "json"], verbose: verbose))
        return try JSONDecoder().decode(PackageDescription.self, from: output.data(using: .utf8)!)
    }

    func showDependencies(verbose: Bool = false) throws -> Dependency {
        let output = cleansingOutput(try run(["show-dependencies", "--format", "json"], verbose: verbose))
        return try! JSONDecoder().decode(Dependency.self, from: output.data(using: .utf8)!)
    }

    private func cleansingOutput(_ output: String) -> String {
        let index = output.firstIndex { $0 == "{" }
        if let index = index {
            return String(output[index...])
        }
        return output
    }
}

private class SwiftBuild: SwiftTool {
    init() {
        super.init(toolName: "build", redirectOutput: false)
    }

    func build(arguments: [String], verbose: Bool = false) throws {
        _ = try run(arguments, verbose: verbose)
    }
}

private struct PackageDescription: Decodable {
    let name: String
    let path: String
    let targets: [Target]
}

private struct Target: Decodable {
    let c99name: String
    let moduleType: String
    let name: String
    let path: String
    let sources: [String]
    let type: String

    enum CodingKeys: String, CodingKey {
        case c99name
        case moduleType = "module_type"
        case name
        case path
        case sources
        case type
    }
}

private struct Dependency: Decodable {
    let name: String
    let path: String
    let url: String
    let version: String
    let dependencies: [Dependency]
}

private enum SwiftTestError: Error {
    case subcommandNotSupported(String)
}

extension SwiftTestError: CustomStringConvertible {
    var description: String {
        switch self {
        case .subcommandNotSupported(let subcommand):
            return "'swift \(subcommand)' is not supported. 'swift test' is only supported"
        }
    }
}
