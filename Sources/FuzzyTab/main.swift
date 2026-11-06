import AppKit
import Carbon.HIToolbox
import FuzzyTabCore
import SwiftUI

final class SwitcherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let switcher = Switcher(providers: [BraveProvider(), RexProvider(), ClaudeProvider()])
    private var panel: SwitcherPanel!
    private var statusItem: NSStatusItem!
    private var hotKey: HotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = SwitcherPanel(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 440),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered, defer: true)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: SwitcherView(
            switcher: switcher,
            onChoose: { [weak self] item in self?.choose(item) },
            onCancel: { [weak self] in self?.hide() }))

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.stack", accessibilityDescription: "FuzzyTab")
        let menu = NSMenu()
        menu.addItem(withTitle: "Show FuzzyTab (⌥Space)", action: #selector(toggle), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu

        hotKey = HotKey(keyCode: kVK_Space, modifiers: optionKey) { [weak self] in
            MainActor.assumeIsolated { self?.toggle() }
        }

        Task { await switcher.refresh() }
    }

    @objc func toggle() {
        panel.isVisible ? hide() : show()
    }

    private func show() {
        switcher.query = ""
        Task { await switcher.refresh() }
        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }

    private func hide() {
        panel.orderOut(nil)
    }

    private func choose(_ item: Item) {
        hide()
        Task { await switcher.activate(item) }
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }
}

// `FuzzyTab --list` prints every item, to check the providers without the UI.
if CommandLine.arguments.contains("--list") {
    Task { @MainActor in
        let switcher = Switcher(providers: [BraveProvider(), RexProvider(), ClaudeProvider()])
        await switcher.refresh()
        for item in switcher.results { print("[\(item.source.displayName)] \(item.title) — \(item.subtitle)") }
        for (source, message) in switcher.errors { print("error \(source.displayName): \(message)") }
        exit(0)
    }
    dispatchMain()
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
