// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("Cohen's Kappa vale 1 sull'accordo perfetto e 0 sull'accordo casuale, per calcolo esatto")
func cohenKappaMatchesExactCases() throws {
    // Accordo perfetto: p_o=1; p_e=(3/5)²+(2/5)²=13/25=0,52 → κ=(1-0,52)/(1-0,52)=1.
    let perfect = try GlifiAgreementAnalysis.cohenKappa(
        rater1: ["a", "b", "a", "b", "a"],
        rater2: ["a", "b", "a", "b", "a"]
    )
    #expect(abs(perfect.observedAgreement - 1) < 1e-12)
    #expect(abs(perfect.expectedAgreement - 0.52) < 1e-12)
    #expect(abs(perfect.kappa - 1) < 1e-9)

    // Accordo al livello del caso: p_o=0,5; p_e=(2/4)²+(2/4)²=0,5 → κ=0.
    let chance = try GlifiAgreementAnalysis.cohenKappa(
        rater1: ["a", "a", "b", "b"],
        rater2: ["a", "b", "a", "b"]
    )
    #expect(abs(chance.observedAgreement - 0.5) < 1e-12)
    #expect(abs(chance.expectedAgreement - 0.5) < 1e-12)
    #expect(abs(chance.kappa) < 1e-9)

    // p_e=1 (nessuna variabilità): kappa non definito.
    do {
        _ = try GlifiAgreementAnalysis.cohenKappa(
            rater1: ["a", "a", "a"],
            rater2: ["a", "a", "a"]
        )
        Issue.record("Il caso p_e=1 non è stato rifiutato")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "agreement.kappa-undefined")
    }

    do {
        _ = try GlifiAgreementAnalysis.cohenKappa(rater1: ["a", "b"], rater2: ["a"])
        Issue.record("La forma disallineata non è stata rifiutata")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "agreement.shape-mismatch")
    }
}

@Test(
    "Krippendorff's Alpha vale 1 sull'accordo perfetto ed è non definito a disaccordo atteso nullo"
)
func krippendorffAlphaMatchesExactCases() throws {
    // Due unità, tre codificatori, accordo perfetto entro ciascuna unità:
    // D_o=0 (nessuna cella fuori diagonale) e D_e>0 (categorie diverse fra
    // unità) → alpha=1 esatto per calcolo indipendente sulla formula dichiarata.
    let perfect = try GlifiAgreementAnalysis.krippendorffAlphaNominal([
        ["a", "a", "a"],
        ["b", "b", "b"],
    ])
    #expect(abs(perfect.observedDisagreement) < 1e-12)
    #expect(abs(perfect.expectedDisagreement - 0.6) < 1e-9)
    #expect(abs(perfect.alpha - 1) < 1e-9)
    #expect(perfect.includedUnitCount == 2)

    // Un'unica categoria ovunque: D_e=0, alpha non definito.
    do {
        _ = try GlifiAgreementAnalysis.krippendorffAlphaNominal([
            ["a", "a", "a"],
            ["a", "a", "a"],
        ])
        Issue.record("Il disaccordo atteso nullo non è stato rifiutato")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "agreement.alpha-undefined")
    }

    // Unità con un solo giudizio non contribuiscono: se nessuna qualifica,
    // il calcolo è rifiutato.
    do {
        _ = try GlifiAgreementAnalysis.krippendorffAlphaNominal([["a"], ["b"]])
        Issue.record("L'assenza di unità qualificate non è stata rifiutata")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "agreement.insufficient-units")
    }

    // Mancanti espliciti: l'unità con un solo giudizio non nullo è esclusa,
    // le altre restano valide.
    let withMissing = try GlifiAgreementAnalysis.krippendorffAlphaNominal([
        ["a", "a", "a"],
        ["b", nil, "b"],
        ["a", nil, nil],
    ])
    #expect(withMissing.includedUnitCount == 2)
}

@Test("Le misure d'accordo sono identiche bit a bit su richieste uguali e su tipi di categoria")
func agreementMeasuresAreBitIdenticalAcrossRepeatedCalls() throws {
    // Regressione: le somme seguivano l'ordine di un insieme hash, non riproducibile fra
    // istanze, e l'ultima cifra di D_e cambiava fra due analisi della stessa richiesta.
    let units: [[String?]] = [
        ["mare", "mare"], ["porto", "mare"], ["monti", "monti"], ["mare", nil],
        ["porto", "porto"], [nil, "monti"], ["monti", "porto"], ["mare", "porto"],
    ]
    let first = try GlifiAgreementAnalysis.krippendorffAlphaNominal(units)
    for _ in 0..<32 {
        let repeated = try GlifiAgreementAnalysis.krippendorffAlphaNominal(units)
        #expect(repeated == first)
        #expect(repeated.expectedDisagreement.bitPattern == first.expectedDisagreement.bitPattern)
        #expect(repeated.alpha.bitPattern == first.alpha.bitPattern)
    }

    let raters = (
        first: ["mare", "porto", "monti", "mare", "porto", "monti", "mare", "monti"],
        second: ["mare", "mare", "monti", "porto", "porto", "monti", "porto", "monti"]
    )
    let kappa = try GlifiAgreementAnalysis.cohenKappa(rater1: raters.first, rater2: raters.second)
    for _ in 0..<32 {
        let repeated = try GlifiAgreementAnalysis.cohenKappa(
            rater1: raters.first, rater2: raters.second)
        #expect(repeated.expectedAgreement.bitPattern == kappa.expectedAgreement.bitPattern)
        #expect(repeated.kappa.bitPattern == kappa.kappa.bitPattern)
    }

    let fleiss = try GlifiAgreementAnalysis.fleissKappa(
        units.map { $0.compactMap { $0 } }.filter { $0.count == 2 })
    for _ in 0..<32 {
        let repeated = try GlifiAgreementAnalysis.fleissKappa(
            units.map { $0.compactMap { $0 } }.filter { $0.count == 2 })
        #expect(repeated.observedAgreement.bitPattern == fleiss.observedAgreement.bitPattern)
        #expect(repeated.kappa.bitPattern == fleiss.kappa.bitPattern)
    }

    // L'esito non dipende dal tipo di categoria: gli interi danno le stesse misure.
    let coded: [[Int?]] = units.map { unit in
        unit.map { label in label.flatMap { ["mare": 0, "porto": 1, "monti": 2][$0] } }
    }
    let integerAlpha = try GlifiAgreementAnalysis.krippendorffAlphaNominal(coded)
    #expect(integerAlpha == first)
}
