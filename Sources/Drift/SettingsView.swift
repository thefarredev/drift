import AppKit
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
            Section("Wallpaper") {
                Toggle("Change my wallpaper with the weather", isOn: $settings.wallpaperEnabled)
                Picker("Show a new image every", selection: $settings.rotateMinutes) {
                    Text("15 minutes").tag(15)
                    Text("30 minutes").tag(30)
                    Text("Hour").tag(60)
                    Text("3 hours").tag(180)
                    Text("Only when the weather changes").tag(0)
                }
                HStack {
                    Text(settings.wallpaperFolder.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Choose…") { chooseFolder() }
                    Button("Open") { NSWorkspace.shared.open(settings.wallpaperFolder) }
                }
                Text("Name images like snow_night_01.jpg, rain_day_02.jpg, fog_01.jpg or holiday_christmas_01.jpg. Times are morning, day, dusk and night. Until you add images, Drift paints simple placeholder skies. Your own wallpaper comes back when you pause, turn this off or quit.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Holidays") {
                ForEach(Holiday.allCases) { holiday in
                    Toggle(holiday.title, isOn: Binding(
                        get: { !settings.disabledHolidays.contains(holiday.rawValue) },
                        set: { on in
                            if on { settings.disabledHolidays.remove(holiday.rawValue) }
                            else { settings.disabledHolidays.insert(holiday.rawValue) }
                        }))
                }
                Text("On these days Drift uses holiday_<name> images, like holiday_christmas_01.jpg or holiday_bajram_01.jpg.")
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
                Toggle("Snow settles on widgets and desktop files", isOn: $settings.settleOnDesktop)
                    .disabled(!settings.settleOnWindows)
                Text("Effects calm down automatically in Low Power Mode or with Reduce Motion on.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 640)
        .padding(.vertical, 8)
        .onAppear { cityDraft = settings.city }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = settings.wallpaperFolder
        panel.prompt = "Use this folder"
        if panel.runModal() == .OK, let url = panel.url { settings.wallpaperFolder = url }
    }
}
