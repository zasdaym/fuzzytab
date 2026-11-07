import FuzzyTabCore
import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let onChange: () -> Void

    var body: some View {
        Form {
            Section("Apps") {
                ForEach(Source.allCases, id: \.self) { source in
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
