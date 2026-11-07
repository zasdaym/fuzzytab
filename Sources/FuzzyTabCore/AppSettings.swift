import Foundation
import Observation

@MainActor
@Observable
public final class AppSettings {
    public static let defaultLimit = 10

    @ObservationIgnored private let defaults: UserDefaults

    /// Maximum entries shown per app. Shared by all apps.
    public var limit: Int {
        get { storedLimit }
        set {
            storedLimit = max(1, newValue)
            defaults.set(storedLimit, forKey: "limit")
        }
    }

    // @Observable makes a stored property's didSet re-enter on assignment, so clamp through a backing value.
    private var storedLimit: Int

    public private(set) var enabled: Set<Source>

    /// The order of apps in settings and in results.
    public private(set) var order: [Source]

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedLimit = defaults.integer(forKey: "limit")
        self.storedLimit = storedLimit > 0 ? storedLimit : Self.defaultLimit
        let disabled = Set((defaults.stringArray(forKey: "disabledSources") ?? []).compactMap(Source.init(rawValue:)))
        enabled = Set(Source.allCases).subtracting(disabled)
        let stored = (defaults.stringArray(forKey: "sourceOrder") ?? []).compactMap(Source.init(rawValue:))
        // Apps added in a later version go at the end.
        order = stored + Source.allCases.filter { !stored.contains($0) }
    }

    public func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let moving = source.map { order[$0] }
        let before = order[..<destination].filter { !moving.contains($0) }
        let after = order[destination...].filter { !moving.contains($0) }
        order = before + moving + after
        defaults.set(order.map(\.rawValue), forKey: "sourceOrder")
    }

    public func isEnabled(_ source: Source) -> Bool {
        enabled.contains(source)
    }

    public func setEnabled(_ source: Source, _ on: Bool) {
        if on { enabled.insert(source) } else { enabled.remove(source) }
        // Store the disabled set so apps added later start enabled.
        let disabled = Source.allCases.filter { !enabled.contains($0) }.map(\.rawValue)
        defaults.set(disabled, forKey: "disabledSources")
    }
}
