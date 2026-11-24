// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("Il p-value t a un grado di libertà coincide con l'identità Cauchy in arcotangente")
func tDistributionPValueMatchesCauchyClosedForm() throws {
    // La t di Student a 1 grado di libertà è la distribuzione di Cauchy
    // standard: P(|T|>t) = 1-(2/π)·arctan(t), calcolabile indipendentemente
    // senza la funzione beta incompleta in prova.
    let t1 = try GlifiStatisticalFoundation.tDistributionPValue(
        statistic: 1,
        degreesOfFreedom: 1,
        alternative: .twoSided
    )
    #expect(abs(t1 - 0.5) < 1e-9)  // arctan(1) = π/4 → p = 1 - 1/2 = 1/2 esatto.

    let sqrtThree = 3.0.squareRoot()
    let t2 = try GlifiStatisticalFoundation.tDistributionPValue(
        statistic: sqrtThree,
        degreesOfFreedom: 1,
        alternative: .twoSided
    )
    #expect(abs(t2 - 1.0 / 3.0) < 1e-9)  // arctan(√3) = π/3 → p = 1 - 2/3 = 1/3 esatto.

    // Simmetria dell'alternativa unilaterale.
    let greater = try GlifiStatisticalFoundation.tDistributionPValue(
        statistic: 1,
        degreesOfFreedom: 1,
        alternative: .greater
    )
    let less = try GlifiStatisticalFoundation.tDistributionPValue(
        statistic: -1,
        degreesOfFreedom: 1,
        alternative: .less
    )
    #expect(abs(greater - less) < 1e-12)
    #expect(abs(greater - 0.25) < 1e-9)
}

@Test("L'identità F(1,df2) = t²(df2) collega le due distribuzioni indipendentemente")
func fDistributionMatchesSquaredTIdentity() throws {
    let f = 4.0
    let denominatorDegreesOfFreedom = 7.0
    let fPValue = try GlifiStatisticalFoundation.fDistributionUpperTailPValue(
        statistic: f,
        numeratorDegreesOfFreedom: 1,
        denominatorDegreesOfFreedom: denominatorDegreesOfFreedom
    )
    let tPValue = try GlifiStatisticalFoundation.tDistributionPValue(
        statistic: f.squareRoot(),
        degreesOfFreedom: denominatorDegreesOfFreedom,
        alternative: .twoSided
    )
    #expect(abs(fPValue - tPValue) < 1e-9)
}

@Test(
    "Welch t su due campioni noti riproduce statistica e gradi di libertà per calcolo indipendente"
)
func welchTTestMatchesIndependentComputation() throws {
    let sample1: [Double] = [2, 4, 6]
    let sample2: [Double] = [1, 2, 3]

    let result = try GlifiStatisticalFoundation.welchTTest(sample1, sample2)

    // Calcolo indipendente diretto dalla formula dichiarata, non dal codice in prova.
    let mean1 = 4.0
    let mean2 = 2.0
    let variance1 = 4.0
    let variance2 = 1.0
    let expectedStatistic =
        (mean1 - mean2) / (variance1 / 3 + variance2 / 3).squareRoot()
    let expectedDegreesOfFreedom =
        (variance1 / 3 + variance2 / 3) * (variance1 / 3 + variance2 / 3)
        / ((variance1 / 3) * (variance1 / 3) / 2 + (variance2 / 3) * (variance2 / 3) / 2)

    #expect(abs(result.statistic - expectedStatistic) < 1e-9)
    #expect(abs(result.degreesOfFreedom - expectedDegreesOfFreedom) < 1e-9)
    #expect(result.pValue >= 0 && result.pValue <= 1)

    do {
        _ = try GlifiStatisticalFoundation.welchTTest([1], [1, 2])
        Issue.record("Un campione con n<2 non è stato rifiutato")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "statistics.insufficient-sample-size")
    }
    do {
        _ = try GlifiStatisticalFoundation.welchTTest([1, 1, 1], [1, 2, 3])
        Issue.record("La varianza nulla non è stata rifiutata")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "statistics.non-positive-variance")
    }
}

@Test("OneWayANOVA su tre gruppi noti produce F=12 e p=0,2³ esatto per identità chiusa")
func oneWayANOVAMatchesClosedFormCase() throws {
    // Gruppi a media equispaziata e uguale dispersione interna: SS_between=24,
    // SS_within=6, F=(24/2)/(6/6)=12 esatto. Con df1=2, df2=6, x=6/(6+2·12)=1/5;
    // I_x(3,1)=x³ in forma chiusa (B(a,1)=1/a), quindi p=0,2³=0,008 esatto.
    let groups: [[Double]] = [
        [1, 2, 3],
        [3, 4, 5],
        [5, 6, 7],
    ]

    let result = try GlifiStatisticalFoundation.oneWayANOVA(groups)

    #expect(abs(result.fStatistic - 12) < 1e-9)
    #expect(result.numeratorDegreesOfFreedom == 2)
    #expect(result.denominatorDegreesOfFreedom == 6)
    #expect(abs(result.pValue - 0.008) < 1e-9)
}

@Test("OneWayANOVA rifiuta gruppi insufficienti, vuoti o a varianza interna nulla")
func oneWayANOVARejectsInvalidGroups() throws {
    do {
        _ = try GlifiStatisticalFoundation.oneWayANOVA([[1, 2, 3]])
        Issue.record("Un solo gruppo non è stato rifiutato")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "statistics.insufficient-group-count")
    }
    do {
        _ = try GlifiStatisticalFoundation.oneWayANOVA([[1, 2], []])
        Issue.record("Un gruppo vuoto non è stato rifiutato")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "statistics.empty-group")
    }
    do {
        _ = try GlifiStatisticalFoundation.oneWayANOVA([[1, 1], [1, 1]])
        Issue.record("La varianza interna nulla non è stata rifiutata")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "statistics.degenerate-within-variance")
    }
}
