import SwiftSyntax

@SwiftSyntaxRule
struct VerticalParameterAlignmentRule: Rule {
    var configuration = SeverityConfiguration<Self>(.warning)

    static let description = RuleDescription(
        identifier: "vertical_parameter_alignment",
        name: "Vertical Parameter Alignment",
        description: "Function parameters should be aligned vertically if they're in multiple lines in a declaration",
        kind: .style,
        nonTriggeringExamples: VerticalParameterAlignmentRuleExamples.nonTriggeringExamples,
        triggeringExamples: VerticalParameterAlignmentRuleExamples.triggeringExamples
    )
}

private extension VerticalParameterAlignmentRule {
    final class Visitor: ViolationsSyntaxVisitor<ConfigurationType> {
        override func visitPost(_ node: FunctionDeclSyntax) {
            violations.append(contentsOf: violations(for: node.signature.parameterClause.parameters))
        }

        override func visitPost(_ node: InitializerDeclSyntax) {
            violations.append(contentsOf: violations(for: node.signature.parameterClause.parameters))
        }

        private func violations(for params: FunctionParameterListSyntax) -> [AbsolutePosition] {
            guard params.count > 1 else {
                return []
            }

            let paramLocations = params.compactMap { param -> (position: AbsolutePosition, line: Int, column: Int)? in
                let position = param.positionAfterSkippingLeadingTrivia
                let location = locationConverter.location(for: position)
                return (position, location.line, location.column)
            }

            guard let firstParamLoc = paramLocations.first else { return [] }

            var violations: [AbsolutePosition] = []
            for (index, paramLoc) in paramLocations.enumerated() where index > 0 && paramLoc.line > firstParamLoc.line {
                let previousParamLoc = paramLocations[index - 1]
                if previousParamLoc.line < paramLoc.line, firstParamLoc.column != paramLoc.column {
                    violations.append(paramLoc.position)
                }
            }

            return violations
        }
    }
}
