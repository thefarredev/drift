import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var cityDraft = ""

    var body: some View {
        Form {
            Section("Weather") {
                Picker("Scene", selection: $settings.source) {
                    ForEach(SceneSource.allCases) { Text($0.title).tag($0) }
                }
                HStack {
                    TextField("City", text: $cityDraft, prompt: Text("e.g. Sarajevo"))
                        .onSubmit { settings.city = cityDraft }
                    Button("Save") { settings.city = cityDraft }
                        .disabled(cityDraft == settings.city)
                }
                Text("Your city is turned into rough coordinates and sent to MET Norway for the forecast. Window positions never leave your Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Funny moments") {
                Picker("Happen on their own", selection: $settings.moments) {
                    ForEach(MomentFrequency.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Text("Snow workers clear your windows, a plough clears the Dock, and snowmen slowly grow in snow nobody clears. Move your pointer through the snow to push it around or knock a snowman over.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Effect") {
                Picker("Intensity", selection: $settings.intensity) {
                    ForEach(Intensity.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Toggle("Snow settles on windows and the Dock", isOn: $settings.settleOnWindows)
                Text("Effects calm down automatically in Low Power Mode or with Reduce Motion on.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .padding(.vertical, 8)
        .onAppear { cityDraft = settings.city }
    }
}
