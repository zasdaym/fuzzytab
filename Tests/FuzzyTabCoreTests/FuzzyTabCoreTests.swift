import Foundation
import Testing
@testable import FuzzyTabCore

private func item(_ title: String, _ subtitle: String = "", source: Source = .brave) -> Item {
    Item(source: source, title: title, subtitle: subtitle, target: .claudeSession(id: title))
}

@Suite struct FuzzyMatcherTests {
    @Test func rejectsOutOfOrderCharacters() {
        #expect(FuzzyMatcher.score("abc", "cba") == nil)
        #expect(FuzzyMatcher.score("abc", "a-b-c") != nil)
    }

    @Test func ranksWordStartsAndAdjacentRunsFirst() {
        let items = [item("grafana alerting"), item("Pull request · VictoriaMetrics"), item("vmagent docs")]
        #expect(FuzzyMatcher.filter(items, query: "pr").first?.title == "Pull request · VictoriaMetrics")
    }

    @Test func requiresEveryTokenAndSearchesSubtitleAndSource() {
        let items = [
            item("Inbox", "https://mail.google.com", source: .brave),
            item("Inbox", "~/notes", source: .rex),
        ]
        #expect(FuzzyMatcher.filter(items, query: "inbox rex").map(\.source) == [.rex])
        #expect(FuzzyMatcher.filter(items, query: "inbox mail").map(\.source) == [.brave])
    }

    @Test func emptyQueryKeepsOrder() {
        let items = [item("b"), item("a")]
        #expect(FuzzyMatcher.filter(items, query: "  ") == items)
    }
}

@Suite struct ParserTests {
    @Test func braveUsesURLWhenTitleIsEmpty() throws {
        let json = #"[{"w":"7","i":2,"t":"","u":"https://example.com"}]"#
        let items = try BraveProvider.parse(Data(json.utf8))
        #expect(items == [Item(source: .brave, title: "https://example.com", subtitle: "https://example.com",
                               target: .braveTab(windowID: "7", tabIndex: 2))])
    }

    @Test func rexHandlesLuaEmptyTable() throws {
        #expect(try RexProvider.parse(Data("{}".utf8)).isEmpty)
    }

    @Test func rexBuildsSubtitleFromSessionAndPath() throws {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let json = """
        [{"session_id":"s1","session":"work","window_id":"w1","index":1,"title":"","pwd":"file://host\(home)/src"}]
        """
        let items = try RexProvider.parse(Data(json.utf8))
        #expect(items.first?.title == "Tab 1")
        #expect(items.first?.subtitle == "work · ~/src")
        #expect(items.first?.target == .rexWindow(sessionID: "s1", windowID: "w1"))
    }

    @Test func claudeSkipsArchivedAndSortsByLastFocus() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let org = dir.appendingPathComponent("acct/org")
        try FileManager.default.createDirectory(at: org, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let sessions = [
            ("local_a", #"{"sessionId":"local_a","title":"old","lastFocusedAt":1}"#),
            ("local_b", #"{"sessionId":"local_b","title":"new","lastFocusedAt":2}"#),
            ("local_c", #"{"sessionId":"local_c","title":"gone","isArchived":true,"lastFocusedAt":3}"#),
            ("local_d", "not json"),
        ]
        for (name, body) in sessions {
            try Data(body.utf8).write(to: org.appendingPathComponent("\(name).json"))
        }

        let items = try ClaudeProvider.load(from: dir)
        #expect(items.map(\.title) == ["new", "old"])
    }
}
