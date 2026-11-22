// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import NaturalLanguage
import Testing

@testable import GlifiCore

@Test(
    "Lo stemmer italiano 3.1 coincide con l'oracolo Snowball indipendente su 680 parole sintetiche")
func italianStemmingMatchesIndependentSnowball310() throws {
    let rows = italianStemmerOracle.split(separator: "\n", omittingEmptySubsequences: false)
    #expect(rows.count == 680)
    for row in rows {
        let fields = row.split(separator: "|", omittingEmptySubsequences: false)
        let word = String(try #require(fields.first))
        let expected = String(try #require(fields.last))
        #expect(try GlifiItalianStemmer.stem(word) == expected, Comment(rawValue: word))
    }
    #expect(try GlifiItalianStemmer.stem("L'ACQUA") == "acqua")
    #expect(try GlifiItalianStemmer.stem("divano") == "divan")
    #expect(try GlifiItalianStemmer.stem("citta\u{0300}") == GlifiItalianStemmer.stem("città"))
    #expect(GlifiItalianStemmer.identifier == "Snowball-Italian-3.1.0")
}

@Test("La vista superficiale resta identica al contratto precedente e preserva tutti gli offset")
func linguisticDefaultPreservesCodingContract() throws {
    let text = "L'acqua è già qui. Citta\u{0300}, città e 👩‍🔬.\n\nPortarglielo, un'amica: 12,5."
    let previous = try GlifiCodingDocument(id: "source", text: text, variables: ["group": "A"])
    let annotated = try GlifiLinguisticPipeline.annotate(text: text)
    let coding = try annotated.codingDocument(id: "source", variables: ["group": "A"])
    #expect(coding == previous)
    #expect(annotated.text == text)
    #expect(annotated.provenance.codingContractIdentifier == "it-token-v1.normalized-surface")
    #expect(annotated.provenance.modelVersion == nil)
    for token in annotated.tokens {
        #expect(token.range.text(in: text) == token.surface)
        #expect(token.lemma == nil && token.partOfSpeech == nil && token.stem == nil)
        #expect(token.lemmaState == .notRequested && token.partOfSpeechState == .notRequested)
    }
    #expect(
        try JSONDecoder().decode(
            GlifiLinguisticAnnotation.self, from: JSONEncoder().encode(annotated)) == annotated)
}

@Test("La vista degli stem mantiene superficie, paragrafi e intervalli senza chiamare un modello")
func linguisticStemsPreserveSourceCoordinates() throws {
    let text = "divano l'acqua accomodarci\n\nguardandogli citta\u{0300}"
    let result = try GlifiLinguisticPipeline.annotate(text: text, base: .italianSnowballStem)
    #expect(result.tokens.map(\.stem) == ["divan", "acqua", "accomod", "guard", "citt"])
    #expect(result.provenance.stemmingIdentifier == "Snowball-Italian-3.1.0")
    #expect(result.provenance.tokenizationIdentifier == "it-token-v1")
    let document = try result.codingDocument(id: "source")
    #expect(document.tokens.map(\.base) == ["divan", "acqua", "accomod", "guard", "citt"])
    #expect(document.tokens.last?.paragraph == 1)
    for token in document.tokens { #expect(token.range.text(in: text) == token.surface) }
}

@Test(
    "Le annotazioni Apple coincidono con le API native installate senza dichiarare accuratezza gold"
)
func appleLinguisticAnnotationsMatchInstalledTagger() throws {
    let available = try GlifiLinguisticPipeline.availability()
    #expect(available.hasItalianStemming)
    let text = "Le ragazze mangiavano mele. Citta\u{0300} e città."
    guard available.hasLemma && available.hasPartOfSpeech else {
        #expect(throws: GlifiFailure.self) {
            try GlifiLinguisticPipeline.annotate(
                text: text, base: .appleLemma, includePartOfSpeech: true)
        }
        return
    }
    let result = try GlifiLinguisticPipeline.annotate(
        text: text, base: .appleLemma, includePartOfSpeech: true)
    let reference = NLTagger(tagSchemes: [.lemma, .lexicalClass])
    reference.string = text
    reference.setLanguage(.italian, range: text.startIndex..<text.endIndex)
    var index = 0
    reference.enumerateTags(
        in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass,
        options: [.omitPunctuation, .omitWhitespace, .omitOther]
    ) { tag, range in
        guard index < result.tokens.count else {
            Issue.record("Missing output token")
            return false
        }
        let token = result.tokens[index]
        let (lemma, _) = reference.tag(at: range.lowerBound, unit: .word, scheme: .lemma)
        #expect(token.surface == String(text[range]))
        #expect(
            token.range.start
                == text.utf8.distance(from: text.utf8.startIndex, to: range.lowerBound))
        #expect(
            token.range.end == text.utf8.distance(from: text.utf8.startIndex, to: range.upperBound))
        #expect(token.lemma == lemma?.rawValue)
        #expect(token.partOfSpeech == tag?.rawValue)
        index += 1
        return true
    }
    #expect(index == result.tokens.count)
    #expect(result.provenance.operatingSystemVersion == available.operatingSystemVersion)
    #expect(result.provenance.partOfSpeechTagset == "Apple-NLTagSchemeLexicalClass")
    #expect(result.provenance.modelVersion == nil)
    #expect(result.provenance.modelVersionPolicy == "not-exposed-by-system-framework")
    #expect(result.provenance.predictionPolicy == "single-best-uncalibrated")
}

@Test("Un lemma sconosciuto resta nullo e non viene sostituito dalla forma nella codifica")
func linguisticUnknownAnnotationsFailClosedForCoding() throws {
    let base = try GlifiLinguisticPipeline.annotate(text: "ragazze")
    var object = try #require(
        JSONSerialization.jsonObject(with: JSONEncoder().encode(base)) as? [String: Any])
    var provenance = try #require(object["provenance"] as? [String: Any])
    provenance["base"] = "apple-lemma"
    object["provenance"] = provenance
    var tokens = try #require(object["tokens"] as? [[String: Any]])
    tokens[0]["lemma"] = NSNull()
    tokens[0]["lemmaState"] = "unknown"
    object["tokens"] = tokens
    let decoded = try JSONDecoder().decode(
        GlifiLinguisticAnnotation.self, from: JSONSerialization.data(withJSONObject: object))
    #expect(decoded.tokens[0].lemma == nil)
    do {
        _ = try decoded.codingDocument(id: "source")
        Issue.record("An unknown lemma was replaced by the surface")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "linguistic.missing-lemma")
        #expect(failure.category == .insufficientData && failure.retainedState == .unchanged)
    }
    provenance["base"] = "normalized-surface"
    provenance["includesPartOfSpeech"] = true
    object["provenance"] = provenance
    tokens[0]["partOfSpeech"] = NSNull()
    tokens[0]["partOfSpeechState"] = "unknown"
    object["tokens"] = tokens
    let missingPOS = try JSONDecoder().decode(
        GlifiLinguisticAnnotation.self, from: JSONSerialization.data(withJSONObject: object))
    do {
        _ = try missingPOS.codingDocument(id: "source")
        Issue.record("Unknown POS was accepted for annotated coding")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "linguistic.missing-pos")
    }
}

@Test("Limiti e lingua sono verificati senza download e senza output parziali")
func linguisticLimitsAndLanguageFailClosed() throws {
    for language in ["", "fr", "it-IT", "xx"] {
        #expect(throws: GlifiFailure.self) {
            try GlifiLinguisticPipeline.availability(languageTag: language)
        }
        #expect(throws: GlifiFailure.self) {
            try GlifiLinguisticPipeline.annotate(text: "ciao", languageTag: language)
        }
    }
    for limits in [
        GlifiLinguisticLimits(maximumTextBytes: 0), GlifiLinguisticLimits(maximumTokenCount: 0),
        GlifiLinguisticLimits(maximumTokenBytes: 1),
        GlifiLinguisticLimits(maximumOutputUTF8Bytes: 0),
        GlifiLinguisticLimits(maximumTextBytes: -1),
    ] {
        #expect(throws: GlifiFailure.self) {
            try GlifiLinguisticPipeline.annotate(text: "città", limits: limits)
        }
        let decodedInput = try GlifiLinguisticPipeline.annotate(text: "città")
        #expect(throws: GlifiFailure.self) {
            try decodedInput.codingDocument(id: "source", limits: limits)
        }
    }
    #expect(
        try GlifiLinguisticPipeline.annotate(
            text: "",
            limits: .init(maximumTextBytes: 0, maximumTokenCount: 0, maximumOutputUTF8Bytes: 0)
        ).tokens.isEmpty)
    #expect(throws: GlifiFailure.self) {
        try GlifiItalianStemmer.stem(String(repeating: "a", count: 4_097))
    }
}

@Test("La conversione di annotazioni esterne richiede byte identici e rifiuta intervalli corrotti")
func linguisticExternalAnnotationsRequireExactSourceBytes() throws {
    let original = try GlifiLinguisticPipeline.annotate(text: "citta\u{0300}")
    let data = try JSONEncoder().encode(original)
    let initial = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    for mutation in 0..<3 {
        var object = initial
        var tokens = try #require(object["tokens"] as? [[String: Any]])
        switch mutation {
        case 0:
            // Swift String equality accepts this canonical equivalent; source bytes differ.
            tokens[0]["surface"] = "città"
            #expect("città" == original.tokens[0].surface)
            #expect(!"città".utf8.elementsEqual(original.tokens[0].surface.utf8))
        case 1:
            tokens[0]["range"] = ["start": Int.max, "end": 0]
        case 2:
            tokens[0]["range"] = ["start": 0, "end": Int.max]
        default:
            Issue.record("Unexpected synthetic mutation")
        }
        object["tokens"] = tokens
        do {
            let decoded = try JSONDecoder().decode(
                GlifiLinguisticAnnotation.self, from: JSONSerialization.data(withJSONObject: object)
            )
            _ = try decoded.codingDocument(id: "source")
            Issue.record("A corrupt annotation was accepted")
        } catch let failure as GlifiFailure {
            #expect(
                failure.code
                    == (mutation == 1 ? "text.invalid-range" : "linguistic.invalid-token-range"))
            #expect(failure.category == .invalidInput && failure.retainedState == .unchanged)
        }
    }
    #expect(
        try original.codingDocument(id: "source").tokens[0].surface.utf8.elementsEqual(
            original.text.utf8))
}

@Test("Cancellazione già richiesta interrompe annotazione e stemming prima del lavoro")
func linguisticCancellationPrecedesPreparation() async throws {
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        _ = try GlifiLinguisticPipeline.annotate(text: String(repeating: "ragazze ", count: 100))
    }
    await #expect(throws: CancellationError.self) { try await task.value }
    let stemTask = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        _ = try GlifiItalianStemmer.stem("ragazze")
    }
    await #expect(throws: CancellationError.self) { try await stemTask.value }
}

@Test("Chiamate concorrenti possiedono tagger separati e conservano gli stessi output")
func linguisticConcurrentCallsUseIndependentTaggers() async throws {
    let available = try GlifiLinguisticPipeline.availability()
    guard available.hasLemma && available.hasPartOfSpeech else { return }
    let text = "Le ragazze mangiavano mele. La città è qui."
    let expected = try GlifiLinguisticPipeline.annotate(
        text: text, base: .appleLemma, includePartOfSpeech: true)
    try await withThrowingTaskGroup(of: GlifiLinguisticAnnotation.self) { group in
        for _ in 0..<8 {
            group.addTask {
                try GlifiLinguisticPipeline.annotate(
                    text: text, base: .appleLemma, includePartOfSpeech: true)
            }
        }
        for try await result in group { #expect(result == expected) }
    }
}

// Synthetic vocabulary; no user corpus or third-party vocabulary is incorporated.
// Independent oracle: https://snowballstem.org/js/italian-stemmer.js, retrieved 2026-11-22.
// Compiler-generated reference SHA-256: adb64297fe71cca64c7b0bb3b4c33de5e895528465c6d3925b6f85e2905cc9ea.
// Its runtime SHA-256: 0a645d4a7b1cf57200345cf323cbfa0fe79d872590b5d0261a7271ff293b74b6.
// NFC/Italian lowercase is applied before the reference, as specified by the public wrapper.
// Only synthetic inputs and outputs are retained; no reference implementation enters the product.
private let italianStemmerOracle = """
    |
    a|a
    e|e
    i|i
    o|o
    u|u
    à|à
    è|è
    ì|ì
    ò|ò
    ù|ù
    divano|divan
    divani|divan
    divana|divan
    divanetti|divanett
    diva|div
    divan|divan
    divanissimo|divanissim
    acqua|acqua
    acque|acque
    crocchi|crocc
    crocchio|crocc
    parche|parc
    larghe|larg
    aiuola|aiuol
    aiuole|aiuol
    guai|gua
    quiete|qui
    mangiando|mang
    guardandogli|guard
    accomodarci|accomod
    portarglielo|port
    mangiandovene|mang
    mangiarvela|mang
    mangiata|mang
    città|citt
    perché|perc
    perchè|perc
    l'|l'
    c'era|c'er
    sant'antonio|sant'anton
    l’acqua|l’acqu
    quest’anno|quest’ann
    amanza|amanz
    amanze|amanz
    amico|amic
    amici|amic
    amica|amic
    amice|amic
    amiche|amic
    amichi|amic
    amismo|amism
    amismi|amism
    amabile|amabil
    amabili|amabil
    amibile|amibil
    amibili|amibil
    amista|amist
    amiste|amist
    amisti|amist
    amistà|amist
    amistè|amist
    amistì|amist
    amoso|amos
    amosi|amos
    amosa|amos
    amose|amos
    ammente|amment
    amatrice|amatric
    amatrici|amatric
    amante|amant
    amanti|amant
    amazione|amazion
    amazioni|amazion
    amatore|amator
    amatori|amator
    amlogia|amlog
    amlogie|amlog
    amuzione|amuzion
    amuzioni|amuzion
    amusione|amusion
    amusioni|amusion
    amenza|amenz
    amenze|amenz
    amamento|amament
    amamenti|amament
    amimento|amiment
    amimenti|amiment
    amamente|am
    amità|amit
    amivo|amiv
    amivi|amiv
    amiva|amiv
    amive|amiv
    amammo|amamm
    amando|amand
    amano|aman
    amare|amar
    amarono|amar
    amasse|amass
    amassero|amasser
    amassi|amass
    amassimo|amassim
    amata|amat
    amate|amat
    amati|amat
    amato|amat
    amava|amav
    amavamo|amavam
    amavano|amav
    amavate|amav
    amavi|amav
    amavo|amav
    amemmo|amemm
    amenda|amend
    amende|amend
    amendi|amend
    amendo|amend
    amerà|amer
    amerai|amera
    ameranno|amerann
    amere|amer
    amerebbe|amerebb
    amerebbero|amerebber
    amerei|amere
    ameremmo|amer
    ameremo|amerem
    amereste|amerest
    ameresti|amerest
    amerete|amer
    amerò|amer
    amerono|amer
    amessero|amesser
    amete|amet
    ameva|amev
    amevamo|amevam
    amevano|amev
    amevate|amev
    amevi|amev
    amevo|amev
    amYamo|amyam
    amiamo|amiam
    amimmo|amimm
    amirà|amir
    amirai|amira
    amiranno|amirann
    amire|amir
    amirebbe|amirebb
    amirebbero|amirebber
    amirei|amire
    amiremmo|amir
    amiremo|amirem
    amireste|amirest
    amiresti|amirest
    amirete|amir
    amirò|amir
    amirono|amir
    amisca|amisc
    amiscano|amisc
    amisce|amisc
    amisci|amisc
    amisco|amisc
    amiscono|amisc
    amissero|amisser
    amita|amit
    amite|amit
    amiti|amit
    amito|amit
    amivamo|amivam
    amivano|amiv
    amivate|amiv
    amono|amon
    amuta|amut
    amute|amut
    amuti|amut
    amuto|amut
    amar|amar
    amir|amir
    comunicanza|comunic
    comunicanze|comunic
    comunicico|comunic
    comunicici|comunic
    comunicica|comunic
    comunicice|comunic
    comuniciche|comunic
    comunicichi|comunic
    comunicismo|comunic
    comunicismi|comunic
    comunicabile|comunic
    comunicabili|comunic
    comunicibile|comunic
    comunicibili|comunic
    comunicista|comunic
    comuniciste|comunic
    comunicisti|comunic
    comunicistà|comunic
    comunicistè|comunic
    comunicistì|comunic
    comunicoso|comunic
    comunicosi|comunic
    comunicosa|comunic
    comunicose|comunic
    comunicmente|comunic
    comunicatrice|comunic
    comunicatrici|comunic
    comunicante|comunic
    comunicanti|comunic
    comunicazione|comun
    comunicazioni|comun
    comunicatore|comun
    comunicatori|comun
    comuniclogia|comuniclog
    comuniclogie|comuniclog
    comunicuzione|comunicu
    comunicuzioni|comunicu
    comunicusione|comunicu
    comunicusioni|comunicu
    comunicenza|comunicent
    comunicenze|comunicent
    comunicamento|comunic
    comunicamenti|comunic
    comunicimento|comunic
    comunicimenti|comunic
    comunicamente|comun
    comunicità|comun
    comunicivo|comunic
    comunicivi|comunic
    comuniciva|comunic
    comunicive|comunic
    comunicammo|comunic
    comunicando|comunic
    comunicano|comunic
    comunicare|comunic
    comunicarono|comunic
    comunicasse|comunic
    comunicassero|comunic
    comunicassi|comunic
    comunicassimo|comunic
    comunicata|comunic
    comunicate|comunic
    comunicati|comunic
    comunicato|comunic
    comunicava|comunic
    comunicavamo|comunic
    comunicavano|comunic
    comunicavate|comunic
    comunicavi|comunic
    comunicavo|comunic
    comunicemmo|comunic
    comunicenda|comunic
    comunicende|comunic
    comunicendi|comunic
    comunicendo|comunic
    comunicerà|comunic
    comunicerai|comunic
    comuniceranno|comunic
    comunicere|comunic
    comunicerebbe|comunic
    comunicerebbero|comunic
    comunicerei|comunic
    comuniceremmo|comunic
    comuniceremo|comunic
    comunicereste|comunic
    comuniceresti|comunic
    comunicerete|comunic
    comunicerò|comunic
    comunicerono|comunic
    comunicessero|comunic
    comunicete|comunic
    comuniceva|comunic
    comunicevamo|comunic
    comunicevano|comunic
    comunicevate|comunic
    comunicevi|comunic
    comunicevo|comunic
    comunicYamo|comunicyam
    comuniciamo|comunic
    comunicimmo|comunic
    comunicirà|comunic
    comunicirai|comunic
    comuniciranno|comunic
    comunicire|comunic
    comunicirebbe|comunic
    comunicirebbero|comunic
    comunicirei|comunic
    comuniciremmo|comunic
    comuniciremo|comunic
    comunicireste|comunic
    comuniciresti|comunic
    comunicirete|comunic
    comunicirò|comunic
    comunicirono|comunic
    comunicisca|comunic
    comuniciscano|comunic
    comunicisce|comunic
    comunicisci|comunic
    comunicisco|comunic
    comuniciscono|comunic
    comunicissero|comunic
    comunicita|comunic
    comunicite|comunic
    comuniciti|comunic
    comunicito|comunic
    comunicivamo|comunic
    comunicivano|comunic
    comunicivate|comunic
    comunicono|comunic
    comunicuta|comunic
    comunicute|comunic
    comunicuti|comunic
    comunicuto|comunic
    comunicar|comunic
    comunicir|comunic
    creativanza|creativ
    creativanze|creativ
    creativico|creativ
    creativici|creativ
    creativica|creativ
    creativice|creativ
    creativiche|creativ
    creativichi|creativ
    creativismo|creativ
    creativismi|creativ
    creativabile|creativ
    creativabili|creativ
    creativibile|creativ
    creativibili|creativ
    creativista|creativ
    creativiste|creativ
    creativisti|creativ
    creativistà|creativ
    creativistè|creativ
    creativistì|creativ
    creativoso|creativ
    creativosi|creativ
    creativosa|creativ
    creativose|creativ
    creativmente|creativ
    creativatrice|creativ
    creativatrici|creativ
    creativante|creativ
    creativanti|creativ
    creativazione|creativ
    creativazioni|creativ
    creativatore|creativ
    creativatori|creativ
    creativlogia|creativlog
    creativlogie|creativlog
    creativuzione|creativu
    creativuzioni|creativu
    creativusione|creativu
    creativusioni|creativu
    creativenza|creativent
    creativenze|creativent
    creativamento|creativ
    creativamenti|creativ
    creativimento|creativ
    creativimenti|creativ
    creativamente|creativ
    creatività|creativ
    creativivo|creativ
    creativivi|creativ
    creativiva|creativ
    creativive|creativ
    creativammo|creativ
    creativando|creativ
    creativano|creat
    creativare|creativ
    creativarono|creativ
    creativasse|creativ
    creativassero|creativ
    creativassi|creativ
    creativassimo|creativ
    creativata|creativ
    creativate|creat
    creativati|creativ
    creativato|creativ
    creativava|creativ
    creativavamo|creativ
    creativavano|creativ
    creativavate|creativ
    creativavi|creativ
    creativavo|creativ
    creativemmo|creativ
    creativenda|creativ
    creativende|creativ
    creativendi|creativ
    creativendo|creativ
    creativerà|creativ
    creativerai|creativ
    creativeranno|creativ
    creativere|creativ
    creativerebbe|creativ
    creativerebbero|creativ
    creativerei|creativ
    creativeremmo|creativ
    creativeremo|creativ
    creativereste|creativ
    creativeresti|creativ
    creativerete|creativ
    creativerò|creativ
    creativerono|creativ
    creativessero|creativ
    creativete|creativ
    creativeva|creativ
    creativevamo|creativ
    creativevano|creativ
    creativevate|creativ
    creativevi|creativ
    creativevo|creativ
    creativYamo|creativyam
    creativiamo|creativ
    creativimmo|creativ
    creativirà|creativ
    creativirai|creativ
    creativiranno|creativ
    creativire|creativ
    creativirebbe|creativ
    creativirebbero|creativ
    creativirei|creativ
    creativiremmo|creativ
    creativiremo|creativ
    creativireste|creativ
    creativiresti|creativ
    creativirete|creativ
    creativirò|creativ
    creativirono|creativ
    creativisca|creativ
    creativiscano|creativ
    creativisce|creativ
    creativisci|creativ
    creativisco|creativ
    creativiscono|creativ
    creativissero|creativ
    creativita|creativ
    creativite|creativ
    creativiti|creativ
    creativito|creativ
    creativivamo|creativ
    creativivano|creativ
    creativivate|creativ
    creativono|creativ
    creativuta|creativ
    creativute|creativ
    creativuti|creativ
    creativuto|creativ
    creativar|creativ
    creativir|creativ
    mangiandoci|mang
    mangiandogli|mang
    mangiandola|mang
    mangiandole|mang
    mangiandoli|mang
    mangiandolo|mang
    mangiandomi|mang
    mangiandone|mang
    mangiandosi|mang
    mangiandoti|mang
    mangiandovi|mang
    mangiandosene|mang
    mangiandogliela|mang
    mangiandogliele|mang
    mangiandoglieli|mang
    mangiandoglielo|mang
    mangiandogliene|mang
    mangiandomela|mang
    mangiandomele|mang
    mangiandomeli|mang
    mangiandomelo|mang
    mangiandomene|mang
    mangiandotela|mang
    mangiandotele|mang
    mangiandoteli|mang
    mangiandotelo|mang
    mangiandotene|mang
    mangiandocela|mang
    mangiandocele|mang
    mangiandoceli|mang
    mangiandocelo|mang
    mangiandocene|mang
    mangiandovela|mang
    mangiandovele|mang
    mangiandoveli|mang
    mangiandovelo|mang
    vedendoci|ved
    vedendogli|ved
    vedendola|ved
    vedendole|ved
    vedendoli|ved
    vedendolo|ved
    vedendomi|ved
    vedendone|ved
    vedendosi|ved
    vedendoti|ved
    vedendovi|ved
    vedendosene|ved
    vedendogliela|ved
    vedendogliele|ved
    vedendoglieli|ved
    vedendoglielo|ved
    vedendogliene|ved
    vedendomela|ved
    vedendomele|ved
    vedendomeli|ved
    vedendomelo|ved
    vedendomene|ved
    vedendotela|ved
    vedendotele|ved
    vedendoteli|ved
    vedendotelo|ved
    vedendotene|ved
    vedendocela|ved
    vedendocele|ved
    vedendoceli|ved
    vedendocelo|ved
    vedendocene|ved
    vedendovela|ved
    vedendovele|ved
    vedendoveli|ved
    vedendovelo|ved
    vedendovene|ved
    parlarci|parl
    parlargli|parl
    parlarla|parl
    parlarle|parl
    parlarli|parl
    parlarlo|parl
    parlarmi|parl
    parlarne|parl
    parlarsi|parl
    parlarti|parl
    parlarvi|parl
    parlarsene|parl
    parlargliela|parl
    parlargliele|parl
    parlarglieli|parl
    parlarglielo|parl
    parlargliene|parl
    parlarmela|parl
    parlarmele|parl
    parlarmeli|parl
    parlarmelo|parl
    parlarmene|parl
    parlartela|parl
    parlartele|parl
    parlarteli|parl
    parlartelo|parl
    parlartene|parl
    parlarcela|parl
    parlarcele|parl
    parlarceli|parl
    parlarcelo|parl
    parlarcene|parl
    parlarvela|parl
    parlarvele|parl
    parlarveli|parl
    parlarvelo|parl
    parlarvene|parl
    vederci|ved
    vedergli|ved
    vederla|ved
    vederle|ved
    vederli|ved
    vederlo|ved
    vedermi|ved
    vederne|ved
    vedersi|ved
    vederti|ved
    vedervi|ved
    vedersene|ved
    vedergliela|ved
    vedergliele|ved
    vederglieli|ved
    vederglielo|ved
    vedergliene|ved
    vedermela|ved
    vedermele|ved
    vedermeli|ved
    vedermelo|ved
    vedermene|ved
    vedertela|ved
    vedertele|ved
    vederteli|ved
    vedertelo|ved
    vedertene|ved
    vedercela|ved
    vedercele|ved
    vederceli|ved
    vedercelo|ved
    vedercene|ved
    vedervela|ved
    vedervele|ved
    vederveli|ved
    vedervelo|ved
    vedervene|ved
    sentirci|sent
    sentirgli|sent
    sentirla|sent
    sentirle|sent
    sentirli|sent
    sentirlo|sent
    sentirmi|sent
    sentirne|sent
    sentirsi|sent
    sentirti|sent
    sentirvi|sent
    sentirsene|sent
    sentirgliela|sent
    sentirgliele|sent
    sentirglieli|sent
    sentirglielo|sent
    sentirgliene|sent
    sentirmela|sent
    sentirmele|sent
    sentirmeli|sent
    sentirmelo|sent
    sentirmene|sent
    sentirtela|sent
    sentirtele|sent
    sentirteli|sent
    sentirtelo|sent
    sentirtene|sent
    sentircela|sent
    sentircele|sent
    sentirceli|sent
    sentircelo|sent
    sentircene|sent
    sentirvela|sent
    sentirvele|sent
    sentirveli|sent
    sentirvelo|sent
    sentirvene|sent
    d'amiche|amic
    d'università|univers
    d'studiare|stud
    l'amiche|amic
    l'università|univers
    l'studiare|stud
    m'amiche|amic
    m'università|univers
    m'studiare|stud
    s'amiche|amic
    s'università|univers
    s'studiare|stud
    t'amiche|amic
    t'università|univers
    t'studiare|stud
    v'amiche|amic
    v'università|univers
    v'studiare|stud
    all'amiche|amic
    all'università|univers
    all'studiare|stud
    dall'amiche|amic
    dall'università|univers
    dall'studiare|stud
    dell'amiche|amic
    dell'università|univers
    dell'studiare|stud
    gl'amiche|amic
    gl'università|univers
    gl'studiare|stud
    nell'amiche|amic
    nell'università|univers
    nell'studiare|stud
    quell'amiche|amic
    quell'università|univers
    quell'studiare|stud
    quest'amiche|amic
    quest'università|univers
    quest'studiare|stud
    sull'amiche|amic
    sull'università|univers
    sull'studiare|stud
    tutt'amiche|amic
    tutt'università|univers
    tutt'studiare|stud
    un'amiche|amic
    un'università|univers
    un'studiare|stud
    """
