import FuzzyTabCore
import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let onChange: () -> Void
    // Not @State: with the Command Line Tools, the macOS 27 SDK cannot expand SwiftUI's @State macro.
    // The view never draws this value, so a plain reference is enough.
    private let drag = DragState()

    var body: some View {
        Form {
            Section {
                ForEach(settings.order, id: \.self) { source in
                    HStack {
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(.secondary)
                        Toggle(isOn: Binding(
                            get: { settings.isEnabled(source) },
                            set: { settings.setEnabled(source, $0); onChange() }
                        )) {
                            Label {
                                Text(source.displayName)
                            } icon: {
                                Image(nsImage: AppIcons.icon(for: source)).resizable().frame(width: 18, height: 18)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    // ForEach.onMove does not work in a grouped Form on macOS, so rows move themselves
                    // as the drag enters them, like a native list.
                    .onDrag {
                        drag.source = source
                        return NSItemProvider(object: source.rawValue as NSString)
                    }
                    .onDrop(of: [.text], delegate: RowDropDelegate(target: source, drag: drag, settings: settings, onChange: onChange))
                }
            } header: {
                Text("Apps")
            } footer: {
                Text("Drag apps to change their order. Results show apps in this order.")
                    .foregroundStyle(.secondary)
            }
            Section {
                Stepper(value: $settings.limit, in: 1...500) {
                    HStack {
                        Text("Entries per app")
                        Spacer()
                        TextField("", value: $settings.limit, format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 50)
                    }
                }
                .onChange(of: settings.limit) { onChange() }
            } footer: {
                Text("The same limit applies to each app. Search still looks at all entries.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct RowDropDelegate: DropDelegate {
    let target: Source
    let drag: DragState
    let settings: AppSettings
    let onChange: () -> Void

    func dropEntered(info: DropInfo) {
        guard let dragging = drag.source, dragging != target,
              let from = settings.order.firstIndex(of: dragging),
              let to = settings.order.firstIndex(of: target) else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            // The destination offset counts the moved row, so moving down lands after the target row.
            settings.move(fromOffsets: [from], toOffset: from < to ? to + 1 : to)
        }
        onChange()
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        drag.source = nil
        return true
    }
}

private final class DragState {
    var source: Source?
}
