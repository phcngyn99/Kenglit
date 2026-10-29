import AppKit
import Combine
import KenglishCore

@MainActor
final class AppFocusMonitor: ObservableObject {
    @Published var lastWarning: String?

    private let preferences: PreferencesStore
    private let switcher: InputSourceSwitching
    private var observer: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var debounceWork: DispatchWorkItem?

    init(preferences: PreferencesStore, switcher: InputSourceSwitching) {
        self.preferences = preferences
        self.switcher = switcher
    }

    func start() {
        stop()
        let center = NSWorkspace.shared.notificationCenter
        observer = center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.scheduleEvaluate() }
        }
        wakeObserver = center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.scheduleEvaluate() }
        }
        scheduleEvaluate()
    }

    func stop() {
        debounceWork?.cancel()
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
        observer = nil
        wakeObserver = nil
    }

    func scheduleEvaluate() {
        debounceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in self?.evaluateNow() }
        }
        debounceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(80), execute: work)
    }

    func evaluateNow() {
        guard preferences.isEnabled else { return }
        let frontID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let watched = Set(preferences.watchedBundleIDs)
        let currentID = switcher.currentSourceID()
        let isEN = switcher.isEnglish(currentID)
        let decision = FocusPolicy.decide(
            isEnabled: preferences.isEnabled,
            frontBundleID: frontID,
            watched: watched,
            currentIsEnglish: isEN
        )
        guard decision.shouldSwitchToEnglish else { return }
        if !switcher.englishSourceAvailable() {
            lastWarning = "No English keyboard found"
            return
        }
        lastWarning = nil
        _ = switcher.selectEnglish()
    }
}
