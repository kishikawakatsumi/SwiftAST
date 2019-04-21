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

struct ParseTool {
    func run(source: String, buildCommand: [String], verbose: Bool = false) throws {
        if buildCommand.contains("xcodebuild") {
            try XcodebuildTool().run(source: source, arguments: buildCommand)
        } else if buildCommand.contains("swift") {
            try SwiftBuildTool().run(source: source, arguments: buildCommand)
        } else  {
            throw ParserError.buildCommandNotSupported(buildCommand.joined(separator: " "))
        }
    }
}

private enum ParserError: Error {
    case buildCommandNotSupported(String)
}

extension ParserError: CustomStringConvertible {
    var description: String {
        switch self {
        case .buildCommandNotSupported(let command):
            return "build command '\(command)' not supported"
        }
    }
}
