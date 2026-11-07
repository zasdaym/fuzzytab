import Foundation
import Observation

@MainActor
@Observable
public final class Switcher {
    public var query = "" {
        didSet { applyFilter() }
    }
    public private(set) var results: [Item] = []
    public var selection: Item.ID?
    public private(set) var errors: [Source: String] = [:]

    private var items: [Item] = []
    private var recent: [Target] = []
    private let providers: [Source: any Provider]
    public let settings: AppSettings

    public init(providers: [any Provider], settings: AppSettings) {
        self.providers = Dictionary(uniqueKeysWithValues: providers.map { ($0.source, $0) })
        self.settings = settings
    }

    public func refresh() async {
        let loaded = await withTaskGroup(of: (Source, Result<[Item], Error>).self) { group in
            for (source, provider) in providers where settings.isEnabled(source) {
                group.addTask { (source, await Result { try await provider.items() }) }
            }
            var all: [Source: Result<[Item], Error>] = [:]
            for await (source, result) in group { all[source] = result }
            return all
        }
        var merged: [Item] = []
        var errors: [Source: String] = [:]
        for source in Source.allCases {
            switch loaded[source] {
            case .success(let found): merged += found
            case .failure(let error): errors[source] = error.localizedDescription
            case nil: break
            }
        }
        // Recently switched targets first, then the providers' own order.
        let rank = Dictionary(uniqueKeysWithValues: recent.enumerated().map { ($1, $0) })
        items = merged.enumerated()
            .sorted { (rank[$0.element.target] ?? Int.max, $0.offset) < (rank[$1.element.target] ?? Int.max, $1.offset) }
            .map(\.element)
        self.errors = errors
        applyFilter()
    }

    public func moveSelection(by delta: Int) {
        guard !results.isEmpty else { return }
        let current = results.firstIndex { $0.id == selection } ?? 0
        selection = results[max(0, min(results.count - 1, current + delta))].id
    }

    public var selectedItem: Item? {
        results.first { $0.id == selection }
    }

    public func activate(_ item: Item) async {
        recent.removeAll { $0 == item.target }
        recent.insert(item.target, at: 0)
        do {
            try await providers[item.source]?.activate(item.target)
            errors[item.source] = nil
        } catch {
            errors[item.source] = error.localizedDescription
        }
    }

    /// Applies the current settings to the loaded items without fetching again.
    public func applyFilter() {
        // Cap after matching, so a search still reaches entries past the limit.
        let enabled = items.filter { settings.isEnabled($0.source) }
        results = FuzzyMatcher.capped(FuzzyMatcher.filter(enabled, query: query), perSource: settings.limit)
        if !results.contains(where: { $0.id == selection }) {
            selection = results.first?.id
        }
    }
}

private extension Result where Failure == Error {
    init(catching body: () async throws -> Success) async {
        do { self = .success(try await body()) } catch { self = .failure(error) }
    }
}
