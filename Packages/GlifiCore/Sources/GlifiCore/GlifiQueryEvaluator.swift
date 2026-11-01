// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// One positional query match with bounded KWIC context ranges.
public struct GlifiQueryMatch: Codable, Equatable, Sendable {
    /// Immutable source revision containing the match.
    public let sourceRevisionID: SourceRevisionID
    /// Exact match interval in extracted UTF-8 bytes.
    public let range: GlifiUTF8Range
    /// Optional bounded interval preceding the match.
    public let leftContextRange: GlifiUTF8Range?
    /// Optional bounded interval following the match.
    public let rightContextRange: GlifiUTF8Range?

    /// Creates a match whose ranges share one source coordinate space.
    public init(
        sourceRevisionID: SourceRevisionID,
        range: GlifiUTF8Range,
        leftContextRange: GlifiUTF8Range?,
        rightContextRange: GlifiUTF8Range?
    ) {
        self.sourceRevisionID = sourceRevisionID
        self.range = range
        self.leftContextRange = leftContextRange
        self.rightContextRange = rightContextRange
    }
}

/// Bounded deterministic result of evaluating one query against one source revision.
public struct GlifiQueryResult: Equatable, Sendable {
    /// Digest of the exact canonical query AST.
    public let queryDigest: String
    /// Source revision evaluated by this result.
    public let sourceRevisionID: SourceRevisionID
    /// Whether the query predicate selected the source scope.
    public let matchedScope: Bool
    /// Ordered, non-overlapping only when the query semantics produce non-overlapping anchors.
    public let matches: [GlifiQueryMatch]
    /// Whether further matches existed beyond the configured materialization limit.
    public let isTruncated: Bool

    /// Creates an immutable result with explicit completeness.
    public init(
        queryDigest: String,
        sourceRevisionID: SourceRevisionID,
        matchedScope: Bool,
        matches: [GlifiQueryMatch],
        isTruncated: Bool
    ) {
        self.queryDigest = queryDigest
        self.sourceRevisionID = sourceRevisionID
        self.matchedScope = matchedScope
        self.matches = matches
        self.isTruncated = isTruncated
    }
}

/// Executes validated QueryAST nodes over the first bounded text representation.
public struct GlifiQueryEvaluator: Sendable {
    /// Creates a stateless bounded evaluator.
    public init() {}

    /// Checks schema, semantic invariants, and resource limits without reading source text.
    public func validate(
        _ query: GlifiQueryAST,
        limits: GlifiQueryLimits = .standard
    ) throws {
        guard query.schema == GlifiQueryAST.schema,
            query.schemaVersion == GlifiQueryAST.schemaVersion,
            query.grammarVersion == GlifiQueryAST.grammarVersion
        else {
            throw queryExecutionFailure("query.incompatible-ast", category: .incompatibleVersion)
        }
        var validation = QueryValidation(limits: limits)
        try validation.validate(query.root, depth: 0)
    }

    /// Evaluates a query using the positional tokenization of the same source snapshot.
    public func evaluate(
        _ query: GlifiQueryAST,
        in importedText: GlifiImportedText,
        tokenization: GlifiTokenization,
        limits: GlifiQueryLimits = .standard
    ) throws -> GlifiQueryResult {
        try validate(query, limits: limits)
        guard tokenization.sourceUTF8Length == importedText.text.utf8.count else {
            throw queryExecutionFailure("query.incompatible-ast", category: .incompatibleVersion)
        }

        let context = QueryEvaluationContext(
            source: importedText,
            tokens: tokenization.tokens,
            limits: limits
        )
        let evaluation = try context.evaluate(query.root)
        let ordered = evaluation.anchors.sorted {
            $0.start == $1.start ? $0.end < $1.end : $0.start < $1.start
        }
        let unique = ordered.reduce(into: [QueryTokenInterval]()) { result, interval in
            guard result.last != interval else { return }
            result.append(interval)
        }
        let isTruncated = unique.count > limits.maximumResultCount
        let retained = unique.prefix(limits.maximumResultCount)
        let matches = try retained.map { interval in
            try context.match(for: interval)
        }
        return GlifiQueryResult(
            queryDigest: try query.canonicalDigest(),
            sourceRevisionID: importedText.sourceRevisionID,
            matchedScope: evaluation.satisfied,
            matches: matches,
            isTruncated: isTruncated
        )
    }
}

private struct QueryValidation {
    let limits: GlifiQueryLimits
    var nodeCount = 0

    mutating func validate(_ node: GlifiQueryNode, depth: Int) throws {
        try Task.checkCancellation()
        nodeCount += 1
        guard nodeCount <= limits.maximumNodeCount else {
            throw queryExecutionFailure(
                "query.node-limit-exceeded",
                category: .insufficientResources
            )
        }
        guard depth <= limits.maximumDepth else {
            throw queryExecutionFailure(
                "query.depth-limit-exceeded",
                category: .insufficientResources
            )
        }

        switch node {
        case .matchAll:
            return
        case let .term(field, value, _):
            try validate(field)
            guard !value.isEmpty, value.utf8.count <= limits.maximumQueryByteCount else {
                throw queryExecutionFailure("query.invalid-term")
            }
        case let .phrase(field, values, slop):
            try validate(field)
            guard !values.isEmpty,
                values.count <= limits.maximumPhraseTokenCount,
                values.allSatisfy({ !$0.isEmpty }),
                slop >= 0,
                slop <= limits.maximumProximityDistance
            else {
                throw queryExecutionFailure("query.invalid-phrase")
            }
        case let .regex(field, pattern, flags):
            try validate(field)
            guard flags.subtracting([.caseInsensitive, .canonicalEquivalence]).isEmpty else {
                throw queryExecutionFailure("query.regex-rejected")
            }
            guard !pattern.isEmpty, pattern.utf8.count <= limits.maximumRegexByteCount else {
                throw queryExecutionFailure("query.regex-limit-exceeded")
            }
            _ = try SafeTokenPattern(pattern)
        case let .range(field, value):
            try validate(field)
            guard value.lower != nil || value.upper != nil else {
                throw queryExecutionFailure("query.invalid-range")
            }
        case let .exists(field):
            try validate(field)
        case let .proximity(left, right, distance, _, _):
            guard distance >= 0, distance <= limits.maximumProximityDistance else {
                throw queryExecutionFailure("query.invalid-proximity")
            }
            try validate(left, depth: depth + 1)
            try validate(right, depth: depth + 1)
        case let .not(child), let .within(child, _):
            try validate(child, depth: depth + 1)
        case let .and(children), let .or(children):
            guard children.count >= 2 else {
                throw queryExecutionFailure("query.invalid-boolean")
            }
            for child in children {
                try validate(child, depth: depth + 1)
            }
        }
    }

    private func validate(_ field: GlifiQueryField) throws {
        guard field.isKnown else {
            throw queryExecutionFailure("query.unknown-field")
        }
    }
}

private struct QueryEvaluationContext {
    let source: GlifiImportedText
    let tokens: [GlifiSurfaceToken]
    let limits: GlifiQueryLimits

    private var anchorCapacity: Int {
        limits.maximumResultCount == Int.max ? Int.max : limits.maximumResultCount + 1
    }

    func evaluate(_ node: GlifiQueryNode) throws -> QueryEvaluation {
        try Task.checkCancellation()
        switch node {
        case .matchAll:
            guard !tokens.isEmpty else {
                return QueryEvaluation(satisfied: true, anchors: [])
            }
            return QueryEvaluation(
                satisfied: true,
                anchors: [QueryTokenInterval(start: 0, end: tokens.count)]
            )
        case let .term(field, value, _):
            return try tokenMatches(field: field) { candidate in
                comparable(candidate, field: field) == comparable(value, field: field)
            }
        case let .regex(field, pattern, flags):
            let matcher = try SafeTokenPattern(
                normalizedRegexValue(comparable(pattern, field: field), flags: flags)
            )
            return try tokenMatches(field: field) { candidate in
                guard candidate.utf8.count <= limits.maximumRegexInputByteCount else {
                    throw queryExecutionFailure(
                        "query.regex-input-limit-exceeded",
                        category: .insufficientResources
                    )
                }
                return try matcher.matches(
                    normalizedRegexValue(comparable(candidate, field: field), flags: flags)
                )
            }
        case let .phrase(field, values, slop):
            try requireTextField(field)
            return try phraseMatches(field: field, values: values, slop: slop)
        case let .proximity(left, right, distance, _, ordered):
            let leftResult = try evaluate(left)
            let rightResult = try evaluate(right)
            guard leftResult.satisfied, rightResult.satisfied else {
                return QueryEvaluation(satisfied: false, anchors: [])
            }
            var anchors: [QueryTokenInterval] = []
            outer: for leftInterval in leftResult.anchors {
                for rightInterval in rightResult.anchors {
                    if let combined = proximity(
                        leftInterval,
                        rightInterval,
                        maximumDistance: distance,
                        ordered: ordered
                    ) {
                        anchors.append(combined)
                        if anchors.count >= anchorCapacity { break outer }
                    }
                }
            }
            return QueryEvaluation(satisfied: !anchors.isEmpty, anchors: anchors)
        case let .not(child):
            let childResult = try evaluate(child)
            return QueryEvaluation(satisfied: !childResult.satisfied, anchors: [])
        case let .and(children):
            var anchors: [QueryTokenInterval] = []
            for child in children {
                let result = try evaluate(child)
                guard result.satisfied else {
                    return QueryEvaluation(satisfied: false, anchors: [])
                }
                appendUnique(result.anchors, to: &anchors)
            }
            return QueryEvaluation(satisfied: true, anchors: anchors)
        case let .or(children):
            var isSatisfied = false
            var anchors: [QueryTokenInterval] = []
            for child in children {
                let result = try evaluate(child)
                isSatisfied = isSatisfied || result.satisfied
                appendUnique(result.anchors, to: &anchors)
            }
            return QueryEvaluation(satisfied: isSatisfied, anchors: anchors)
        case let .within(child, scope):
            switch scope {
            case let .sourceRevision(sourceRevisionID):
                guard sourceRevisionID == source.sourceRevisionID else {
                    return QueryEvaluation(satisfied: false, anchors: [])
                }
                return try evaluate(child)
            case .project, .corpus:
                throw queryExecutionFailure("query.unsupported-scope", category: .insufficientData)
            }
        case .range, .exists:
            throw queryExecutionFailure("query.unsupported-field", category: .insufficientData)
        }
    }

    func match(for interval: QueryTokenInterval) throws -> GlifiQueryMatch {
        guard interval.start >= 0,
            interval.end > interval.start,
            interval.end <= tokens.count
        else {
            throw queryExecutionFailure("query.invalid-match", category: .invariantViolation)
        }
        let range = try GlifiUTF8Range(
            start: tokens[interval.start].range.start,
            end: tokens[interval.end - 1].range.end
        )
        let leftStart = max(0, interval.start - limits.contextTokenCount)
        let rightEnd = min(tokens.count, interval.end + limits.contextTokenCount)
        let leftRange =
            leftStart < interval.start
            ? try GlifiUTF8Range(
                start: tokens[leftStart].range.start,
                end: tokens[interval.start - 1].range.end
            ) : nil
        let rightRange =
            interval.end < rightEnd
            ? try GlifiUTF8Range(
                start: tokens[interval.end].range.start,
                end: tokens[rightEnd - 1].range.end
            ) : nil
        return GlifiQueryMatch(
            sourceRevisionID: source.sourceRevisionID,
            range: range,
            leftContextRange: leftRange,
            rightContextRange: rightRange
        )
    }

    private func tokenMatches(
        field: GlifiQueryField,
        predicate: (String) throws -> Bool
    ) throws -> QueryEvaluation {
        try requireTextField(field)
        var anchors: [QueryTokenInterval] = []
        for (index, token) in tokens.enumerated() {
            if index.isMultiple(of: 4_096) { try Task.checkCancellation() }
            guard token.kind.contributesToLexicalStatistics,
                let value = token.range.text(in: source.text),
                try predicate(value)
            else {
                continue
            }
            anchors.append(QueryTokenInterval(start: index, end: index + 1))
            if anchors.count >= anchorCapacity { break }
        }
        return QueryEvaluation(satisfied: !anchors.isEmpty, anchors: anchors)
    }

    private func phraseMatches(
        field: GlifiQueryField,
        values: [String],
        slop: Int
    ) throws -> QueryEvaluation {
        let expected = values.map { comparable($0, field: field) }
        var anchors: [QueryTokenInterval] = []
        for start in tokens.indices {
            if start.isMultiple(of: 4_096) { try Task.checkCancellation() }
            guard tokenValue(at: start, field: field) == expected[0],
                let end = phraseEnd(
                    expected: expected,
                    expectedIndex: 1,
                    afterToken: start,
                    remainingSlop: slop,
                    field: field
                )
            else {
                continue
            }
            anchors.append(QueryTokenInterval(start: start, end: end + 1))
            if anchors.count >= anchorCapacity { break }
        }
        return QueryEvaluation(satisfied: !anchors.isEmpty, anchors: anchors)
    }

    private func phraseEnd(
        expected: [String],
        expectedIndex: Int,
        afterToken previous: Int,
        remainingSlop: Int,
        field: GlifiQueryField
    ) -> Int? {
        var currentToken = previous
        var availableSlop = remainingSlop
        for currentExpected in expectedIndex..<expected.count {
            let furthest = min(tokens.count - 1, currentToken + availableSlop + 1)
            guard currentToken + 1 <= furthest else { return nil }
            var matchedToken: Int?
            for candidate in (currentToken + 1)...furthest
            where tokenValue(at: candidate, field: field) == expected[currentExpected] {
                matchedToken = candidate
                break
            }
            guard let matchedToken else { return nil }
            availableSlop -= matchedToken - currentToken - 1
            currentToken = matchedToken
        }
        return currentToken
    }

    private func tokenValue(at index: Int, field: GlifiQueryField) -> String? {
        guard tokens[index].kind.contributesToLexicalStatistics,
            let value = tokens[index].range.text(in: source.text)
        else {
            return nil
        }
        return comparable(value, field: field)
    }

    private func comparable(_ value: String, field: GlifiQueryField) -> String {
        switch field {
        case .normalized:
            value.precomposedStringWithCanonicalMapping.lowercased(
                with: Locale(identifier: "it_IT")
            )
        default:
            value
        }
    }

    private func normalizedRegexValue(_ value: String, flags: GlifiRegexFlags) -> String {
        var result = value
        if flags.contains(.canonicalEquivalence) {
            result = result.precomposedStringWithCanonicalMapping
        }
        if flags.contains(.caseInsensitive) {
            result = String(
                result.unicodeScalars.map { scalar -> Character in
                    guard (65...90).contains(scalar.value),
                        let lowered = UnicodeScalar(scalar.value + 32)
                    else {
                        return Character(String(scalar))
                    }
                    return Character(String(lowered))
                }
            )
        }
        return result
    }

    private func proximity(
        _ left: QueryTokenInterval,
        _ right: QueryTokenInterval,
        maximumDistance: Int,
        ordered: Bool
    ) -> QueryTokenInterval? {
        if left.end <= right.start {
            let gap = right.start - left.end
            guard gap <= maximumDistance else { return nil }
            return QueryTokenInterval(start: left.start, end: right.end)
        }
        guard !ordered, right.end <= left.start else { return nil }
        let gap = left.start - right.end
        guard gap <= maximumDistance else { return nil }
        return QueryTokenInterval(start: right.start, end: left.end)
    }

    private func appendUnique(
        _ candidates: [QueryTokenInterval],
        to anchors: inout [QueryTokenInterval]
    ) {
        for candidate in candidates where !anchors.contains(candidate) {
            anchors.append(candidate)
            if anchors.count >= anchorCapacity { return }
        }
    }

    private func requireTextField(_ field: GlifiQueryField) throws {
        guard field == .form || field == .normalized || field == .text else {
            throw queryExecutionFailure("query.unsupported-field", category: .insufficientData)
        }
    }
}

private struct QueryEvaluation {
    let satisfied: Bool
    let anchors: [QueryTokenInterval]
}

private struct QueryTokenInterval: Equatable {
    let start: Int
    let end: Int
}

private struct SafeTokenPattern {
    private let atoms: [Atom]
    private let anchoredStart: Bool
    private let anchoredEnd: Bool

    init(_ pattern: String) throws {
        let characters = Array(pattern)
        var index = 0
        anchoredStart = characters.first == "^"
        if anchoredStart { index += 1 }
        var parsedAtoms: [Atom] = []
        var hasEndAnchor = false

        while index < characters.count {
            if characters[index] == "$", index == characters.count - 1 {
                hasEndAnchor = true
                index += 1
                break
            }
            let predicate: Predicate
            switch characters[index] {
            case ".":
                predicate = .any
                index += 1
            case "[":
                let parsed = try Self.parseClass(characters, from: index)
                predicate = parsed.predicate
                index = parsed.nextIndex
            case "\\":
                let parsed = try Self.parseEscape(characters, from: index)
                predicate = parsed.predicate
                index = parsed.nextIndex
            case "(", ")", "|", "{", "}", "^", "$", "*", "+", "?":
                throw queryExecutionFailure("query.regex-rejected")
            default:
                predicate = .literal(characters[index])
                index += 1
            }

            var repetition = Repetition.once
            if index < characters.count {
                switch characters[index] {
                case "?": repetition = .optional
                case "*": repetition = .zeroOrMore
                case "+": repetition = .oneOrMore
                default: break
                }
                if repetition != .once { index += 1 }
            }
            parsedAtoms.append(Atom(predicate: predicate, repetition: repetition))
        }
        guard index == characters.count, !parsedAtoms.isEmpty else {
            throw queryExecutionFailure("query.regex-rejected")
        }
        atoms = parsedAtoms
        anchoredEnd = hasEndAnchor
    }

    func matches(_ value: String) throws -> Bool {
        let characters = Array(value)
        let initial = epsilonClosure([0])
        var states = initial
        if states.contains(atoms.count), !anchoredEnd {
            return true
        }

        for (valueIndex, character) in characters.enumerated() {
            if valueIndex.isMultiple(of: 256) { try Task.checkCancellation() }
            if !anchoredStart {
                states.formUnion(initial)
            }
            var next: Set<Int> = []
            for state in states where state < atoms.count {
                let atom = atoms[state]
                guard atom.predicate.matches(character) else { continue }
                switch atom.repetition {
                case .once, .optional:
                    next.insert(state + 1)
                case .zeroOrMore, .oneOrMore:
                    next.insert(state)
                    next.insert(state + 1)
                }
            }
            states = epsilonClosure(next)
            if states.contains(atoms.count),
                !anchoredEnd || valueIndex == characters.count - 1
            {
                return true
            }
        }
        if !anchoredStart {
            states.formUnion(initial)
        }
        return states.contains(atoms.count)
    }

    private func epsilonClosure(_ seeds: Set<Int>) -> Set<Int> {
        var result = seeds
        var pending = Array(seeds)
        while let state = pending.popLast() {
            guard state < atoms.count else { continue }
            switch atoms[state].repetition {
            case .optional, .zeroOrMore:
                if result.insert(state + 1).inserted {
                    pending.append(state + 1)
                }
            case .once, .oneOrMore:
                break
            }
        }
        return result
    }

    private static func parseClass(
        _ characters: [Character],
        from start: Int
    ) throws -> (predicate: Predicate, nextIndex: Int) {
        var index = start + 1
        var isNegated = false
        if index < characters.count, characters[index] == "^" {
            isNegated = true
            index += 1
        }
        var members: [Character] = []
        while index < characters.count, characters[index] != "]" {
            if characters[index] == "\\" {
                let parsed = try parseEscape(characters, from: index)
                guard case let .literal(character) = parsed.predicate else {
                    throw queryExecutionFailure("query.regex-rejected")
                }
                members.append(character)
                index = parsed.nextIndex
            } else {
                members.append(characters[index])
                index += 1
            }
        }
        guard index < characters.count, !members.isEmpty else {
            throw queryExecutionFailure("query.regex-rejected")
        }
        return (.characterClass(Set(members), negated: isNegated), index + 1)
    }

    private static func parseEscape(
        _ characters: [Character],
        from start: Int
    ) throws -> (predicate: Predicate, nextIndex: Int) {
        guard start + 1 < characters.count else {
            throw queryExecutionFailure("query.regex-rejected")
        }
        switch characters[start + 1] {
        case "d": return (.digit, start + 2)
        case "w": return (.word, start + 2)
        case "s": return (.whitespace, start + 2)
        case let escaped: return (.literal(escaped), start + 2)
        }
    }

    private struct Atom {
        let predicate: Predicate
        let repetition: Repetition
    }

    private enum Repetition {
        case once
        case optional
        case zeroOrMore
        case oneOrMore
    }

    private enum Predicate {
        case any
        case literal(Character)
        case characterClass(Set<Character>, negated: Bool)
        case digit
        case word
        case whitespace

        func matches(_ character: Character) -> Bool {
            switch self {
            case .any:
                true
            case let .literal(expected):
                character == expected
            case let .characterClass(members, negated):
                members.contains(character) != negated
            case .digit:
                character.unicodeScalars.allSatisfy { CharacterSet.decimalDigits.contains($0) }
            case .word:
                character == "_"
                    || character.unicodeScalars.allSatisfy {
                        CharacterSet.alphanumerics.contains($0)
                    }
            case .whitespace:
                character.unicodeScalars.allSatisfy {
                    CharacterSet.whitespacesAndNewlines.contains($0)
                }
            }
        }
    }

}

func queryExecutionFailure(
    _ code: String,
    category: GlifiFailureCategory = .invalidInput
) -> GlifiFailure {
    GlifiFailure(
        code: code,
        category: category,
        operation: .query,
        retryDisposition: GlifiFailureTaxonomy.defaultRetry(category),
        retainedState: GlifiFailureTaxonomy.defaultRetained(category, preferred: .unchanged),
        messageKey: "failure.\(code)"
    )
}
