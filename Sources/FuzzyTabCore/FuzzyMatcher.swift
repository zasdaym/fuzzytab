import Foundation

public enum FuzzyMatcher {
    /// Scores `candidate` against `query` as an ordered subsequence match.
    /// Returns nil when not every query character appears in order.
    /// Matches at word starts and runs of adjacent characters score higher.
    public static func score(_ query: String, _ candidate: String) -> Int? {
        let q = Array(query.lowercased())
        let c = Array(candidate.lowercased())
        guard !q.isEmpty else { return 0 }

        var score = 0
        var qi = 0
        var previousMatch = -2
        for (ci, ch) in c.enumerated() where qi < q.count {
            guard ch == q[qi] else { continue }
            score += 1
            if ci == previousMatch + 1 { score += 5 }
            if ci == 0 || isSeparator(c[ci - 1]) { score += 8 }
            previousMatch = ci
            qi += 1
        }
        guard qi == q.count else { return nil }
        // Prefer shorter candidates when the match quality is equal.
        return score * 100 - min(c.count, 99)
    }

    /// Filters and ranks items. Each whitespace-separated query token must match.
    /// Items keep their input order when the query is empty or scores tie.
    public static func filter(_ items: [Item], query: String) -> [Item] {
        let tokens = query.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !tokens.isEmpty else { return items }

        var scored: [(item: Item, score: Int, order: Int)] = []
        for (order, item) in items.enumerated() {
            let text = item.searchText
            var total = 0
            var matched = true
            for token in tokens {
                guard let s = score(token, text) else { matched = false; break }
                total += s
            }
            if matched { scored.append((item, total, order)) }
        }
        scored.sort { $0.score != $1.score ? $0.score > $1.score : $0.order < $1.order }
        return scored.map(\.item)
    }

    private static func isSeparator(_ ch: Character) -> Bool {
        !(ch.isLetter || ch.isNumber)
    }
}
