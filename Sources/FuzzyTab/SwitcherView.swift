import AppKit
import FuzzyTabCore
import SwiftUI

struct SwitcherView: View {
    @Bindable var switcher: Switcher
    let onChoose: (Item) -> Void
    let onCancel: () -> Void
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search tabs and sessions", text: $switcher.query)
                .textFieldStyle(.plain)
                .font(.system(size: 20))
                .padding(14)
                .focused($searchFocused)
                .onSubmit { if let item = switcher.selectedItem { onChoose(item) } }
                .onKeyPress(.downArrow) { switcher.moveSelection(by: 1); return .handled }
                .onKeyPress(.upArrow) { switcher.moveSelection(by: -1); return .handled }
                .onKeyPress(keys: ["n", "j"]) { press in
                    guard press.modifiers == .control else { return .ignored }
                    switcher.moveSelection(by: 1); return .handled
                }
                .onKeyPress(keys: ["p", "k"]) { press in
                    guard press.modifiers == .control else { return .ignored }
                    switcher.moveSelection(by: -1); return .handled
                }
                .onKeyPress(.escape) { onCancel(); return .handled }

            Divider()

            ScrollViewReader { proxy in
                List(switcher.results, selection: $switcher.selection) { item in
                    Row(item: item)
                        .tag(item.id)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) { onChoose(item) }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .onChange(of: switcher.selection) { _, id in
                    if let id { proxy.scrollTo(id) }
                }
            }

            if !switcher.errors.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(switcher.errors.sorted(by: { $0.key.rawValue < $1.key.rawValue }), id: \.key) { source, message in
                        Text("\(source.displayName): \(message)")
                            .lineLimit(2)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
            }
        }
        .frame(width: 680, height: 440)
        .background(.regularMaterial)
        // The panel keeps a hidden title bar for its rounded corners; do not reserve space for it.
        .ignoresSafeArea()
        .onAppear { searchFocused = true }
    }
}

private struct Row: View {
    let item: Item

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: AppIcons.icon(for: item.source))
                .resizable()
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title).lineLimit(1)
                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .padding(.vertical, 3)
    }
}

@MainActor
enum AppIcons {
    private static var cache: [Source: NSImage] = [:]

    static func icon(for source: Source) -> NSImage {
        if let cached = cache[source] { return cached }
        let image = NSWorkspace.shared.urlForApplication(withBundleIdentifier: source.bundleID)
            .map { NSWorkspace.shared.icon(forFile: $0.path) }
            ?? NSImage(systemSymbolName: "app", accessibilityDescription: nil)!
        cache[source] = image
        return image
    }
}
