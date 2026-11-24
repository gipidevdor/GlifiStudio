// SPDX-License-Identifier: BSD-3-Clause

import Testing

@testable import GlifiCore

@Test("La baseline non consente telemetria o diagnostica automatica")
func telemetryPolicyIsLocalAndExplicit() {
    #expect(!GlifiTelemetryPolicy.allowsRemoteTelemetry)
    #expect(!GlifiTelemetryPolicy.allowsThirdPartyTelemetry)
    #expect(!GlifiTelemetryPolicy.allowsAutomaticDiagnosticExport)
    #expect(!GlifiTelemetryPolicy.allowsCorpusContentInDiagnostics)
}

@Test("La pressione critica protegge il sistema e rifiuta nuovo lavoro non interattivo")
func criticalPressureProtectsTheSystem() {
    let conditions = GlifiSystemConditions(
        isLowPowerModeEnabled: false,
        thermalCondition: .critical,
        memoryPressure: .critical,
        isApplicationActive: true
    )

    let recommendation = GlifiRuntimePolicy.recommendation(
        for: .userInitiated,
        conditions: conditions,
        availableProcessorCount: 12
    )

    #expect(recommendation.profile == .protective)
    #expect(recommendation.maximumParallelism == 0)
    #expect(!recommendation.allowsNewWork)
    #expect(!recommendation.allowsSpeculativeWork)
    #expect(recommendation.shouldCheckpoint)
}

@Test("Il lavoro interattivo minimo resta disponibile sotto pressione critica")
func criticalPressurePreservesInteractiveWork() {
    let conditions = GlifiSystemConditions(
        isLowPowerModeEnabled: true,
        thermalCondition: .critical,
        memoryPressure: .critical,
        isApplicationActive: true
    )

    let recommendation = GlifiRuntimePolicy.recommendation(
        for: .interactive,
        conditions: conditions,
        availableProcessorCount: 16
    )

    #expect(recommendation.profile == .protective)
    #expect(recommendation.priority == .userInteractive)
    #expect(recommendation.maximumParallelism == 1)
    #expect(recommendation.allowsNewWork)
    #expect(!recommendation.shouldCheckpoint)
}

@Test("Low Power Mode limita il lavoro richiesto e sospende quello discrezionale")
func lowPowerModeConstrainsScheduling() {
    let conditions = GlifiSystemConditions(
        isLowPowerModeEnabled: true,
        thermalCondition: .nominal,
        memoryPressure: .nominal,
        isApplicationActive: true
    )

    let requested = GlifiRuntimePolicy.recommendation(
        for: .userInitiated,
        conditions: conditions,
        availableProcessorCount: 10
    )
    let discretionary = GlifiRuntimePolicy.recommendation(
        for: .utility,
        conditions: conditions,
        availableProcessorCount: 10
    )

    #expect(requested.profile == .constrained)
    #expect(requested.maximumParallelism == 2)
    #expect(requested.allowsNewWork)
    #expect(discretionary.profile == .constrained)
    #expect(discretionary.maximumParallelism == 0)
    #expect(!discretionary.allowsNewWork)
    #expect(discretionary.shouldCheckpoint)
}

@Test("Un'app inattiva raggiunge l'idle sospendendo la manutenzione")
func inactiveApplicationSuspendsMaintenance() {
    let conditions = GlifiSystemConditions(
        isLowPowerModeEnabled: false,
        thermalCondition: .nominal,
        memoryPressure: .nominal,
        isApplicationActive: false
    )

    let recommendation = GlifiRuntimePolicy.recommendation(
        for: .maintenance,
        conditions: conditions,
        availableProcessorCount: 8
    )

    #expect(recommendation.profile == .suspended)
    #expect(recommendation.priority == .background)
    #expect(recommendation.maximumParallelism == 0)
    #expect(!recommendation.allowsNewWork)
    #expect(recommendation.shouldCheckpoint)
}

@Test("Il profilo nominale limita comunque il parallelismo alla policy")
func nominalProfileCapsParallelism() {
    let conditions = GlifiSystemConditions(
        isLowPowerModeEnabled: false,
        thermalCondition: .nominal,
        memoryPressure: .nominal,
        isApplicationActive: true
    )

    let recommendation = GlifiRuntimePolicy.recommendation(
        for: .userInitiated,
        conditions: conditions,
        availableProcessorCount: 64
    )

    #expect(recommendation.profile == .balanced)
    #expect(recommendation.priority == .userInitiated)
    #expect(recommendation.maximumParallelism == 8)
    #expect(recommendation.allowsNewWork)
    #expect(recommendation.allowsSpeculativeWork)
}

@Test("La matrice completa delle condizioni produce decisioni deterministiche e bounded")
func completeSystemConditionMatrixIsDeterministicAndBounded() {
    for intent in GlifiWorkIntent.allCases {
        for lowPowerMode in [false, true] {
            for thermalCondition in GlifiThermalCondition.allCases {
                for memoryPressure in GlifiMemoryPressure.allCases {
                    for isApplicationActive in [false, true] {
                        let conditions = GlifiSystemConditions(
                            isLowPowerModeEnabled: lowPowerMode,
                            thermalCondition: thermalCondition,
                            memoryPressure: memoryPressure,
                            isApplicationActive: isApplicationActive
                        )
                        let first = GlifiRuntimePolicy.recommendation(
                            for: intent,
                            conditions: conditions,
                            availableProcessorCount: 64
                        )
                        let second = GlifiRuntimePolicy.recommendation(
                            for: intent,
                            conditions: conditions,
                            availableProcessorCount: 64
                        )

                        #expect(first == second)
                        #expect(first.maximumParallelism >= 0)
                        #expect(first.maximumParallelism <= 8)
                        #expect(first.allowsNewWork == (first.maximumParallelism > 0))

                        if memoryPressure == .critical || thermalCondition == .critical {
                            #expect(first.profile == .protective)
                            #expect(!first.allowsSpeculativeWork)
                        }

                        if !isApplicationActive
                            && (intent == .utility || intent == .maintenance)
                            && memoryPressure != .critical
                            && thermalCondition != .critical
                        {
                            #expect(first.profile == .suspended)
                            #expect(first.shouldCheckpoint)
                        }
                    }
                }
            }
        }
    }
}

@Test("Ogni operazione misurata restituisce il risultato senza modificarlo")
func signpostsPreserveOperationResults() {
    for operation in GlifiMeasuredOperation.allCases {
        let result = GlifiDiagnostics.measure(operation) { 42 }
        #expect(result == 42)
    }
}
