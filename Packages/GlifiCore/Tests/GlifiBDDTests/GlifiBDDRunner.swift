// SPDX-License-Identifier: BSD-3-Clause

import CucumberSwiftTesting
import Foundation

// CucumberSwift's supported registration API requires this test-only conformance (GS-WVR-005).
// swift-format-ignore: AvoidRetroactiveConformances
extension Cucumber: @retroactive StepImplementation {
    /// Registers the domain steps shared by the executable acceptance scenarios.
    public func setupSteps() {
        Cucumber.oneTestPerScenario = true
        if ProcessInfo.processInfo.environment["CUCUMBER_REPORT_PATH"] == nil {
            Cucumber.reportPath =
                URL(fileURLWithPath: CommandLine.arguments[0])
                .deletingLastPathComponent().appendingPathComponent("cucumber.json").path
        }
        registerWorkflowSteps()
        registerCLISteps()
        registerAnalyticalSteps()
        registerCompleteMethodSteps()
        registerProfileSteps()
        registerInterchangeSteps()
        registerPlannerContractSteps()
        registerTextVariantSteps()
        registerEvaluationVariantSteps()
        registerProjectVariantSteps()
        registerResearchSteps()
        registerStudySteps()
    }
}
