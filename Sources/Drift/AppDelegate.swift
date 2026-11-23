import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = AppSettings.shared
    private let overlay = OverlayController()
    private let weatherService = WeatherService()

    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    /// Last forecast we got, shown at the top of the menu.
    private var live: LiveWeather?
    private var lastError: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "snowflake", accessibilityDescription: "Drift")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        overlay.start()
        bindSettings()

        // Re-check the forecast every 30 minutes (MET Norway updates roughly hourly).
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { [weak self] _ in
            self?.refreshWeather()
        }
    }

    // MARK: - Settings → overlay

    private func bindSettings() {
        settings.$intensity.sink { [weak self] in self?.overlay.intensity = $0 }.store(in: &cancellables)
        settings.$paused.sink { [weak self] paused in
            self?.overlay.paused = paused
            self?.statusItem.button?.appearsDisabled = paused
        }.store(in: &cancellables)
        settings.$settleOnWindows.sink { [weak self] in self?.overlay.settle = $0 }.store(in: &cancellables)
        settings.$moments.sink { [weak self] in self?.overlay.moments = $0 }.store(in: &cancellables)
        settings.$awayMinutes.sink { [weak self] in self?.overlay.awayMinutes = $0 }.store(in: &cancellables)
        settings.$frostMinutes.sink { [weak self] in self?.overlay.frostMinutes = $0 }.store(in: &cancellables)
        settings.$source.sink { [weak self] source in
            // @Published fires before the value is stored, so act on the new value directly.
            self?.applySource(source)
        }.store(in: &cancellables)
        settings.$city
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in self?.refreshWeather() }
            .store(in: &cancellables)
    }

    private func applySource(_ source: SceneSource) {
        switch source {
        case .snow: overlay.weather = .snow; overlay.wind = -8
        case .rain: overlay.weather = .rain; overlay.wind = -8
        case .clear: overlay.weather = .clear
        case .live:
            if let live { overlay.weather = live.scene; overlay.wind = CGFloat(live.wind) }
            DispatchQueue.main.async { self.refreshWeather() }
        }
    }

    private func apply(_ weather: LiveWeather) {
        guard settings.source == .live else { return }
        overlay.weather = weather.scene
        overlay.wind = CGFloat(weather.wind)
        overlay.temperature = weather.temperature
    }

    private func refreshWeather() {
        guard settings.source == .live else { return }
        let city = settings.city.trimmingCharacters(in: .whitespaces)
        guard !city.isEmpty else {
            lastError = "Set your city in Settings."
            return
        }
        Task { @MainActor in
            do {
                let weather = try await weatherService.fetch(city: city)
                self.live = weather
                self.lastError = nil
                self.apply(weather)
            } catch {
                self.lastError = error.localizedDescription
            }
        }
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if settings.source == .live {
            let line: String
            if let live {
                line = "\(live.place) · \(live.scene.title), \(Int(live.temperature.rounded()))°"
            } else {
                line = lastError ?? "Checking the weather…"
            }
            let info = NSMenuItem(title: line, action: nil, keyEquivalent: "")
            info.isEnabled = false
            menu.addItem(info)
            menu.addItem(.separator())
        }

        for source in SceneSource.allCases {
            let item = NSMenuItem(title: source.title, action: #selector(pickSource(_:)), keyEquivalent: "")
            item.representedObject = source.rawValue
            item.state = settings.source == source ? .on : .off
            item.target = self
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let intensityHeader = NSMenuItem(title: "Intensity", action: nil, keyEquivalent: "")
        intensityHeader.isEnabled = false
        menu.addItem(intensityHeader)
        for level in Intensity.allCases {
            let item = NSMenuItem(title: level.title, action: #selector(pickIntensity(_:)), keyEquivalent: "")
            item.representedObject = level.rawValue
            item.state = settings.intensity == level ? .on : .off
            item.indentationLevel = 1
            item.target = self
            menu.addItem(item)
        }

        menu.addItem(.separator())
        addItem(to: menu, "Snow settles on windows", #selector(toggleSettle), state: settings.settleOnWindows)
        addItem(to: menu, "Sweep away the snow", #selector(sweep))

        let fun = NSMenuItem(title: "Funny moments", action: nil, keyEquivalent: "")
        let funMenu = NSMenu()
        addItem(to: funMenu, "Send the snow crew", #selector(sendCrew))
        addItem(to: funMenu, "Call the snow plough", #selector(sendPlough))
        addItem(to: funMenu, "Build a snowman", #selector(buildSnowman))
        addItem(to: funMenu, "Bury my screen (demo)", #selector(demoBury))
        addItem(to: funMenu, "Frost my screen (demo)", #selector(demoFrost))
        funMenu.addItem(.separator())
        for level in MomentFrequency.allCases {
            let item = NSMenuItem(title: "Happen on their own: \(level.title)", action: #selector(pickMoments(_:)), keyEquivalent: "")
            item.representedObject = level.rawValue
            item.state = settings.moments == level ? .on : .off
            item.target = self
            funMenu.addItem(item)
        }
        fun.submenu = funMenu
        menu.addItem(fun)
        addItem(to: menu, settings.paused ? "Resume" : "Pause", #selector(togglePause))
        menu.addItem(.separator())
        addItem(to: menu, "Settings…", #selector(openSettings), key: ",")
        addItem(to: menu, "Quit Drift", #selector(quit), key: "q")
    }

    private func addItem(to menu: NSMenu, _ title: String, _ action: Selector, key: String = "", state: Bool? = nil) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        if let state { item.state = state ? .on : .off }
        menu.addItem(item)
    }

    @objc private func pickSource(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let source = SceneSource(rawValue: raw) else { return }
        settings.source = source
        if source == .live, settings.city.isEmpty { openSettings() }
    }

    @objc private func pickIntensity(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let level = Intensity(rawValue: raw) else { return }
        settings.intensity = level
    }

    @objc private func toggleSettle() { settings.settleOnWindows.toggle() }
    @objc private func sweep() { overlay.clearSnow() }
    @objc private func sendCrew() { overlay.sendCrew() }
    @objc private func sendPlough() { overlay.sendPlough() }
    @objc private func buildSnowman() { overlay.buildSnowman() }
    @objc private func demoBury() { overlay.demoBury() }
    @objc private func demoFrost() { overlay.demoFrost() }
    @objc private func pickMoments(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let level = MomentFrequency(rawValue: raw) else { return }
        settings.moments = level
    }
    @objc private func togglePause() { settings.paused.toggle() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(settings: settings)))
            window.title = "Drift Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
