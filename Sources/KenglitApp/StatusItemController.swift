import AppKit
import QuartzCore
import Combine
import KenglitCore

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let model: AppModel
    private var statusItem: NSStatusItem!
    private var cancellables = Set<AnyCancellable>()
    private var settingsWindow: NSWindow?
    private var lastEnabled: Bool?

    init(model: AppModel) {
        self.model = model
        super.init()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
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
        // Off state: slightly dim the whole button for instant readability
        button.alphaValue = enabled ? 1.0 : 0.55
        button.contentTintColor = nil
    }

    private func updateTooltip(enabled: Bool) {
        statusItem.button?.toolTip = enabled ? "Kenglit ON" : "Kenglit OFF"
    }

    private func pulseButton(emphasizeOn: Bool) {
        guard let button = statusItem.button else { return }
        button.wantsLayer = true
        guard let layer = button.layer else { return }

        // Brief scale bounce
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.82
        scale.toValue = 1.0
        scale.duration = 0.28
        scale.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(scale, forKey: "kenglit.scale")

        // Opacity flash
        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = emphasizeOn ? 0.35 : 0.2
        opacity.toValue = emphasizeOn ? 1.0 : 0.55
        opacity.duration = 0.28
        opacity.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(opacity, forKey: "kenglit.opacity")

        // Teal “live” ping only when turning On (drawn as temporary green tint via filter-less second pulse)
        if emphasizeOn {
            let glow = CABasicAnimation(keyPath: "opacity")
            glow.beginTime = CACurrentMediaTime()
            glow.fromValue = 1.0
            glow.toValue = 1.0
            glow.duration = 0.01
            // Use shadow pulse if available
            layer.shadowColor = NSColor.systemTeal.cgColor
            layer.shadowOpacity = 0.0
            layer.shadowRadius = 6
            layer.shadowOffset = .zero
            let shadow = CABasicAnimation(keyPath: "shadowOpacity")
            shadow.fromValue = 0.85
            shadow.toValue = 0.0
            shadow.duration = 0.45
            shadow.timingFunction = CAMediaTimingFunction(name: .easeOut)
            layer.add(shadow, forKey: "kenglit.shadow")
        }
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.delegate = self
        let enabled = model.preferences.isEnabled

        let enabledItem = NSMenuItem(
            title: enabled ? "ON" : "OFF",
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
        // Icon animation comes from $isEnabled sink; menu rebuild for labels
        rebuildMenu()
    }



    @objc private func openSettings() {
        if let existing = settingsWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let controller = SettingsWindowController(preferences: model.preferences)
        settingsWindow = controller.window
        controller.window?.delegate = self
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

extension StatusItemController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        settingsWindow = nil
    }
}

/// Menu-bar template glyphs drawn at runtime (crisp On/Off states).
enum MenuBarIcon {
    static func make(enabled: Bool, size: CGFloat = 18) -> NSImage {
        let final = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let inset = size * 0.10
            let box = rect.insetBy(dx: inset, dy: inset)
            let radius = size * 0.22
            let border = NSBezierPath(roundedRect: box, xRadius: radius, yRadius: radius)

            if enabled {
                // ON: solid tile + white K + teal live pip
                NSColor(calibratedWhite: 0.12, alpha: 1).setFill()
                border.fill()
                drawK(in: box, color: .white, fontSize: size * 0.62)

                let pipR = size * 0.09
                let pip = NSRect(
                    x: box.maxX - pipR * 1.6,
                    y: box.minY + pipR * 0.35,
                    width: pipR * 1.5,
                    height: pipR * 1.5
                )
                NSColor(calibratedRed: 0.18, green: 0.78, blue: 0.60, alpha: 1).setFill()
                NSBezierPath(ovalIn: pip).fill()
            } else {
                // OFF: outline + muted K + slash
                NSColor.labelColor.withAlphaComponent(0.85).setStroke()
                border.lineWidth = max(size * 0.09, 1.1)
                border.stroke()
                drawK(in: box, color: NSColor.labelColor.withAlphaComponent(0.55), fontSize: size * 0.58)

                let slash = NSBezierPath()
                slash.move(to: NSPoint(x: box.minX + box.width * 0.18, y: box.minY + box.height * 0.22))
                slash.line(to: NSPoint(x: box.maxX - box.width * 0.18, y: box.maxY - box.height * 0.22))
                slash.lineWidth = max(size * 0.11, 1.3)
                slash.lineCapStyle = .round
                NSColor.labelColor.withAlphaComponent(0.7).setStroke()
                slash.stroke()
            }
            return true
        }
        final.isTemplate = false
        final.size = NSSize(width: size, height: size)
        return final
    }

    private static func drawK(in box: NSRect, color: NSColor, fontSize: CGFloat) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ]
        let text = NSString(string: "K")
        let size = text.size(withAttributes: attrs)
        let origin = NSPoint(
            x: box.midX - size.width / 2,
            y: box.midY - size.height / 2 - box.height * 0.04
        )
        text.draw(at: origin, withAttributes: attrs)
    }
}
