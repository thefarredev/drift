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
                Picker("Bury my screen when I'm away", selection: $settings.awayMinutes) {
                    Text("Never").tag(0)
                    Text("After 2 min").tag(2)
                    Text("After 5 min").tag(5)
                    Text("After 10 min").tag(10)
                    Text("After 20 min").tag(20)
                }
                Picker("Frost my screen when I'm away", selection: $settings.frostMinutes) {
                    Text("Never").tag(0)
                    Text("After 1 min").tag(1)
                    Text("After 3 min").tag(3)
                    Text("After 5 min").tag(5)
                    Text("After 10 min").tag(10)
                }
                Text("Snow workers clear your windows, a plough clears the Dock, and snowmen pop up in deep snow. While you're away the screen slowly fills with snow, and the crew digs you out when you're back. Frost only forms when it's snowing or cold outside, and melts when you're back; your pointer melts it faster. Both are skipped while a video is playing.")
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
