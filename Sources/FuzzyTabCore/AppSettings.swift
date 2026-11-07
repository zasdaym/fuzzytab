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

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedLimit = defaults.integer(forKey: "limit")
        self.storedLimit = storedLimit > 0 ? storedLimit : Self.defaultLimit
        let disabled = Set((defaults.stringArray(forKey: "disabledSources") ?? []).compactMap(Source.init(rawValue:)))
        enabled = Set(Source.allCases).subtracting(disabled)
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
