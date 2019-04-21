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

public final class SwiftAST {
    private let buildOptions: [String]
    private let dependencies: [URL]
    private let bridgingHeader: URL?

    private let fileSystem = Basic.localFileSystem

    public init(buildOptions: [String], dependencies: [URL] = [], bridgingHeader: URL? = nil) {
        self.buildOptions = buildOptions
        self.dependencies = dependencies
        self.bridgingHeader = bridgingHeader
    }

    public func processFile(input: URL, verbose: Bool = false) throws -> AST {
        return try process(sourceFile: input, verbose: verbose)
    }

    private func process(sourceFile: URL, verbose: Bool = false) throws -> AST {
        let arguments = buildArguments(source: sourceFile)
        let rawAST = try dumpAST(arguments: arguments)
        let tokens = tokenize(rawAST: rawAST)
        let node = lex(tokens: tokens)
        let root = parse(node: node)
        return root
    }

    private func buildArguments(source: URL) -> [String] {
        #if os(macOS)
        let exec = ["/usr/bin/xcrun", "swift"]
        #else
        let exec = ["swift"]
        #endif
        let arguments = exec + [
            "-frontend",
            "-suppress-warnings",
            "-dump-ast"
        ]
        let importObjcHeaderOption: [String]
        if let bridgingHeader = bridgingHeader {
            importObjcHeaderOption = ["-import-objc-header", bridgingHeader.path]
        } else {
            importObjcHeaderOption = []
        }
        return arguments + buildOptions + importObjcHeaderOption + ["-primary-file", source.path] + dependencies.map { $0.path }
    }

    private func dumpAST(arguments: [String]) throws -> String {
        let process = Process(arguments: arguments)
        try! process.launch()
        ProcessManager.default.add(process: process)
        let result = try process.waitUntilExit()
        let output = try result.utf8Output()
        switch result.exitStatus {
        case .terminated(let code) where code == 0:
            return output
        default:
            let command = process.arguments.map { $0.shellEscaped() }.joined(separator: " ")
            let errorOutput = try result.utf8stderrOutput().split(separator: "\n").prefix(1).joined(separator: "\n")
            throw SwiftASTError.executingSubprocessFailed(command: command, output: errorOutput)
        }
    }

    private func tokenize(rawAST: String) -> [ASTToken] {
        let tokenizer = ASTTokenizer()
        return tokenizer.tokenize(source: rawAST)
    }

    private func lex(tokens: [ASTToken]) -> ASTNode<[ASTToken]> {
        let lexer = ASTLexer()
        return lexer.lex(tokens: tokens)
    }

    private func parse(node: ASTNode<[ASTToken]>) -> AST {
        let parser = ASTParser()
        return parser.parse(root: node)
    }
}

public enum SDK {
    case macosx
    case iphoneos
    case iphonesimulator
    case watchos
    case watchsimulator
    case appletvos
    case appletvsimulator

    public var name: String {
        switch self {
        case .macosx:
            return "macosx"
        case .iphoneos:
            return "iphoneos"
        case .iphonesimulator:
            return "iphonesimulator"
        case .watchos:
            return "watchos"
        case .watchsimulator:
            return "watchsimulator"
        case .appletvos:
            return "appletvos"
        case .appletvsimulator:
            return "appletvsimulator"
        }
    }

    public var os: String {
        switch self {
        case .macosx:
            return "macosx"
        case .iphoneos, .iphonesimulator:
            return "ios"
        case .watchos, .watchsimulator:
            return "watchos"
        case .appletvos, .appletvsimulator:
            return "tvos"
        }
    }

    public func path() throws -> String {
        let process = Process(arguments: ["/usr/bin/xcrun", "--sdk", name, "--show-sdk-path"])
        try! process.launch()
        ProcessManager.default.add(process: process)
        let result = try! process.waitUntilExit()
        let output = try! result.utf8Output()
        switch result.exitStatus {
        case .terminated(let code) where code == 0:
            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        default:
            throw SwiftASTError.executingSubprocessFailed(command: process.arguments.joined(separator: " "), output: try result.utf8stderrOutput())
        }
    }

    public func version() throws -> String {
        let process = Process(arguments: ["/usr/bin/xcrun", "--sdk", name, "--show-sdk-version"])
        try! process.launch()
        ProcessManager.default.add(process: process)
        let result = try! process.waitUntilExit()
        let output = try! result.utf8Output()
        switch result.exitStatus {
        case .terminated(let code) where code == 0:
            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        default:
            throw SwiftASTError.executingSubprocessFailed(command: process.arguments.joined(separator: " "), output: try result.utf8stderrOutput())
        }
    }
}
