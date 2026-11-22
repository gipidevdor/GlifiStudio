// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Bounded parser for the public `glifi-query-v1` grammar.
public struct GlifiQueryParser: Sendable {
    private let tokenizer: any GlifiTokenizing

    /// Creates a parser with the same replaceable tokenizer used by analysis.
    public init(tokenizer: any GlifiTokenizing = GlifiItalianTokenizer()) {
        self.tokenizer = tokenizer
    }

    /// Parses text into a canonical AST or throws a privacy-safe diagnostic failure.
    public func parse(
        _ source: String,
        limits: GlifiQueryLimits = .standard
    ) throws -> GlifiQueryAST {
        guard source.utf8.count <= limits.maximumQueryByteCount else {
            throw queryFailure(
                "query.byte-limit-exceeded",
                category: .insufficientResources,
                start: 0,
                end: source.utf8.count
            )
        }
        var lexer = QueryLexer(source: source)
        let tokens = try lexer.scan()
        var parser = QuerySyntaxParser(tokens: tokens, limits: limits, tokenizer: tokenizer)
        return GlifiQueryAST(root: try parser.parse())
    }
}

private struct QuerySyntaxParser {
    let tokens: [QueryLexeme]
    let limits: GlifiQueryLimits
    let tokenizer: any GlifiTokenizing
    var index = 0
    var nodeCount = 0

    mutating func parse() throws -> GlifiQueryNode {
        guard !tokens.isEmpty else {
            throw failure("query.unexpected-token", at: nil)
        }
        let root = try parseOr(depth: 0)
        guard index == tokens.count else {
            throw failure("query.unexpected-token", at: current)
        }
        try validateTreeDepth(root)
        return root
    }

    private func validateTreeDepth(_ root: GlifiQueryNode) throws {
        var pending: [(node: GlifiQueryNode, depth: Int)] = [(root, 0)]
        while let (node, depth) = pending.popLast() {
            try Task.checkCancellation()
            guard depth <= limits.maximumDepth else {
                throw failure(
                    "query.depth-limit-exceeded", category: .insufficientResources, at: nil)
            }
            switch node {
            case .matchAll, .term, .phrase, .regex, .range, .exists:
                break
            case let .proximity(left, right, _, _, _):
                pending.append((left, depth + 1))
                pending.append((right, depth + 1))
            case let .not(child), let .within(child, _):
                pending.append((child, depth + 1))
            case let .and(children), let .or(children):
                for child in children {
                    pending.append((child, depth + 1))
                }
            }
        }
    }

    private mutating func parseOr(depth: Int) throws -> GlifiQueryNode {
        var children = [try parseAnd(depth: depth)]
        while consumeKeyword("OR") != nil {
            children.append(try parseAnd(depth: depth))
        }
        guard children.count > 1 else { return children[0] }
        return try make(.or(children), at: tokens[max(index - 1, 0)])
    }

    private mutating func parseAnd(depth: Int) throws -> GlifiQueryNode {
        var children = [try parseNear(depth: depth)]
        while true {
            if consumeKeyword("AND") != nil {
                children.append(try parseNear(depth: depth))
            } else if beginsUnary(current) {
                children.append(try parseNear(depth: depth))
            } else {
                break
            }
        }
        guard children.count > 1 else { return children[0] }
        return try make(.and(children), at: tokens[max(index - 1, 0)])
    }

    private mutating func parseNear(depth: Int) throws -> GlifiQueryNode {
        var left = try parseUnary(depth: depth)
        while let operatorToken = current,
            operatorToken.isKeyword("NEAR") || operatorToken.isKeyword("BEFORE")
        {
            index += 1
            guard consume(.slash) != nil else {
                throw failure("query.unexpected-token", at: current ?? operatorToken)
            }
            let distanceToken = try requireWord(code: "query.invalid-proximity")
            guard let distance = Int(distanceToken.wordValue ?? ""),
                distance >= 0,
                distance <= limits.maximumProximityDistance
            else {
                throw failure("query.invalid-proximity", at: distanceToken)
            }
            let right = try parseUnary(depth: depth)
            left = try make(
                .proximity(
                    left: left,
                    right: right,
                    distance: distance,
                    unit: .surfaceToken,
                    ordered: operatorToken.isKeyword("BEFORE")
                ),
                at: operatorToken
            )
        }
        return left
    }

    private mutating func parseUnary(depth: Int) throws -> GlifiQueryNode {
        if let token = consumeKeyword("NOT") {
            try validateDepth(depth + 1, at: token)
            return try make(.not(parseUnary(depth: depth + 1)), at: token)
        }
        return try parsePrimary(depth: depth)
    }

    private mutating func parsePrimary(depth: Int) throws -> GlifiQueryNode {
        if let opening = consume(.leftParenthesis) {
            try validateDepth(depth + 1, at: opening)
            let expression = try parseOr(depth: depth + 1)
            guard consume(.rightParenthesis) != nil else {
                throw failure("query.unexpected-token", at: current ?? opening)
            }
            return expression
        }
        return try parseClause()
    }

    private mutating func parseClause() throws -> GlifiQueryNode {
        var field = GlifiQueryField.form
        if let token = current,
            case let .word(fieldName) = token.kind,
            peek(1)?.kind == .colon
        {
            field = GlifiQueryField(rawValue: fieldName)
            guard field.isKnown else {
                throw failure("query.unknown-field", at: token)
            }
            index += 2
        }

        guard let token = current else {
            throw failure("query.unexpected-token", at: nil)
        }
        switch token.kind {
        case let .word(value):
            guard !token.isReservedKeyword else {
                throw failure("query.unexpected-token", at: token)
            }
            index += 1
            if value == "*" {
                return field == .form
                    ? try make(.matchAll, at: token)
                    : try make(.exists(field: field), at: token)
            }
            return try make(.term(field: field, value: value, matchMode: .exact), at: token)
        case let .phrase(value):
            index += 1
            let tokenization = try tokenizer.tokenize(value)
            let values = tokenization.tokens.compactMap { surfaceToken -> String? in
                guard surfaceToken.kind.contributesToLexicalStatistics else { return nil }
                return surfaceToken.range.text(in: value)
            }
            guard !values.isEmpty else {
                throw failure("query.empty-phrase", at: token)
            }
            guard values.count <= limits.maximumPhraseTokenCount else {
                throw failure(
                    "query.phrase-limit-exceeded",
                    category: .insufficientResources,
                    at: token
                )
            }
            var slop = 0
            if consume(.tilde) != nil {
                let slopToken = try requireWord(code: "query.invalid-slop")
                guard let parsed = Int(slopToken.wordValue ?? ""),
                    parsed >= 0,
                    parsed <= limits.maximumProximityDistance
                else {
                    throw failure("query.invalid-slop", at: slopToken)
                }
                slop = parsed
            }
            return try make(.phrase(field: field, values: values, slop: slop), at: token)
        case let .regex(pattern, flagText):
            index += 1
            guard pattern.utf8.count <= limits.maximumRegexByteCount else {
                throw failure(
                    "query.regex-limit-exceeded",
                    category: .insufficientResources,
                    at: token
                )
            }
            var flags: GlifiRegexFlags = []
            for flag in flagText {
                switch flag {
                case "i": flags.insert(.caseInsensitive)
                case "c": flags.insert(.canonicalEquivalence)
                default: throw failure("query.regex-rejected", at: token)
                }
            }
            return try make(.regex(field: field, pattern: pattern, flags: flags), at: token)
        case .leftBracket, .leftBrace:
            return try parseRange(field: field)
        default:
            throw failure("query.unexpected-token", at: token)
        }
    }

    private mutating func parseRange(field: GlifiQueryField) throws -> GlifiQueryNode {
        guard let opening = current else {
            throw failure("query.invalid-range", at: nil)
        }
        let includesLower = opening.kind == .leftBracket
        index += 1
        let lowerToken = try requireBound()
        guard consumeKeyword("TO") != nil else {
            throw failure("query.invalid-range", at: current ?? lowerToken)
        }
        let upperToken = try requireBound()
        guard let closing = current,
            closing.kind == .rightBracket || closing.kind == .rightBrace
        else {
            throw failure("query.invalid-range", at: current ?? upperToken)
        }
        index += 1
        let lower = lowerToken.boundValue == "*" ? nil : lowerToken.boundValue
        let upper = upperToken.boundValue == "*" ? nil : upperToken.boundValue
        guard lower != nil || upper != nil else {
            throw failure("query.invalid-range", at: opening)
        }
        return try make(
            .range(
                field: field,
                value: GlifiQueryRange(
                    lower: lower,
                    upper: upper,
                    includesLower: includesLower,
                    includesUpper: closing.kind == .rightBracket
                )
            ),
            at: opening
        )
    }

    private mutating func requireBound() throws -> QueryLexeme {
        guard let token = current,
            token.boundValue != nil,
            !token.isKeyword("TO")
        else {
            throw failure("query.invalid-range", at: current)
        }
        index += 1
        return token
    }

    private mutating func requireWord(code: String) throws -> QueryLexeme {
        guard let token = current, case .word = token.kind else {
            throw failure(code, at: current)
        }
        index += 1
        return token
    }

    private mutating func make(
        _ node: GlifiQueryNode,
        at token: QueryLexeme
    ) throws -> GlifiQueryNode {
        nodeCount += 1
        guard nodeCount <= limits.maximumNodeCount else {
            throw failure("query.node-limit-exceeded", category: .insufficientResources, at: token)
        }
        return node
    }

    private func validateDepth(_ depth: Int, at token: QueryLexeme) throws {
        guard depth <= limits.maximumDepth else {
            throw failure("query.depth-limit-exceeded", category: .insufficientResources, at: token)
        }
    }

    private var current: QueryLexeme? {
        peek(0)
    }

    private func peek(_ offset: Int) -> QueryLexeme? {
        let target = index + offset
        return tokens.indices.contains(target) ? tokens[target] : nil
    }

    private mutating func consume(_ kind: QueryLexeme.Kind) -> QueryLexeme? {
        guard let token = current, token.kind == kind else { return nil }
        index += 1
        return token
    }

    private mutating func consumeKeyword(_ keyword: String) -> QueryLexeme? {
        guard let token = current, token.isKeyword(keyword) else { return nil }
        index += 1
        return token
    }

    private func beginsUnary(_ token: QueryLexeme?) -> Bool {
        guard let token else { return false }
        if token.isKeyword("NOT") { return true }
        if token.isReservedKeyword { return false }
        switch token.kind {
        case .word, .phrase, .regex, .leftParenthesis, .leftBracket, .leftBrace:
            return true
        default:
            return false
        }
    }

    private func failure(
        _ code: String,
        category: GlifiFailureCategory = .invalidInput,
        at token: QueryLexeme?
    ) -> GlifiFailure {
        queryFailure(
            code,
            category: category,
            start: token?.start ?? tokens.last?.end ?? 0,
            end: token?.end ?? tokens.last?.end ?? 0
        )
    }
}

private struct QueryLexer {
    private let clusters: [QueryCluster]
    private var index = 0

    init(source: String) {
        var offset = 0
        clusters = source.map { character in
            defer { offset += String(character).utf8.count }
            return QueryCluster(
                character: character,
                start: offset,
                end: offset + String(character).utf8.count
            )
        }
    }

    mutating func scan() throws -> [QueryLexeme] {
        var tokens: [QueryLexeme] = []
        while index < clusters.count {
            if index.isMultiple(of: 4_096) {
                try Task.checkCancellation()
            }
            let cluster = clusters[index]
            if cluster.isWhitespace {
                index += 1
                continue
            }
            if let punctuation = punctuationKind(cluster.character) {
                tokens.append(
                    QueryLexeme(kind: punctuation, start: cluster.start, end: cluster.end))
                index += 1
                continue
            }
            if cluster.character == "\"" {
                tokens.append(try scanQuoted { .phrase($0) })
                continue
            }
            if cluster.character == "/" {
                if let previous = tokens.last,
                    previous.isKeyword("NEAR") || previous.isKeyword("BEFORE")
                {
                    tokens.append(
                        QueryLexeme(kind: .slash, start: cluster.start, end: cluster.end)
                    )
                    index += 1
                } else {
                    tokens.append(try scanRegex())
                }
                continue
            }
            tokens.append(try scanWord())
        }
        return tokens
    }

    private mutating func scanQuoted(kind: (String) -> QueryLexeme.Kind) throws -> QueryLexeme {
        let start = clusters[index].start
        index += 1
        var value = ""
        while index < clusters.count {
            let cluster = clusters[index]
            if cluster.character == "\"" {
                index += 1
                return QueryLexeme(kind: kind(value), start: start, end: cluster.end)
            }
            if cluster.character == "\\" {
                index += 1
                guard index < clusters.count else {
                    throw queryFailure(
                        "query.invalid-escape",
                        start: cluster.start,
                        end: cluster.end
                    )
                }
            }
            value.append(clusters[index].character)
            index += 1
        }
        throw queryFailure(
            "query.unterminated-phrase",
            start: start,
            end: clusters.last?.end ?? start
        )
    }

    private mutating func scanRegex() throws -> QueryLexeme {
        let start = clusters[index].start
        index += 1
        var pattern = ""
        var escaped = false
        while index < clusters.count {
            let cluster = clusters[index]
            if !escaped, cluster.character == "/" {
                index += 1
                var flags = ""
                while index < clusters.count,
                    clusters[index].character.isASCII,
                    clusters[index].character.isLetter
                {
                    flags.append(clusters[index].character)
                    index += 1
                }
                return QueryLexeme(
                    kind: .regex(pattern: pattern, flags: flags),
                    start: start,
                    end: clusters[index - 1].end
                )
            }
            if !escaped, cluster.character == "\\" {
                escaped = true
                pattern.append(cluster.character)
                index += 1
                continue
            }
            escaped = false
            pattern.append(cluster.character)
            index += 1
        }

        throw queryFailure(
            "query.regex-rejected",
            start: start,
            end: clusters.last?.end ?? start
        )
    }

    private mutating func scanWord() throws -> QueryLexeme {
        let start = clusters[index].start
        var value = ""
        var end = clusters[index].end
        var hadEscape = false
        while index < clusters.count {
            let cluster = clusters[index]
            if cluster.isWhitespace || isReserved(cluster.character) {
                break
            }
            if cluster.character == "\\" {
                hadEscape = true
                let escapeStart = cluster.start
                index += 1
                guard index < clusters.count else {
                    throw queryFailure("query.invalid-escape", start: escapeStart, end: cluster.end)
                }
            }
            value.append(clusters[index].character)
            end = clusters[index].end
            index += 1
        }
        guard !value.isEmpty else {
            throw queryFailure("query.unexpected-token", start: start, end: end)
        }
        return QueryLexeme(kind: .word(value), start: start, end: end, escaped: hadEscape)
    }

    private func punctuationKind(_ character: Character) -> QueryLexeme.Kind? {
        switch character {
        case "(": .leftParenthesis
        case ")": .rightParenthesis
        case "[": .leftBracket
        case "]": .rightBracket
        case "{": .leftBrace
        case "}": .rightBrace
        case ":": .colon
        case "~": .tilde
        default: nil
        }
    }

    private func isReserved(_ character: Character) -> Bool {
        ["(", ")", "[", "]", "{", "}", ":", "~", "\"", "/"].contains(character)
    }
}

private struct QueryCluster {
    let character: Character
    let start: Int
    let end: Int

    var isWhitespace: Bool {
        character.unicodeScalars.allSatisfy { CharacterSet.whitespacesAndNewlines.contains($0) }
    }
}

private struct QueryLexeme: Equatable {
    enum Kind: Equatable {
        case word(String)
        case phrase(String)
        case regex(pattern: String, flags: String)
        case leftParenthesis
        case rightParenthesis
        case leftBracket
        case rightBracket
        case leftBrace
        case rightBrace
        case colon
        case tilde
        case slash
    }

    let kind: Kind
    let start: Int
    let end: Int
    let escaped: Bool

    init(kind: Kind, start: Int, end: Int, escaped: Bool = false) {
        self.kind = kind
        self.start = start
        self.end = end
        self.escaped = escaped
    }

    var wordValue: String? {
        guard case let .word(value) = kind else { return nil }
        return value
    }

    var boundValue: String? {
        switch kind {
        case let .word(value), let .phrase(value): value
        default: nil
        }
    }

    var isReservedKeyword: Bool {
        ["AND", "OR", "NOT", "TO", "NEAR", "BEFORE"].contains { isKeyword($0) }
    }

    func isKeyword(_ keyword: String) -> Bool {
        guard !escaped,
            case let .word(value) = kind,
            value.unicodeScalars.allSatisfy({ $0.isASCII })
        else {
            return false
        }
        return value.uppercased() == keyword
    }
}

private func queryFailure(
    _ code: String,
    category: GlifiFailureCategory = .invalidInput,
    start: Int,
    end: Int
) -> GlifiFailure {
    GlifiFailure(
        code: code,
        category: category,
        operation: .query,
        retryDisposition: GlifiFailureTaxonomy.defaultRetry(category),
        retainedState: GlifiFailureTaxonomy.defaultRetained(category, preferred: .unchanged),
        messageKey: "failure.\(code)",
        arguments: ["start": String(start), "end": String(end)]
    )
}
