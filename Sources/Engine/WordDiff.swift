import Foundation

// The word-level diff algorithm, shared by the panel's grammar result and
// the All Runs detail pane. It lived inside Panel/DiffView.swift, which made
// Engine depend on a view file to compute a diff.

enum DiffOp: Equatable {
    case equal(String)
    case deletion(String)
    case insertion(String)
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Lowercased and stripped of surrounding punctuation, so a substitution that
    /// only fixes case or a comma reads as a correction rather than a reword.
    var normalizedForComparison: String {
        trimmed
            .lowercased()
            .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    }
}

enum WordDiff {
    /// Word-level diff using the classic longest-common-subsequence approach.
    /// Tokens split on whitespace boundaries, preserving the whitespace as part
    /// of each token so reconstruction round-trips exactly.
    ///
    /// Grammar corrections leave most text untouched, so the common prefix and
    /// suffix are trimmed before the O(n*m) LCS runs; the DP table then only
    /// covers the changed middle region. Tokens are compared as integer ids and
    /// the table is a flat Int32 buffer to keep the worst case cheap.
    static func diff(original: String, revised: String) -> [DiffOp] {
        let a = tokenize(original)
        let b = tokenize(revised)
        guard !a.isEmpty || !b.isEmpty else { return [] }

        var start = 0
        while start < a.count, start < b.count, a[start] == b[start] {
            start += 1
        }
        var endA = a.count
        var endB = b.count
        while endA > start, endB > start, a[endA - 1] == b[endB - 1] {
            endA -= 1
            endB -= 1
        }

        var ops: [DiffOp] = []
        if start > 0 {
            ops.append(.equal(a[0..<start].joined()))
        }
        ops.append(contentsOf: lcsDiff(Array(a[start..<endA]), Array(b[start..<endB])))
        if endA < a.count {
            ops.append(.equal(a[endA...].joined()))
        }
        return merge(ops)
    }

    private static func lcsDiff(_ a: [String], _ b: [String]) -> [DiffOp] {
        if a.isEmpty { return b.isEmpty ? [] : [.insertion(b.joined())] }
        if b.isEmpty { return [.deletion(a.joined())] }

        // Compare integer ids in the hot loop instead of strings.
        var ids: [String: Int32] = [:]
        func id(_ token: String) -> Int32 {
            if let existing = ids[token] { return existing }
            let next = Int32(ids.count)
            ids[token] = next
            return next
        }
        let ai = a.map(id)
        let bi = b.map(id)

        let n = a.count
        let m = b.count
        let width = m + 1
        var lengths = [Int32](repeating: 0, count: (n + 1) * width)

        lengths.withUnsafeMutableBufferPointer { table in
            for i in stride(from: n - 1, through: 0, by: -1) {
                for j in stride(from: m - 1, through: 0, by: -1) {
                    if ai[i] == bi[j] {
                        table[i * width + j] = table[(i + 1) * width + j + 1] + 1
                    } else {
                        table[i * width + j] = max(table[(i + 1) * width + j], table[i * width + j + 1])
                    }
                }
            }
        }

        var ops: [DiffOp] = []
        var i = 0, j = 0
        while i < n && j < m {
            if ai[i] == bi[j] {
                ops.append(.equal(a[i]))
                i += 1
                j += 1
            } else if lengths[(i + 1) * width + j] >= lengths[i * width + j + 1] {
                ops.append(.deletion(a[i]))
                i += 1
            } else {
                ops.append(.insertion(b[j]))
                j += 1
            }
        }
        while i < n { ops.append(.deletion(a[i])); i += 1 }
        while j < m { ops.append(.insertion(b[j])); j += 1 }
        return ops
    }

    /// Share of substituted words that are unrelated to the word they replaced
    /// (0 = every change is a near-miss correction, 1 = every change is a
    /// different word entirely).
    ///
    /// A spelling or punctuation fix replaces a word with something almost
    /// identical: "discus" → "discuss", "tommorow" → "tomorrow". A paraphrase
    /// replaces it with an unrelated word: "note" → "reminder", "moment" →
    /// "time". Grammar is only licensed to do the former, so this is what
    /// separates a correction from a restyle.
    ///
    /// Length cannot do that job. A previous version flagged Grammar only when
    /// the result got shorter, and missed the reported case entirely — that
    /// paraphrase came back three tokens *longer*.
    static func paraphraseScore(_ ops: [DiffOp]) -> Double {
        var unrelated = 0
        var substitutions = 0
        var index = 0
        while index < ops.count {
            guard case .deletion(let removed) = ops[index] else {
                // A bare insertion is added content, which corrections never do.
                if case .insertion(let added) = ops[index], !added.trimmed.isEmpty {
                    substitutions += 1
                    unrelated += 1
                }
                index += 1
                continue
            }
            // A deletion immediately followed by an insertion is a substitution.
            if index + 1 < ops.count, case .insertion(let added) = ops[index + 1] {
                if !removed.trimmed.isEmpty || !added.trimmed.isEmpty {
                    substitutions += 1
                    if !isPlausibleCorrection(of: removed, to: added) { unrelated += 1 }
                }
                index += 2
                continue
            }
            if !removed.trimmed.isEmpty {
                // Content removed outright.
                substitutions += 1
                unrelated += 1
            }
            index += 1
        }
        guard substitutions > 0 else { return 0 }
        return Double(unrelated) / Double(substitutions)
    }

    /// True when `added` looks like a corrected spelling of `removed` rather than
    /// a different word. Compared case- and punctuation-insensitively, so "i" →
    /// "I" and "monday," → "Monday;" count as corrections.
    private static func isPlausibleCorrection(of removed: String, to added: String) -> Bool {
        let a = removed.normalizedForComparison
        let b = added.normalizedForComparison
        if a == b { return true }
        if a.isEmpty || b.isEmpty { return false }
        let distance = editDistance(Array(a), Array(b))
        return Double(distance) / Double(max(a.count, b.count)) <= 0.5
    }

    private static func editDistance(_ a: [Character], _ b: [Character]) -> Int {
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var previous = Array(0...b.count)
        var current = [Int](repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            current[0] = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
            }
            swap(&previous, &current)
        }
        return previous[b.count]
    }

    /// Share of the revised text that survived unchanged from the original
    /// (1 = untouched, 0 = nothing in common).
    ///
    /// This is the measure of whether a diff is worth rendering. `changeRatio`
    /// below is not: it weights equal text double and is dominated by length, so
    /// a single typo in a two-word string scores 0.43 and an ordinary copy-edit
    /// scores 0.51 — indistinguishable from a genuine rewrite. Retention compares
    /// like with like, against the length of the text actually being shown.
    static func retentionRatio(_ ops: [DiffOp]) -> Double {
        var kept = 0
        var revisedLength = 0
        for op in ops {
            switch op {
            case .equal(let s):
                kept += s.count
                revisedLength += s.count
            case .insertion(let s):
                revisedLength += s.count
            case .deletion:
                // Deleted text is not part of what the user is reading.
                break
            }
        }
        guard revisedLength > 0 else { return 1 }
        return Double(kept) / Double(revisedLength)
    }

    /// Fraction of the diff that is changed text (0 = identical, 1 = fully
    /// rewritten), measured in characters. Used to flag restyled results.
    static func changeRatio(_ ops: [DiffOp]) -> Double {
        var changed = 0
        var total = 0
        for op in ops {
            switch op {
            case .equal(let s):
                total += 2 * s.count
            case .deletion(let s), .insertion(let s):
                changed += s.count
                total += s.count
            }
        }
        guard total > 0 else { return 0 }
        return Double(changed) / Double(total)
    }

    /// Splits into tokens, keeping trailing whitespace attached so joining tokens
    /// back together reproduces the original spacing exactly.
    private static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var inWhitespace: Bool?

        for char in text {
            let isSpace = char.isWhitespace
            if inWhitespace == nil {
                inWhitespace = isSpace
            }
            if isSpace == inWhitespace {
                current.append(char)
            } else {
                tokens.append(current)
                current = String(char)
                inWhitespace = isSpace
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    private static func merge(_ ops: [DiffOp]) -> [DiffOp] {
        var merged: [DiffOp] = []
        for op in ops {
            if let last = merged.last {
                switch (last, op) {
                case (.equal(let l), .equal(let r)):
                    merged[merged.count - 1] = .equal(l + r)
                    continue
                case (.deletion(let l), .deletion(let r)):
                    merged[merged.count - 1] = .deletion(l + r)
                    continue
                case (.insertion(let l), .insertion(let r)):
                    merged[merged.count - 1] = .insertion(l + r)
                    continue
                default:
                    break
                }
            }
            merged.append(op)
        }
        return merged
    }
}
