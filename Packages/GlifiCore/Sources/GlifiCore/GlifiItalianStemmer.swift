// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// A native implementation of the published Snowball Italian 3.1.0 rules.
///
/// The implementation is original Swift written from the algorithm specification:
/// https://snowballstem.org/algorithms/italian/stemmer.html.
/// It includes the 3.0.0 `divan` region exception and the 3.1.0 elision rules.
/// NFC and Italian lowercase are explicit input views; source text is never changed.
public enum GlifiItalianStemmer {
    /// Exact rule revision implemented by this stemmer.
    public static let identifier = "Snowball-Italian-3.1.0"
    /// Versioned normalization applied before the published lowercase-word algorithm.
    public static let normalizationIdentifier = "NFC-Italian-lowercase-v1"
    /// Maximum UTF-8 bytes accepted for one token before normalization or allocation.
    public static let maximumTokenBytes = 4_096

    /// Returns an Italian stem without using a linguistic model or modifying source coordinates.
    public static func stem(_ word: String) throws -> String {
        try Task.checkCancellation()
        guard word.utf8.count <= maximumTokenBytes else {
            throw linguisticPipelineFailure(
                "linguistic.token-limit", category: .insufficientResources)
        }
        let normalized = word.precomposedStringWithCanonicalMapping.lowercased(
            with: Locale(identifier: "it_IT"))
        var buffer = normalized.unicodeScalars.map(\.value)
        guard !buffer.isEmpty else { return "" }
        removeElision(from: &buffer)
        prepareVowels(in: &buffer)
        let firstRegion = region(after: 0, in: buffer)
        let secondRegion = region(after: firstRegion, in: buffer)
        let verbRegion = romanceVerbRegion(in: buffer)
        removePronoun(from: &buffer, verbRegion: verbRegion)
        if !removeStandardSuffix(
            from: &buffer, firstRegion: firstRegion, secondRegion: secondRegion,
            verbRegion: verbRegion)
        {
            if let ending = longestSuffix(in: buffer, candidates: verbEndings, region: verbRegion) {
                buffer.removeLast(ending.count)
            }
        }
        if let last = buffer.last, finalVowels.contains(last), buffer.count - 1 >= verbRegion {
            buffer.removeLast()
            if buffer.last == 105, buffer.count - 1 >= verbRegion { buffer.removeLast() }
        }
        if buffer.count >= 2, buffer.last == 104,
            buffer[buffer.count - 2] == 99 || buffer[buffer.count - 2] == 103,
            buffer.count - 2 >= verbRegion
        {
            buffer.removeLast()
        }
        var result = String.UnicodeScalarView()
        for scalar in buffer {
            let restored = scalar == 73 ? 105 : (scalar == 85 ? 117 : scalar)
            if let value = UnicodeScalar(restored) { result.append(value) }
        }
        return String(result)
    }
}

private enum ItalianSuffixAction: Sendable {
    case removeInSecondRegion
    case removeAndIC
    case replaceWithLog
    case replaceWithU
    case replaceWithEnte
    case removeInVerbRegion
    case adverb
    case quality
    case adjective
}

private struct ItalianStandardSuffix: Sendable {
    let values: [UInt32]
    let action: ItalianSuffixAction
}

private let italianVowels: Set<UInt32> = Set("aeiouàèìòù".unicodeScalars.map(\.value))
private let finalVowels: Set<UInt32> = Set("aeioàèìò".unicodeScalars.map(\.value))
private let elisionPrefixes =
    [
        "d'", "l'", "m'", "s'", "t'", "v'", "all'", "dall'", "dell'", "gl'", "nell'",
        "quell'", "quest'", "sull'", "tutt'", "un'",
    ]
    .map { $0.unicodeScalars.map(\.value) }
private let pronounEndings = scalarSuffixes(
    "ci gli la le li lo mi ne si ti vi sene gliela gliele glieli glielo gliene mela mele meli melo mene tela tele teli telo tene cela cele celi celo cene vela vele veli velo vene"
)
private let verbEndings = scalarSuffixes(
    "ammo ando ano are arono asse assero assi assimo ata ate ati ato ava avamo avano avate avi avo emmo enda ende endi endo erà erai eranno ere erebbe erebbero erei eremmo eremo ereste eresti erete erò erono essero ete eva evamo evano evate evi evo Yamo iamo immo irà irai iranno ire irebbe irebbero irei iremmo iremo ireste iresti irete irò irono isca iscano isce isci isco iscono issero ita ite iti ito iva ivamo ivano ivate ivi ivo ono uta ute uti uto ar ir"
)
private let standardEndings: [ItalianStandardSuffix] = {
    let groups: [(String, ItalianSuffixAction)] = [
        (
            "anza anze ico ici ica ice iche ichi ismo ismi abile abili ibile ibili ista iste isti istà istè istì oso osi osa ose mente atrice atrici ante anti",
            .removeInSecondRegion
        ),
        ("azione azioni atore atori", .removeAndIC),
        ("logia logie", .replaceWithLog),
        ("uzione uzioni usione usioni", .replaceWithU),
        ("enza enze", .replaceWithEnte),
        ("amento amenti imento imenti", .removeInVerbRegion),
        ("amente", .adverb), ("ità", .quality), ("ivo ivi iva ive", .adjective),
    ]
    return groups.flatMap { text, action in
        scalarSuffixes(text).map { ItalianStandardSuffix(values: $0, action: action) }
    }.sorted { $0.values.count > $1.values.count }
}()

private func scalarSuffixes(_ text: String) -> [[UInt32]] {
    text.split(separator: " ").map { $0.unicodeScalars.map(\.value) }
        .sorted { $0.count > $1.count }
}

private func longestSuffix(in word: [UInt32], candidates: [[UInt32]], region: Int = 0) -> [UInt32]?
{
    candidates.first { $0.count <= word.count - region && word.suffix($0.count).elementsEqual($0) }
}

private func removeElision(from word: inout [UInt32]) {
    if let prefix = elisionPrefixes.first(where: { word.count > $0.count && word.starts(with: $0) })
    {
        word.removeFirst(prefix.count)
    }
}

private func prepareVowels(in word: inout [UInt32]) {
    for index in word.indices {
        switch word[index] {
        case 225: word[index] = 224
        case 233: word[index] = 232
        case 237: word[index] = 236
        case 243: word[index] = 242
        case 250: word[index] = 249
        case 117 where index > 0 && word[index - 1] == 113: word[index] = 85
        default: break
        }
    }
    guard word.count >= 3 else { return }
    for index in 1..<(word.count - 1)
    where (word[index] == 105 || word[index] == 117)
        && italianVowels.contains(word[index - 1]) && italianVowels.contains(word[index + 1])
    {
        word[index] = word[index] == 105 ? 73 : 85
    }
}

private func region(after start: Int, in word: [UInt32]) -> Int {
    guard start + 1 < word.count else { return word.count }
    for index in (start + 1)..<word.count
    where italianVowels.contains(word[index - 1]) && !italianVowels.contains(word[index]) {
        return index + 1
    }
    return word.count
}

private func romanceVerbRegion(in word: [UInt32]) -> Int {
    if word.starts(with: [100, 105, 118, 97, 110]) { return 5 }
    guard word.count >= 3 else { return word.count }
    if !italianVowels.contains(word[1]) {
        return (2..<word.count).first { italianVowels.contains(word[$0]) }.map { $0 + 1 }
            ?? word.count
    }
    if italianVowels.contains(word[0]) {
        return (2..<word.count).first { !italianVowels.contains(word[$0]) }.map { $0 + 1 }
            ?? word.count
    }
    return 3
}

private func removePronoun(from word: inout [UInt32], verbRegion: Int) {
    guard let pronoun = longestSuffix(in: word, candidates: pronounEndings) else { return }
    let boundary = word.count - pronoun.count
    for ending in scalarPronounHosts {
        let start = boundary - ending.count
        if start >= verbRegion, word[start..<boundary].elementsEqual(ending) {
            word.removeLast(pronoun.count)
            if ending.count == 2 { word.append(101) }
            return
        }
    }
}

private let scalarPronounHosts = scalarSuffixes("ando endo ar er ir")

private func removeStandardSuffix(
    from word: inout [UInt32], firstRegion: Int, secondRegion: Int, verbRegion: Int
) -> Bool {
    guard
        let suffix = standardEndings.first(where: {
            word.suffix($0.values.count).elementsEqual($0.values)
        })
    else { return false }
    let start = word.count - suffix.values.count
    let requiredRegion: Int
    switch suffix.action {
    case .removeInVerbRegion: requiredRegion = verbRegion
    case .adverb: requiredRegion = firstRegion
    case .removeInSecondRegion, .removeAndIC, .replaceWithLog, .replaceWithU, .replaceWithEnte,
        .quality, .adjective:
        requiredRegion = secondRegion
    }
    guard start >= requiredRegion else { return false }
    word.removeLast(suffix.values.count)
    switch suffix.action {
    case .removeInSecondRegion, .removeInVerbRegion: break
    case .removeAndIC:
        _ = removeSuffix("ic", from: &word, region: secondRegion)
    case .replaceWithLog: word.append(contentsOf: [108, 111, 103])
    case .replaceWithU: word.append(117)
    case .replaceWithEnte: word.append(contentsOf: [101, 110, 116, 101])
    case .adverb:
        if removeSuffix("iv", from: &word, region: secondRegion) {
            _ = removeSuffix("at", from: &word, region: secondRegion)
        } else {
            for ending in ["os", "ic", "abil"]
            where removeSuffix(ending, from: &word, region: secondRegion) { break }
        }
    case .quality:
        for ending in ["abil", "ic", "iv"]
        where removeSuffix(ending, from: &word, region: secondRegion) { break }
    case .adjective:
        if removeSuffix("at", from: &word, region: secondRegion) {
            _ = removeSuffix("ic", from: &word, region: secondRegion)
        }
    }
    return true
}

private func removeSuffix(_ suffix: String, from word: inout [UInt32], region: Int) -> Bool {
    let values = suffix.unicodeScalars.map(\.value)
    guard word.count - values.count >= region, word.suffix(values.count).elementsEqual(values)
    else {
        return false
    }
    word.removeLast(values.count)
    return true
}
