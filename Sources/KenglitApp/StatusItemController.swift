import AppKit
import QuartzCore
import Combine
import KenglitCore

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let model: AppModel
    private var statusItem: NSStatusItem!
    private var cancellables = Set<AnyCancellable>()
    private var settingsController: SettingsWindowController?
    private var lastEnabled: Bool?

    init(model: AppModel) {
        self.model = model
        super.init()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            button.toolTip = "Kenglit"
            button.wantsLayer = true
        }

        rebuildMenu()

        model.preferences.$isEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                self?.applyEnabled(enabled, animated: true)
            }
            .store(in: &cancellables)

        model.preferences.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)

        model.monitor.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)

        applyEnabled(model.preferences.isEnabled, animated: false)
    }

    private func applyEnabled(_ enabled: Bool, animated: Bool) {
        let changed = lastEnabled.map { $0 != enabled } ?? true
        lastEnabled = enabled
        updateIcon(enabled: enabled)
        updateTooltip(enabled: enabled)
        if animated, changed {
            pulseButton(emphasizeOn: enabled)
        }
    }

    private func updateIcon(enabled: Bool) {
        guard let button = statusItem.button else { return }
        let image = MenuBarIcon.make(enabled: enabled)
        button.image = image
        button.appearsDisabled = false
        button.alphaValue = enabled ? 1.0 : 0.45
    }

    private func updateTooltip(enabled: Bool) {
        statusItem.button?.toolTip = enabled ? "Kenglit · On" : "Kenglit · Off"
    }

    private func pulseButton(emphasizeOn: Bool) {
        guard let button = statusItem.button else { return }
        button.wantsLayer = true
        guard let layer = button.layer else { return }

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.82
        scale.toValue = 1.0
        scale.duration = 0.28
        scale.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(scale, forKey: "kenglit.scale")

        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = emphasizeOn ? 0.35 : 0.2
        opacity.toValue = emphasizeOn ? 1.0 : 0.45
        opacity.duration = 0.28
        opacity.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(opacity, forKey: "kenglit.opacity")
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.delegate = self
        let enabled = model.preferences.isEnabled

        let enabledItem = NSMenuItem(
            title: enabled ? "On" : "Off",
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        enabledItem.target = self
        enabledItem.image = MenuBarIcon.make(enabled: enabled, size: 14)
        menu.addItem(enabledItem)

        if let warning = model.monitor.lastWarning {
            let w = NSMenuItem(title: warning, action: nil, keyEquivalent: "")
            w.isEnabled = false
            menu.addItem(w)
        }

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let quit = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
        updateIcon(enabled: enabled)
        updateTooltip(enabled: enabled)
    }

    @objc private func toggleEnabled() {
        model.preferences.isEnabled.toggle()
        if model.preferences.isEnabled {
            model.monitor.start()
        } else {
            model.monitor.stop()
        }
        rebuildMenu()
    }

    @objc func openSettings() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if settingsController == nil {
            settingsController = SettingsWindowController(preferences: model.preferences)
        }
        settingsController?.showWindow(nil)
        settingsController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        settingsController?.onClose = { [weak self] in
            NSApp.setActivationPolicy(.accessory)
            self?.settingsController = nil
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

enum MenuBarIcon {
    static func make(enabled: Bool, size: CGFloat = 18) -> NSImage {
        if let template = loadTemplate() {
            let image = NSImage(size: NSSize(width: size, height: size))
            image.lockFocus()
            NSGraphicsContext.current?.imageInterpolation = .high
            template.draw(
                in: NSRect(x: 0, y: 0, width: size, height: size),
                from: .zero,
                operation: .sourceOver,
                fraction: 1.0,
                respectFlipped: true,
                hints: [.interpolation: NSImageInterpolation.high]
            )
            if !enabled {
                NSColor.black.setStroke()
                let inset = size * 0.18
                let slash = NSBezierPath()
                slash.move(to: NSPoint(x: inset, y: inset))
                slash.line(to: NSPoint(x: size - inset, y: size - inset))
                slash.lineWidth = max(size * 0.11, 1.2)
                slash.lineCapStyle = .round
                slash.stroke()
            }
            image.unlockFocus()
            image.isTemplate = true
            image.size = NSSize(width: size, height: size)
            return image
        }
        return fallback(enabled: enabled, size: size)
    }

    private static func loadTemplate() -> NSImage? {
        if let named = NSImage(named: "kenglitTemplate") {
            named.isTemplate = true
            return named
        }
        let bundle = Bundle.main
        if let url = bundle.url(forResource: "kenglitTemplate", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.isTemplate = true
            return image
        }
        return nil
    }

    private static func fallback(enabled: Bool, size: CGFloat) -> NSImage {
        let final = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let inset = size * 0.08
            let box = rect.insetBy(dx: inset, dy: inset)
            let radius = size * 0.20
            let border = NSBezierPath(roundedRect: box, xRadius: radius, yRadius: radius)
            NSColor.black.setStroke()
            NSColor.black.setFill()
            border.lineWidth = max(size * 0.10, 1.15)
            border.stroke()

            let stemW = size * 0.09
            let stemH = size * 0.47
            let stem = NSRect(
                x: box.minX + box.width * 0.28,
                y: box.midY - stemH / 2,
                width: stemW,
                height: stemH
            )
            NSBezierPath(roundedRect: stem, xRadius: stemW * 0.2, yRadius: stemW * 0.2).fill()

            let arm = NSBezierPath()
            let ax = stem.maxX + size * 0.02
            let midY = box.midY
            arm.move(to: NSPoint(x: ax, y: midY))
            arm.line(to: NSPoint(x: box.maxX - box.width * 0.18, y: box.maxY - box.height * 0.18))
            arm.move(to: NSPoint(x: ax, y: midY))
            arm.line(to: NSPoint(x: box.maxX - box.width * 0.18, y: box.minY + box.height * 0.18))
            arm.lineWidth = max(size * 0.10, 1.2)
            arm.lineCapStyle = .round
            arm.lineJoinStyle = .round
            arm.stroke()

            if !enabled {
                let slash = NSBezierPath()
                slash.move(to: NSPoint(x: box.minX + box.width * 0.16, y: box.minY + box.height * 0.18))
                slash.line(to: NSPoint(x: box.maxX - box.width * 0.16, y: box.maxY - box.height * 0.18))
                slash.lineWidth = max(size * 0.11, 1.3)
                slash.lineCapStyle = .round
                slash.stroke()
            }
            return true
        }
        final.isTemplate = true
        final.size = NSSize(width: size, height: size)
        return final
    }
}
