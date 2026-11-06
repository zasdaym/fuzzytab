import AppKit
import Foundation

public protocol Provider: Sendable {
    var source: Source { get }
    func items() async throws -> [Item]
    func activate(_ target: Target) async throws
}

func isRunning(_ source: Source) -> Bool {
    !NSRunningApplication.runningApplications(withBundleIdentifier: source.bundleID).isEmpty
}

@MainActor
func activateApp(_ source: Source) {
    NSRunningApplication.runningApplications(withBundleIdentifier: source.bundleID).first?.activate()
}

// MARK: - Brave

public struct BraveProvider: Provider {
    public let source = Source.brave
    private let osascript = URL(fileURLWithPath: "/usr/bin/osascript")

    public init() {}

    private static let listScript = """
    function run() {
      const app = Application("com.brave.Browser");
      const out = [];
      for (const w of app.windows()) {
        const id = String(w.id());
        const titles = w.tabs.title();
        const urls = w.tabs.url();
        titles.forEach((t, i) => out.push({w: id, i: i + 1, t: t, u: urls[i]}));
      }
      return JSON.stringify(out);
    }
    """

    private static let activateScript = """
    function run(argv) {
      const app = Application("com.brave.Browser");
      // Brave reports window IDs as strings, so compare loosely.
      const w = app.windows().find(w => w.id() == argv[0]);
      if (!w) throw new Error("Brave window is closed");
      w.activeTabIndex = Number(argv[1]);
      w.index = 1;
      app.activate();
    }
    """

    public func items() async throws -> [Item] {
        // AppleScript launches the target app, so skip Brave when it is not running.
        guard isRunning(.brave) else { return [] }
        let data = try await Command.run(osascript, ["-l", "JavaScript", "-e", Self.listScript])
        return try Self.parse(data)
    }

    public func activate(_ target: Target) async throws {
        guard case let .braveTab(windowID, tabIndex) = target else { return }
        _ = try await Command.run(osascript, ["-l", "JavaScript", "-e", Self.activateScript, windowID, String(tabIndex)])
    }

    static func parse(_ data: Data) throws -> [Item] {
        struct Tab: Decodable { let w: String; let i: Int; let t: String; let u: String }
        return try JSONDecoder().decode([Tab].self, from: data).map {
            Item(source: .brave, title: $0.t.isEmpty ? $0.u : $0.t, subtitle: $0.u,
                 target: .braveTab(windowID: $0.w, tabIndex: $0.i))
        }
    }
}

// MARK: - Rex

public struct RexProvider: Provider {
    public let source = Source.rex
    private let cli: URL

    public init(cli: URL = RexProvider.defaultCLI) {
        self.cli = cli
    }

    public static let defaultCLI = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app/Contents/MacOS/rex")

    // The server only answers session queries on a connection attached to that session.
    private static let listScript = """
    local out = {}
    for _, s in ipairs(assert(rex.call("session.list")).sessions) do
      local v = assert(rex.call("session.attach", {session_id = s.session_id}))
      v = v.view or v
      for i, w in ipairs(v.windows or {}) do
        local title, pwd = "", ""
        if w.focused_block_id then
          local t = rex.call("block.method", {session_id = s.session_id, block_id = w.focused_block_id, method = "title"})
          if t then title = t.title or "" end
          local p = rex.call("block.method", {session_id = s.session_id, block_id = w.focused_block_id, method = "pwd"})
          if p then pwd = p.pwd or "" end
        end
        table.insert(out, {session_id = s.session_id, session = s.label, window_id = w.window_id, index = i, title = title, pwd = pwd})
      end
      rex.call("session.detach", {session_id = s.session_id})
    end
    return out
    """

    public func items() async throws -> [Item] {
        guard isRunning(.rex) else { return [] }
        let data = try await Command.run(cli, ["do", "-e", Self.listScript, "--json", "--autostart=false"])
        return try Self.parse(data)
    }

    public func activate(_ target: Target) async throws {
        guard case let .rexWindow(sessionID, windowID) = target else { return }
        _ = try await Command.run(cli, ["do", "session.select", "session_id=\(sessionID)", "window_id=\(windowID)", "--autostart=false"])
        await activateApp(.rex)
    }

    static func parse(_ data: Data) throws -> [Item] {
        struct Window: Decodable {
            let session_id: String
            let session: String
            let window_id: String
            let index: Int
            let title: String
            let pwd: String
        }
        // Lua encodes an empty table as an object, not an array.
        if (try? JSONDecoder().decode([String: String].self, from: data))?.isEmpty == true { return [] }
        return try JSONDecoder().decode([Window].self, from: data).map { w in
            let path = URL(string: w.pwd)?.path ?? ""
            let title = w.title.isEmpty ? "Tab \(w.index)" : w.title
            return Item(source: .rex, title: title, subtitle: [w.session, abbreviateHome(path)].filter { !$0.isEmpty }.joined(separator: " · "),
                        target: .rexWindow(sessionID: w.session_id, windowID: w.window_id))
        }
    }
}

// MARK: - Claude

public struct ClaudeProvider: Provider {
    public let source = Source.claude
    private let sessionsDir: URL

    public init(sessionsDir: URL = ClaudeProvider.defaultSessionsDir) {
        self.sessionsDir = sessionsDir
    }

    public static let defaultSessionsDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Claude/claude-code-sessions")

    public func items() async throws -> [Item] {
        try Self.load(from: sessionsDir)
    }

    @MainActor
    public func activate(_ target: Target) async throws {
        guard case let .claudeSession(id) = target else { return }
        var components = URLComponents(string: "claude://code/continue")!
        components.queryItems = [URLQueryItem(name: "session", value: id)]
        NSWorkspace.shared.open(components.url!)
    }

    /// Reads the desktop app's Claude Code session files, laid out as `<account>/<org>/local_<id>.json`.
    static func load(from dir: URL) throws -> [Item] {
        struct Session: Decodable {
            let sessionId: String
            let title: String?
            let cwd: String?
            let isArchived: Bool?
            let lastFocusedAt: Double?
        }
        let fm = FileManager.default
        guard fm.fileExists(atPath: dir.path) else { return [] }
        var sessions: [Session] = []
        let decoder = JSONDecoder()
        for account in try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for org in (try? fm.contentsOfDirectory(at: account, includingPropertiesForKeys: nil)) ?? [] {
                for file in (try? fm.contentsOfDirectory(at: org, includingPropertiesForKeys: nil)) ?? []
                where file.lastPathComponent.hasPrefix("local_") && file.pathExtension == "json" {
                    guard let data = try? Data(contentsOf: file),
                          let s = try? decoder.decode(Session.self, from: data),
                          s.isArchived != true else { continue }
                    sessions.append(s)
                }
            }
        }
        return sessions
            .sorted { ($0.lastFocusedAt ?? 0) > ($1.lastFocusedAt ?? 0) }
            .map { s in
                let cwd = abbreviateHome(s.cwd ?? "")
                let title = s.title?.isEmpty == false ? s.title! : (cwd.isEmpty ? "Untitled session" : cwd)
                return Item(source: .claude, title: title, subtitle: cwd, target: .claudeSession(id: s.sessionId))
            }
    }
}

func abbreviateHome(_ path: String) -> String {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    if path == home { return "~" }
    if path.hasPrefix(home + "/") { return "~" + path.dropFirst(home.count) }
    return path
}
