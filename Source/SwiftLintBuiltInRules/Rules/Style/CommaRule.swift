import Foundation
import SourceKittenFramework
import SwiftSyntax

struct CommaRule: CorrectableRule, SourceKitFreeRule {
    var configuration = SeverityConfiguration<Self>(.warning)

    static let description = RuleDescription(
        identifier: "comma",
        name: "Comma Spacing",
        description: "There should be no space before and one after any comma",
        kind: .style,
        nonTriggeringExamples: [
            Example("func abc(a: String, b: String) { }"),
            Example("abc(a: \"string\", b: \"string\""),
            Example("enum a { case a, b, c }"),
            Example("func abc(\n  a: String,  // comment\n  bcd: String // comment\n) {\n}"),
            Example("func abc(\n  a: String,\n  bcd: String\n) {\n}"),
            Example("#imageLiteral(resourceName: \"foo,bar,baz\")"),
            Example("""
                kvcStringBuffer.advanced(by: rootKVCLength)
                  .storeBytes(of: 0x2E /* '.' */, as: CChar.self)
                """),
            Example("""
                public indirect enum ExpectationMessage {
                  /// appends after an existing message ("<expectation> (use beNil() to match nils)")
                  case appends(ExpectationMessage, /* Appended Message */ String)
                }
                """, excludeFromDocumentation: true),
        ],
        triggeringExamples: [
            Example("func abc(a: String↓ ,b: String) { }"),
            Example("func abc(a: String↓ ,b: String↓ ,c: String↓ ,d: String) { }"),
            Example("abc(a: \"string\"↓,b: \"string\""),
            Example("enum a { case a↓ ,b }"),
            Example("let result = plus(\n    first: 3↓ , // #683\n    second: 4\n)"),
            Example("""
            Foo(
              parameter: a.b.c,
              tag: a.d,
              value: a.identifier.flatMap { Int64($0) }↓ ,
              reason: Self.abcd()
            )
            """),
            Example("""
            return Foo(bar: .baz, title: fuzz,
                      message: My.Custom.message↓ ,
                      another: parameter, doIt: true,
                      alignment: .center)
            """),
            Example(#"Logger.logError("Hat is too large"↓,  info: [])"#),
        ],
        corrections: [
            Example("func abc(a: String↓,b: String) {}"): Example("func abc(a: String, b: String) {}"),
            Example("abc(a: \"string\"↓,b: \"string\""): Example("abc(a: \"string\", b: \"string\""),
            Example("abc(a: \"string\"↓  ,  b: \"string\""): Example("abc(a: \"string\", b: \"string\""),
            Example("enum a { case a↓  ,b }"): Example("enum a { case a, b }"),
            Example("let a = [1↓,1]\nlet b = 1\nf(1, b)"): Example("let a = [1, 1]\nlet b = 1\nf(1, b)"),
            Example("let a = [1↓,1↓,1↓,1]"): Example("let a = [1, 1, 1, 1]"),
            Example("""
            Foo(
              parameter: a.b.c,
              tag: a.d,
              value: a.identifier.flatMap { Int64($0) }↓ ,
              reason: Self.abcd()
            )
            """): Example("""
                Foo(
                  parameter: a.b.c,
                  tag: a.d,
                  value: a.identifier.flatMap { Int64($0) },
                  reason: Self.abcd()
                )
                """),
            Example("""
            return Foo(bar: .baz, title: fuzz,
                      message: My.Custom.message↓ ,
                      another: parameter, doIt: true,
                      alignment: .center)
            """): Example("""
                return Foo(bar: .baz, title: fuzz,
                          message: My.Custom.message,
                          another: parameter, doIt: true,
                          alignment: .center)
                """),
            Example(#"Logger.logError("Hat is too large"↓,  info: [])"#):
                Example(#"Logger.logError("Hat is too large", info: [])"#),
        ]
    )

    func validate(file: SwiftLintFile) -> [StyleViolation] {
        violationRanges(in: file).map {
            StyleViolation(ruleDescription: Self.description,
                           severity: configuration.severity,
                           location: Location(file: file, byteOffset: $0.0.location))
        }
    }

    private func violationRanges(in file: SwiftLintFile) -> [(ByteRange, shouldAddSpace: Bool)] {
        let syntaxTree = file.syntaxTree

        return syntaxTree
            .windowsOfThreeTokens()
            .compactMap { previous, current, next -> (ByteRange, shouldAddSpace: Bool)? in
                if current.tokenKind != .comma {
                    return nil
                }
                if !previous.trailingTrivia.isEmpty, !previous.trailingTrivia.containsBlockComments() {
                    let start = ByteCount(previous.endPositionBeforeTrailingTrivia)
                    let end = ByteCount(current.endPosition)
                    let nextIsNewline = next.leadingTrivia.containsNewlines()
                    return (ByteRange(location: start, length: end - start), shouldAddSpace: !nextIsNewline)
                }
                if !current.trailingTrivia.starts(with: [.spaces(1)]), !next.leadingTrivia.containsNewlines() {
                    let start = ByteCount(current.position)
                    let end = ByteCount(next.positionAfterSkippingLeadingTrivia)
                    return (ByteRange(location: start, length: end - start), shouldAddSpace: true)
                }
                return nil
            }
    }

    func correct(file: SwiftLintFile) -> Int {
        let initialNSRanges = Dictionary(
            uniqueKeysWithValues: violationRanges(in: file)
                .compactMap { byteRange, shouldAddSpace in
                    file.stringView
                        .byteRangeToNSRange(byteRange)
                        .flatMap { ($0, shouldAddSpace) }
                }
        )

        let violatingRanges = file.ruleEnabled(violatingRanges: Array(initialNSRanges.keys), for: self)
        guard violatingRanges.isNotEmpty else {
            return 0
        }

        var contents = file.contents
        for range in violatingRanges.sorted(by: { $0.location > $1.location }) {
            let contentsNSString = contents.bridge()
            let shouldAddSpace = initialNSRanges[range] ?? true
            contents = contentsNSString.replacingCharacters(in: range, with: ",\(shouldAddSpace ? " " : "")")
        }
        file.write(contents)
        return violatingRanges.count
    }
}

private extension Trivia {
    func containsBlockComments() -> Bool {
        contains { piece in
            if case .blockComment = piece {
                return true
            }
            return false
        }
    }
}
