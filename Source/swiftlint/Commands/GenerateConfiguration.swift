import ArgumentParser
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#else
#error("Unsupported platform")
#endif
import Foundation
import SwiftLintFramework
import SwiftyTextTable

extension SwiftLint {
    struct GenerateConfiguration: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Generate a default configuration file")
        
        @Option(help: "The path to a SwiftLint configuration file")
        var config: String?
        @OptionGroup
        var rulesFilterOptions: RulesFilterOptions
        @Flag(name: .shortAndLong, help: "Add a comment describing the rule")
        var verbose = false
        
        func run() throws {
            let configuration = Configuration(configurationFiles: [config].compactMap { $0 })
            let rulesFilter = RulesFilter(enabledRules: configuration.rules)
            let rules = rulesFilter.getRules(excluding: rulesFilterOptions.excludingOptions)
            let sortedRules = rules.list
                .filter { $0.key != "custom_rules" }
                .sorted { $0.key < $1.key }
            
            print("# By default, SwiftLint uses a set of sensible default rules you can adjust:")
            
            let optOutRules = sortedRules.filter { ruleID, ruleType in
                let rule = ruleType.init()
                return !(rule is (any OptInRule))
            }
            
            let optInRules = sortedRules.filter { ruleID, ruleType in
                let rule = ruleType.init()
                return rule is (any OptInRule)
            }
            
            print("disabled_rules: # rule identifiers turned on by default to exclude from running")
            for (ruleID, ruleType) in optOutRules {
                let configuredRule = configuration.configuredRule(forID: ruleID)
                
                let line = [
                    configuredRule == nil ? nil : "#",
                    "-",
                    ruleID,
                    verbose ? "# \(ruleType.description.comment)" : nil
                ]
                .compactMap { $0 }
                .joined(separator: " ")
                
                print("  \(line)")
            }
            
            print("opt_in_rules: # some rules are turned off by default, so you need to opt-in")
            for (ruleID, ruleType) in optInRules {
                let configuredRule = configuration.configuredRule(forID: ruleID)
                
                let line = [
                    configuredRule != nil ? nil : "#",
                    "-",
                    ruleID,
                    verbose ? "# \(ruleType.description.comment)" : nil
                ]
                .compactMap { $0 }
                .joined(separator: " ")
                
                print("  \(line)")
            }
            
            if !configuration.includedPaths.isEmpty {
                print("\nincluded:")
                for path in configuration.includedPaths.paths(rootDirectory: configuration.rootDirectory, relativeTo: config) {
                    print("  - \(path)")
                }
            }
            
            if !configuration.excludedPaths.isEmpty {
                print("\nexcluded:")
                for path in configuration.excludedPaths.paths(rootDirectory: configuration.rootDirectory, relativeTo: config) {
                    print("  - \(path)")
                }
            }
            
            print()
        }
    }
}

private extension [String] {
    func paths(rootDirectory: String, relativeTo: String?) -> [String] {
        guard let relativeTo = relativeTo?.bridge().deletingLastPathComponent else { return self }
        return map {
            $0.bridge()
                .absolutePathRepresentation(rootDirectory: rootDirectory)
                .path(relativeTo: relativeTo)
        }
    }
}

private extension RuleDescription {
    var comment: String {
        description.replacingOccurrences(of: "\n", with: " ")
    }
}
