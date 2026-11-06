import Foundation

public enum Source: String, CaseIterable, Sendable {
    case brave, rex, claude

    public var bundleID: String {
        switch self {
        case .brave: "com.brave.Browser"
        case .rex: "com.superlogical.rex"
        case .claude: "com.anthropic.claudefordesktop"
        }
    }

    public var displayName: String {
        switch self {
        case .brave: "Brave"
        case .rex: "Rex"
        case .claude: "Claude"
        }
    }
}

public enum Target: Hashable, Sendable {
    case braveTab(windowID: String, tabIndex: Int)
    case rexWindow(sessionID: String, windowID: String)
    case claudeSession(id: String)
}

public struct Item: Identifiable, Hashable, Sendable {
    public let source: Source
    public let title: String
    public let subtitle: String
    public let target: Target

    public var id: Target { target }

    public init(source: Source, title: String, subtitle: String, target: Target) {
        self.source = source
        self.title = title
        self.subtitle = subtitle
        self.target = target
    }

    var searchText: String { "\(title) \(subtitle) \(source.displayName)" }
}
