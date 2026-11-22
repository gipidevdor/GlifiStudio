// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// One token supplied by a linguistic backend, preserving its source coordinates.
public struct GlifiCodingToken: Equatable, Sendable {
    /// Surface form, case-sensitive when explicitly constrained.
    public let surface: String
    /// Normalized form or backend lemma.
    public let base: String
    /// Optional backend POS tag.
    public let partOfSpeech: String?
    /// Optional backend inflection tag.
    public let inflection: String?
    /// UTF-8 range in extracted text.
    public let range: GlifiUTF8Range
    /// Sentence identity within the document.
    public let sentence: Int
    /// Paragraph identity within the document.
    public let paragraph: Int

    /// Creates an explicit linguistic observation without synthesizing absent annotations.
    public init(
        surface: String, base: String, partOfSpeech: String? = nil, inflection: String? = nil,
        range: GlifiUTF8Range, sentence: Int, paragraph: Int
    ) {
        self.surface = surface
        self.base = base
        self.partOfSpeech = partOfSpeech
        self.inflection = inflection
        self.range = range
        self.sentence = sentence
        self.paragraph = paragraph
    }
}

/// An immutable coding unit, with an explicit linguistic contract and external variables.
public struct GlifiCodingDocument: Equatable, Sendable {
    /// Caller identity, retained by matrices and evidence.
    public let id: String
    /// Extracted text whose coordinates the tokens address.
    public let text: String
    /// Token observations, in source order.
    public let tokens: [GlifiCodingToken]
    /// Caller-supplied external variables; missing values fail closed.
    public let variables: [String: String]
    /// Versioned identity of the supplied linguistic annotations.
    public let linguisticContract: String

    /// Validates caller-supplied annotations before evaluating any rule.
    public init(
        id: String, text: String, tokens: [GlifiCodingToken], variables: [String: String] = [:],
        linguisticContract: String
    ) throws {
        guard !id.isEmpty, !linguisticContract.isEmpty, text.utf8.count <= 64 * 1_024 * 1_024,
            tokens.count <= 2_000_000
        else { throw exploratoryFailure("coding.invalid-document") }
        var end = 0
        var previousSentence = 0
        var previousParagraph = 0
        for token in tokens {
            guard token.range.start >= end, token.range.end <= text.utf8.count,
                token.range.text(in: text) == token.surface, !token.base.isEmpty,
                token.sentence >= previousSentence, token.paragraph >= previousParagraph
            else { throw exploratoryFailure("coding.invalid-token") }
            end = token.range.end
            previousSentence = token.sentence
            previousParagraph = token.paragraph
        }
        self.id = id
        self.text = text
        self.tokens = tokens
        self.variables = variables
        self.linguisticContract = linguisticContract
    }

    /// Uses the native Italian surface tokenizer; it does not pretend to provide lemmas or POS.
    public init(id: String, text: String, variables: [String: String] = [:]) throws {
        guard text.utf8.count <= 64 * 1_024 * 1_024 else {
            throw exploratoryFailure("exploratory.resource-limit", .insufficientResources)
        }
        let tokenization = try GlifiItalianTokenizer().tokenize(text)
        let sentenceEnds = tokenization.sentences.map(\.range.end)
        let bytes = Array(text.utf8)
        var paragraphStarts = [0]
        for index in bytes.indices where bytes[index] == 10 {
            if index > 0, bytes[index - 1] == 10 { paragraphStarts.append(index + 1) }
        }
        var sentence = 0
        var paragraph = 0
        var tokens: [GlifiCodingToken] = []
        for token in tokenization.tokens where token.kind.contributesToLexicalStatistics {
            while sentence < sentenceEnds.count - 1, token.range.start >= sentenceEnds[sentence] {
                sentence += 1
            }
            while paragraph + 1 < paragraphStarts.count,
                token.range.start >= paragraphStarts[paragraph + 1]
            { paragraph += 1 }
            guard let surface = token.range.text(in: text) else {
                throw exploratoryFailure("coding.invalid-token")
            }
            tokens.append(
                GlifiCodingToken(
                    surface: surface, base: codingNormalized(surface), range: token.range,
                    sentence: sentence, paragraph: paragraph
                ))
        }
        try self.init(
            id: id, text: text, tokens: tokens, variables: variables,
            linguisticContract: "it-token-v1.normalized-surface"
        )
    }
}

/// Multi-label coding results, including negative rules with no positive token evidence.
public struct GlifiCodingMatrix: Equatable, Sendable {
    /// Unit identities, in input order.
    public let documentIDs: [String]
    /// Code names, in rule-file order.
    public let codes: [String]
    /// Binary document-code matrix.
    public let values: [[Int]]
    /// Applied document counts per code.
    public let frequencies: [Int]
    /// UTF-8 positive evidence for each document/code cell; absence can still satisfy negation.
    public let evidence: [[[GlifiUTF8Range]]]
    /// Linguistic contracts of the input documents.
    public let linguisticContracts: [String]

    /// Aggregates code counts by an explicit external grouping, keeping missing groups explicit.
    public func crosstab(groups: [String?]) throws -> (
        groups: [String], counts: [[Int]], sizes: [Int], missing: Int
    ) {
        guard groups.count == values.count else {
            throw exploratoryFailure("coding.invalid-groups")
        }
        let names = Array(Set(groups.compactMap { $0 })).sorted()
        let positions = Dictionary(
            uniqueKeysWithValues: names.enumerated().map { ($0.element, $0.offset) })
        var counts = Array(repeating: Array(repeating: 0, count: codes.count), count: names.count)
        var sizes = [Int](repeating: 0, count: names.count)
        var missing = 0
        for index in values.indices {
            guard let group = groups[index], let row = positions[group] else {
                missing += 1
                continue
            }
            sizes[row] += 1
            for code in codes.indices { counts[row][code] += values[index][code] }
        }
        return (names, counts, sizes, missing)
    }
}

/// A bounded, compiled KH Coder-style rule file.
///
/// Parsing never executes host-language code.
public struct GlifiCodingRuleSet: Sendable {
    /// Versioned grammar and evaluation contract.
    public static let identifier = "KH-coding-compatible-v2"
    /// Code names in file order.
    public let names: [String]
    private let expressions: [CodingExpression]

    /// Compiles a UTF-8 rule file with comments, arithmetic, proximity and code references.
    public init(_ source: String) throws {
        guard source.utf8.count <= 65_536 else {
            throw exploratoryFailure("coding.rule-byte-limit", .insufficientResources)
        }
        var names: [String] = []
        var bodies: [String] = []
        for raw in source.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(
            of: "\r", with: "\n"
        ).components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            if line.hasPrefix("*") || line.hasPrefix("＊") {
                let name = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty, !names.contains(name), names.count < 256 else {
                    throw exploratoryFailure("coding.invalid-code-name")
                }
                names.append(name)
                bodies.append("")
            } else {
                guard !bodies.isEmpty else {
                    throw exploratoryFailure("coding.missing-code-header")
                }
                bodies[bodies.count - 1] += " " + line
            }
        }
        guard !names.isEmpty else { throw exploratoryFailure("coding.empty-rules") }
        var expressions: [CodingExpression] = []
        for body in bodies {
            var parser = try CodingParser(body)
            let expression = try parser.parse()
            try expression.validateDepth(0)
            expressions.append(expression)
        }
        let all = Set(names)
        for expression in expressions {
            guard expression.references.isSubset(of: all) else {
                throw exploratoryFailure("coding.unknown-reference")
            }
        }
        // Validate all dependencies, including branches that no document would otherwise visit.
        var visited: Set<Int> = []
        var active: Set<Int> = []
        func visit(_ index: Int, depth: Int) throws {
            guard depth <= 32, !active.contains(index) else {
                throw exploratoryFailure("coding.cyclic-reference")
            }
            if visited.contains(index) { return }
            active.insert(index)
            for name in expressions[index].references.sorted() {
                guard let next = names.firstIndex(of: name) else {
                    throw exploratoryFailure("coding.unknown-reference")
                }
                try visit(next, depth: depth + 1)
            }
            active.remove(index)
            visited.insert(index)
        }
        for index in names.indices { try visit(index, depth: 0) }
        self.names = names
        self.expressions = expressions
    }

    /// Evaluates every rule without mutating the project's manual codings or creating a new format.
    public func evaluate(
        _ documents: [GlifiCodingDocument], limits: GlifiExploratoryLimits = .standard
    ) throws -> GlifiCodingMatrix {
        guard !documents.isEmpty, Set(documents.map(\.id)).count == documents.count,
            documents.count <= limits.maximumCells / names.count
        else { throw exploratoryFailure("coding.invalid-documents") }
        try requireWork([documents.reduce(0) { $0 + $1.tokens.count }, expressions.count], limits)
        try requireWork(
            [documents.reduce(0) { $0 + $1.text.utf8.count }, expressions.count], limits)
        var values: [[Int]] = []
        var evidence: [[[GlifiUTF8Range]]] = []
        var frequencies = [Int](repeating: 0, count: names.count)
        var evidenceCount = 0
        for (index, document) in documents.enumerated() {
            try Task.checkCancellation()
            let context = CodingContext(document: document, number: index + 1)
            // Every document shares the same precompiled AST; token positions are indexed once.
            var cache: [String: CodingValue] = [:]
            func evaluateCode(_ name: String) throws -> CodingValue {
                if let value = cache[name] { return value }
                guard let position = names.firstIndex(of: name) else {
                    throw exploratoryFailure("coding.unknown-reference")
                }
                let evaluated = try context.evaluate(expressions[position], reference: evaluateCode)
                let value = CodingValue(
                    number: evaluated.number == 0 ? 0 : 1,
                    ranges: evaluated.number == 0 ? [] : evaluated.ranges
                )
                cache[name] = value
                return value
            }
            var row: [Int] = []
            var rowEvidence: [[GlifiUTF8Range]] = []
            for (position, name) in names.enumerated() {
                let result = try evaluateCode(name)
                let selected = result.number != 0
                row.append(selected ? 1 : 0)
                if selected { frequencies[position] += 1 }
                evidenceCount += selected ? result.ranges.count : 0
                guard evidenceCount <= limits.maximumCells else {
                    throw exploratoryFailure("coding.evidence-limit", .insufficientResources)
                }
                rowEvidence.append(
                    selected
                        ? Array(Set(result.ranges)).sorted {
                            $0.start == $1.start ? $0.end < $1.end : $0.start < $1.start
                        } : [])
            }
            values.append(row)
            evidence.append(rowEvidence)
        }
        return GlifiCodingMatrix(
            documentIDs: documents.map(\.id), codes: names, values: values,
            frequencies: frequencies,
            evidence: evidence, linguisticContracts: documents.map(\.linguisticContract)
        )
    }
}

private indirect enum CodingExpression: Sendable {
    case atom(String, literal: Bool)
    case word(String)
    case number(Double)
    case unary(CodingExpression)
    case binary(String, CodingExpression, CodingExpression)
    case reference(String)
    case proximity([String], ordered: Bool, distance: Int, boundary: String)

    func validateDepth(_ depth: Int) throws {
        guard depth <= 32 else {
            throw exploratoryFailure("coding.depth-limit", .insufficientResources)
        }
        switch self {
        case let .binary(_, left, right):
            try left.validateDepth(depth + 1)
            try right.validateDepth(depth + 1)
        case let .unary(child): try child.validateDepth(depth + 1)
        case .atom, .word, .number, .reference, .proximity: break
        }
    }

    var references: Set<String> {
        switch self {
        case let .reference(name): [name]
        case let .unary(child): child.references
        case let .binary(_, left, right): left.references.union(right.references)
        case .atom, .word, .number, .proximity: []
        }
    }
}

private struct CodingValue {
    let number: Double
    let ranges: [GlifiUTF8Range]
}

private struct CodingContext {
    let document: GlifiCodingDocument
    let number: Int
    var positions: [String: [Int]] = [:]

    init(document: GlifiCodingDocument, number: Int) {
        self.document = document
        self.number = number
        for (index, token) in document.tokens.enumerated() {
            positions[codingNormalized(token.base), default: []].append(index)
        }
    }

    func evaluate(
        _ expression: CodingExpression, reference: (String) throws -> CodingValue
    ) throws -> CodingValue {
        try Task.checkCancellation()
        switch expression {
        case let .number(value): return CodingValue(number: value, ranges: [])
        case let .reference(name): return try reference(name)
        case let .unary(child):
            return CodingValue(
                number: try evaluate(child, reference: reference).number == 0 ? 1 : 0, ranges: [])
        case let .word(value):
            let selected = try tokenPositions(value)
            guard selected.count <= 10_000 else {
                throw exploratoryFailure("coding.evidence-limit", .insufficientResources)
            }
            return CodingValue(
                number: Double(selected.count), ranges: selected.map { document.tokens[$0].range })
        case let .atom(value, literal):
            return try atom(value, literal: literal)
        case let .proximity(terms, ordered, distance, boundary):
            return try proximity(terms, ordered: ordered, distance: distance, boundary: boundary)
        case let .binary(operation, left, right):
            let a = try evaluate(left, reference: reference)
            let b = try evaluate(right, reference: reference)
            let value: Double
            switch operation {
            case "+": value = a.number + b.number
            case "-": value = a.number - b.number
            case "*": value = a.number * b.number
            case "/":
                guard b.number != 0 else { throw exploratoryFailure("coding.division-by-zero") }
                value = a.number / b.number
            case ">": value = a.number > b.number ? 1 : 0
            case "<": value = a.number < b.number ? 1 : 0
            case ">=": value = a.number >= b.number ? 1 : 0
            case "<=": value = a.number <= b.number ? 1 : 0
            case "==": value = a.number == b.number ? 1 : 0
            case "!=": value = a.number != b.number ? 1 : 0
            case "&": value = a.number != 0 && b.number != 0 ? 1 : 0
            case "|": value = a.number != 0 || b.number != 0 ? 1 : 0
            default: throw exploratoryFailure("coding.invalid-operator")
            }
            guard value.isFinite else { throw exploratoryFailure("exploratory.numeric-overflow") }
            let ranges: [GlifiUTF8Range]
            if operation == "|" {
                ranges = (a.number != 0 ? a.ranges : []) + (b.number != 0 ? b.ranges : [])
            } else {
                ranges = value != 0 ? a.ranges + b.ranges : []
            }
            let unique = Array(Set(ranges))
            guard unique.count <= 10_000 else {
                throw exploratoryFailure("coding.evidence-limit", .insufficientResources)
            }
            return CodingValue(number: value, ranges: unique)
        }
    }

    private func atom(_ value: String, literal: Bool) throws -> CodingValue {
        if literal {
            var ranges: [GlifiUTF8Range] = []
            var cursor = document.text.startIndex
            while cursor < document.text.endIndex,
                let range = document.text.range(
                    of: value, options: [.literal], range: cursor..<document.text.endIndex)
            {
                let start = document.text[..<range.lowerBound].utf8.count
                let end = start + document.text[range].utf8.count
                let sentence = document.tokens.first { $0.range.end > start }?.sentence
                let lastSentence = document.tokens.last { $0.range.start < end }?.sentence
                if sentence == lastSentence {
                    ranges.append(try GlifiUTF8Range(start: start, end: end))
                }
                guard ranges.count <= 10_000 else {
                    throw exploratoryFailure("coding.evidence-limit", .insufficientResources)
                }
                try Task.checkCancellation()
                cursor = range.upperBound
            }
            guard ranges.count <= 10_000 else {
                throw exploratoryFailure("coding.evidence-limit", .insufficientResources)
            }
            return CodingValue(number: Double(ranges.count), ranges: ranges)
        }
        if value.hasPrefix("<>") {
            let parts = String(value.dropFirst(2)).components(separatedBy: "-->")
            let fallback =
                parts.count == 2 ? parts : String(value.dropFirst(2)).components(separatedBy: "->")
            guard fallback.count == 2, let variable = document.variables[fallback[0]] else {
                throw exploratoryFailure("coding.missing-variable", .insufficientData)
            }
            return CodingValue(number: variable == fallback[1] ? 1 : 0, ranges: [])
        }
        switch value {
        case "lw": return CodingValue(number: Double(document.tokens.count), ranges: [])
        case "lc": return CodingValue(number: Double(document.text.count), ranges: [])
        case "No.": return CodingValue(number: Double(number), ranges: [])
        default: break
        }
        if value.contains("+") {
            return try proximity(
                value.components(separatedBy: "+"), ordered: true, distance: 1, boundary: "")
        }
        let selected = try tokenPositions(value)
        guard selected.count <= 10_000 else {
            throw exploratoryFailure("coding.evidence-limit", .insufficientResources)
        }
        return CodingValue(
            number: Double(selected.count), ranges: selected.map { document.tokens[$0].range })
    }

    private func tokenPositions(_ specification: String) throws -> [Int] {
        let surfaceParts = specification.components(separatedBy: "=>")
        let posParts = surfaceParts[0].components(separatedBy: "-->")
        let inflectionParts = posParts.last?.components(separatedBy: "->") ?? []
        let baseParts = posParts[0].components(separatedBy: "->")
        guard surfaceParts.count <= 2, posParts.count <= 2, !baseParts[0].isEmpty,
            !(surfaceParts.count == 2 && (inflectionParts.count == 2 || baseParts.count == 2))
        else { throw exploratoryFailure("coding.invalid-token-condition") }
        let pos = posParts.count == 2 ? inflectionParts.first : nil
        let inflection =
            posParts.count == 2
            ? (inflectionParts.count == 2 ? inflectionParts[1] : nil)
            : (baseParts.count == 2 ? baseParts[1] : nil)
        if pos != nil, !document.tokens.allSatisfy({ $0.partOfSpeech != nil }) {
            throw exploratoryFailure("coding.missing-pos", .insufficientData)
        }
        if inflection != nil, !document.tokens.allSatisfy({ $0.inflection != nil }) {
            throw exploratoryFailure("coding.missing-inflection", .insufficientData)
        }
        return (positions[codingNormalized(baseParts[0])] ?? []).filter { index in
            let token = document.tokens[index]
            return (pos == nil || token.partOfSpeech == pos)
                && (inflection == nil || token.inflection == inflection)
                && (surfaceParts.count == 1 || token.surface == surfaceParts[1])
        }
    }

    private func proximity(
        _ terms: [String], ordered: Bool, distance: Int, boundary: String
    ) throws -> CodingValue {
        guard terms.count >= 2, terms.count <= 32, !terms.contains(where: \.isEmpty),
            Set(terms).count == terms.count || ordered
        else { throw exploratoryFailure("coding.invalid-proximity") }
        let candidates = try terms.map { try tokenPositions($0) }
        guard candidates.allSatisfy({ !$0.isEmpty }) else {
            return CodingValue(number: 0, ranges: [])
        }
        var matches: [GlifiUTF8Range] = []
        var steps = 0
        func extend(_ selected: [Int], _ next: Int) throws {
            steps += 1
            guard steps <= 1_000_000 else {
                throw exploratoryFailure("coding.proximity-work-limit", .insufficientResources)
            }
            if steps.isMultiple(of: 1_024) { try Task.checkCancellation() }
            if next == candidates.count {
                guard let first = selected.min(), let last = selected.max() else { return }
                guard matches.count < 10_000 else {
                    throw exploratoryFailure("coding.evidence-limit", .insufficientResources)
                }
                matches.append(
                    try GlifiUTF8Range(
                        start: document.tokens[first].range.start,
                        end: document.tokens[last].range.end))
                return
            }
            for candidate in candidates[next] where !selected.contains(candidate) {
                guard let previous = selected.last else { continue }
                if ordered, candidate <= previous { continue }
                if distance > 0 {
                    if ordered {
                        if candidate - previous > distance { break }
                    } else if selected.contains(where: { abs(candidate - $0) > distance }) {
                        continue
                    }
                }
                if boundary == "b",
                    document.tokens[candidate].sentence != document.tokens[selected[0]].sentence
                {
                    continue
                }
                if boundary == "d",
                    document.tokens[candidate].paragraph != document.tokens[selected[0]].paragraph
                {
                    continue
                }
                try extend(selected + [candidate], next + 1)
            }
        }
        guard candidates[0].count <= 1_000_000 else {
            throw exploratoryFailure("coding.proximity-work-limit", .insufficientResources)
        }
        for first in candidates[0] {
            try extend([first], 1)
            guard matches.count <= 10_000 else {
                throw exploratoryFailure("coding.evidence-limit", .insufficientResources)
            }
        }
        let unique = Array(Set(matches))
        return CodingValue(number: Double(unique.count), ranges: unique)
    }
}

private struct CodingLexeme {
    let value: String
    let quoted: Character?
}

private struct CodingParser {
    let tokens: [CodingLexeme]
    var index = 0
    var nodes = 0

    init(_ source: String) throws {
        let characters = Array(source)
        var result: [CodingLexeme] = []
        var index = 0
        while index < characters.count {
            if characters[index].isWhitespace {
                index += 1
                continue
            }
            let start = index
            let character = characters[index]
            if character == "'" || character == "\"" {
                index += 1
                var value = ""
                var closed = false
                while index < characters.count {
                    if characters[index] == character {
                        if index + 1 < characters.count, characters[index + 1] == character {
                            value.append(character)
                            index += 2
                            continue
                        }
                        index += 1
                        closed = true
                        break
                    }
                    value.append(characters[index])
                    index += 1
                }
                guard closed, !value.isEmpty else {
                    throw exploratoryFailure("coding.unterminated-string")
                }
                result.append(CodingLexeme(value: value, quoted: character))
            } else if character == "(" || character == ")" {
                result.append(CodingLexeme(value: String(character), quoted: nil))
                index += 1
            } else if sourcePrefix(characters, index, "near(")
                || sourcePrefix(characters, index, "seq(")
            {
                while index < characters.count, characters[index] != ")" { index += 1 }
                guard index < characters.count else {
                    throw exploratoryFailure("coding.invalid-proximity")
                }
                index += 1
                if index < characters.count, characters[index] == "[" {
                    while index < characters.count, characters[index] != "]" { index += 1 }
                    guard index < characters.count else {
                        throw exploratoryFailure("coding.invalid-proximity")
                    }
                    index += 1
                }
                result.append(CodingLexeme(value: String(characters[start..<index]), quoted: nil))
            } else if sourcePrefix(characters, index, "<*") {
                while index < characters.count, characters[index] != ">" { index += 1 }
                guard index < characters.count else {
                    throw exploratoryFailure("coding.invalid-reference")
                }
                index += 1
                result.append(CodingLexeme(value: String(characters[start..<index]), quoted: nil))
            } else {
                while index < characters.count, !characters[index].isWhitespace,
                    characters[index] != "(", characters[index] != ")"
                { index += 1 }
                let word = String(characters[start..<index])
                if word.count > 1, word.contains(where: { "&|!*/".contains($0) }), word != "&!",
                    word != "|!", word != "!="
                {
                    throw exploratoryFailure("coding.unspaced-operator")
                }
                let normalized = word.lowercased()
                let mapped =
                    normalized == "and"
                    ? "&" : normalized == "or" ? "|" : normalized == "not" ? "!" : word
                if mapped == "&!" || mapped == "|!" {
                    result.append(CodingLexeme(value: String(mapped.prefix(1)), quoted: nil))
                    result.append(CodingLexeme(value: "!", quoted: nil))
                } else {
                    result.append(CodingLexeme(value: mapped, quoted: nil))
                }
            }
        }
        guard result.count <= 1_024 else {
            throw exploratoryFailure("coding.node-limit", .insufficientResources)
        }
        tokens = result
    }

    mutating func parse() throws -> CodingExpression {
        let expression = try parseExpression(minimum: 0, depth: 0)
        guard index == tokens.count else { throw exploratoryFailure("coding.unexpected-token") }
        return expression
    }

    mutating func parseExpression(minimum: Int, depth: Int) throws -> CodingExpression {
        guard depth <= 32, nodes < 1_024, index < tokens.count else {
            throw exploratoryFailure("coding.syntax-or-depth-limit")
        }
        nodes += 1
        let token = tokens[index]
        index += 1
        var left: CodingExpression
        if token.quoted == "'", !token.value.isEmpty {
            left = .atom(token.value, literal: true)
        } else if token.quoted == "\"" {
            left =
                token.value.hasPrefix("<>")
                ? .atom(token.value, literal: false) : .word(token.value)
        } else if token.value == "!" {
            left = .unary(try parseExpression(minimum: 6, depth: depth + 1))
        } else if token.value == "(" {
            left = try parseExpression(minimum: 0, depth: depth + 1)
            guard index < tokens.count, tokens[index].value == ")" else {
                throw exploratoryFailure("coding.unclosed-parenthesis")
            }
            index += 1
        } else if token.value.hasPrefix("<*"), token.value.hasSuffix(">") {
            left = .reference(String(token.value.dropFirst(2).dropLast()))
        } else if token.value.hasPrefix("near(") || token.value.hasPrefix("seq(") {
            guard let opening = token.value.firstIndex(of: "("),
                let closing = token.value.firstIndex(of: ")")
            else {
                throw exploratoryFailure("coding.invalid-proximity")
            }
            let terms = token.value[token.value.index(after: opening)..<closing].components(
                separatedBy: "-")
            let suffix = String(token.value[token.value.index(after: closing)...])
            var option = suffix.isEmpty ? "" : String(suffix.dropFirst().dropLast())
            guard suffix.isEmpty || (suffix.hasPrefix("[") && suffix.hasSuffix("]")) else {
                throw exploratoryFailure("coding.invalid-proximity")
            }
            let boundary =
                option.first == "b" || option.first == "d" ? String(option.removeFirst()) : ""
            let distance = option.isEmpty ? 10 : Int(option)
            guard let distance, distance >= 0, distance <= 10_000 else {
                throw exploratoryFailure("coding.invalid-proximity")
            }
            left = .proximity(
                terms, ordered: token.value.hasPrefix("seq("), distance: distance,
                boundary: boundary)
        } else if let number = Double(token.value), number.isFinite {
            left = .number(number)
        } else {
            guard token.value != ")", precedence(token.value) == nil else {
                throw exploratoryFailure("coding.unexpected-token")
            }
            left = .atom(token.value, literal: false)
        }
        while index < tokens.count, tokens[index].quoted == nil,
            let precedence = precedence(tokens[index].value), precedence >= minimum
        {
            let operation = tokens[index].value
            index += 1
            let right = try parseExpression(minimum: precedence + 1, depth: depth + 1)
            left = .binary(operation, left, right)
            nodes += 1
            guard nodes <= 1_024 else {
                throw exploratoryFailure("coding.node-limit", .insufficientResources)
            }
        }
        return left
    }
}

private func sourcePrefix(_ characters: [Character], _ start: Int, _ prefix: String) -> Bool {
    let expected = Array(prefix)
    guard start + expected.count <= characters.count else { return false }
    return Array(characters[start..<(start + expected.count)]) == expected
}

private func precedence(_ operation: String) -> Int? {
    switch operation {
    case "|": 1
    case "&": 2
    case ">", "<", ">=", "<=", "==", "!=": 3
    case "+", "-": 4
    case "*", "/": 5
    default: nil
    }
}

private func codingNormalized(_ string: String) -> String {
    string.precomposedStringWithCanonicalMapping.lowercased(with: Locale(identifier: "it_IT"))
}
