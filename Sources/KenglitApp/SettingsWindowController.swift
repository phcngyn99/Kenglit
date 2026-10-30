import AppKit
import QuartzCore
import UniformTypeIdentifiers
import KenglitCore

private enum SettingsUI {
    static let margin: CGFloat = 16
    static let sectionGap: CGFloat = 12
    static let rowH: CGFloat = 34
    static let headerH: CGFloat = 24
    static let icon: CGFloat = 24
    static let iconPad: CGFloat = 10
    static let trailing: CGFloat = 10
    static let controlH: CGFloat = 24
    static let windowW: CGFloat = 440
    static let windowH: CGFloat = 480
    static let minW: CGFloat = 380
    static let minH: CGFloat = 360
}

@MainActor
final class SettingsWindowController: NSWindowController {
    private let preferences: PreferencesStore
    private var enabledSwitch: NSSwitch!
    private var loginSwitch: NSSwitch!
    private var statusLabel: NSTextField!
    private var searchField: NSSearchField!
    private var table: SettingsTableView!
    private var displayRows: [Row] = []
    private var customExpanded = true
    private var builtInExpanded = true
    private var filter = ""
    private var iconCache: [String: NSImage] = [:]
    var onClose: (() -> Void)?

    private enum Section { case custom, builtIn }
    private enum Row {
        case header(Section, title: String, expanded: Bool)
        case app(bundleID: String, removable: Bool)
        case empty(String)
    }

    init(preferences: PreferencesStore) {
        self.preferences = preferences
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: SettingsUI.windowW, height: SettingsUI.windowH),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Kenglit"
        window.minSize = NSSize(width: SettingsUI.minW, height: SettingsUI.minH)
        window.center()
        super.init(window: window)
        window.contentView = buildContent()
        window.delegate = self
        reload()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func buildContent() -> NSView {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: SettingsUI.windowW, height: SettingsUI.windowH))
        let m = SettingsUI.margin

        let generalTitle = sectionLabel("General")
        root.addSubview(generalTitle)

        let (enSw, enRow) = prefRow(
            title: "Enable Kenglit",
            action: #selector(toggleEnabled)
        )
        enabledSwitch = enSw
        root.addSubview(enRow)

        let (loginSw, loginRow) = prefRow(
            title: "Launch at Login",
            action: #selector(toggleLogin)
        )
        loginSwitch = loginSw
        root.addSubview(loginRow)

        statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(statusLabel)

        let aboutBtn = iconButton("info.circle", tip: "About keyboard switching", action: #selector(showAbout))
        root.addSubview(aboutBtn)

        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(divider)

        let appsTitle = sectionLabel("Applications")
        root.addSubview(appsTitle)

        let addBtn = textButton("Enforce [EN] an App", action: #selector(addApplications))
        addBtn.toolTip = "Choose an app that should stay English"
        root.addSubview(addBtn)

        searchField = NSSearchField()
        searchField.placeholderString = "Search"
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.target = self
        searchField.action = #selector(searchChanged)
        searchField.sendsSearchStringImmediately = true
        searchField.delegate = self
        root.addSubview(searchField)

        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .bezelBorder
        scroll.drawsBackground = true
        scroll.backgroundColor = .controlBackgroundColor
        scroll.wantsLayer = true
        scroll.layer?.cornerRadius = 6

        table = SettingsTableView()
        table.headerView = nil
        table.rowHeight = SettingsUI.rowH
        table.allowsMultipleSelection = false
        table.usesAlternatingRowBackgroundColors = false
        table.backgroundColor = .clear
        table.selectionHighlightStyle = .regular
        table.gridStyleMask = []
        table.intercellSpacing = .zero
        if #available(macOS 11.0, *) { table.style = .plain }
        let col = NSTableColumn(identifier: .init("app"))
        col.resizingMask = .autoresizingMask
        col.width = 400
        table.addTableColumn(col)
        table.dataSource = self
        table.delegate = self
        table.onRowMouseDown = { [weak self] row in
            self?.handleTableRowClick(row) ?? false
        }
        scroll.documentView = table
        root.addSubview(scroll)

        let restore = textButton("Restore Default", action: #selector(restoreDefaults))
        restore.toolTip = "Restore the factory application list"
        restore.contentTintColor = .secondaryLabelColor
        root.addSubview(restore)

        NSLayoutConstraint.activate([
            generalTitle.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: m),
            generalTitle.topAnchor.constraint(equalTo: root.topAnchor, constant: m),
            aboutBtn.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -m),
            aboutBtn.centerYAnchor.constraint(equalTo: generalTitle.centerYAnchor),
            aboutBtn.widthAnchor.constraint(equalToConstant: 20),
            aboutBtn.heightAnchor.constraint(equalToConstant: 20),

            enRow.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: m),
            enRow.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -m),
            enRow.topAnchor.constraint(equalTo: generalTitle.bottomAnchor, constant: 8),
            enRow.heightAnchor.constraint(equalToConstant: 28),

            loginRow.leadingAnchor.constraint(equalTo: enRow.leadingAnchor),
            loginRow.trailingAnchor.constraint(equalTo: enRow.trailingAnchor),
            loginRow.topAnchor.constraint(equalTo: enRow.bottomAnchor, constant: 4),
            loginRow.heightAnchor.constraint(equalToConstant: 28),

            statusLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: m),
            statusLabel.topAnchor.constraint(equalTo: loginRow.bottomAnchor, constant: 4),

            divider.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: m),
            divider.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -m),
            divider.topAnchor.constraint(equalTo: loginRow.bottomAnchor, constant: SettingsUI.sectionGap),

            appsTitle.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: m),
            appsTitle.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: SettingsUI.sectionGap),
            addBtn.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -m),
            addBtn.centerYAnchor.constraint(equalTo: appsTitle.centerYAnchor),

            searchField.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: m),
            searchField.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -m),
            searchField.topAnchor.constraint(equalTo: appsTitle.bottomAnchor, constant: 8),

            scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: m),
            scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -m),
            scroll.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            scroll.bottomAnchor.constraint(equalTo: restore.topAnchor, constant: -12),

            restore.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -m),
            restore.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -m),
            restore.heightAnchor.constraint(equalToConstant: SettingsUI.controlH),
        ])
        return root
    }

    private func sectionLabel(_ text: String) -> NSTextField {
        let t = NSTextField(labelWithString: text)
        t.font = .systemFont(ofSize: 13, weight: .semibold)
        t.textColor = .labelColor
        t.translatesAutoresizingMaskIntoConstraints = false
        return t
    }

    private func prefRow(title: String, action: Selector) -> (NSSwitch, NSView) {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let titleL = NSTextField(labelWithString: title)
        titleL.font = .systemFont(ofSize: 13)
        titleL.textColor = .labelColor
        titleL.translatesAutoresizingMaskIntoConstraints = false

        let sw = NSSwitch()
        sw.target = self
        sw.action = action
        sw.controlSize = .regular
        sw.translatesAutoresizingMaskIntoConstraints = false
        sw.setContentHuggingPriority(.required, for: .horizontal)

        row.addSubview(titleL)
        row.addSubview(sw)

        NSLayoutConstraint.activate([
            titleL.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            titleL.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            titleL.trailingAnchor.constraint(lessThanOrEqualTo: sw.leadingAnchor, constant: -12),

            sw.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            sw.centerYAnchor.constraint(equalTo: row.centerYAnchor),
        ])
        return (sw, row)
    }

    private func textButton(_ title: String, action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .inline
        b.isBordered = false
        b.font = .systemFont(ofSize: 12, weight: .medium)
        b.contentTintColor = .controlAccentColor
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setContentHuggingPriority(.required, for: .horizontal)
        return b
    }

    private func iconButton(_ symbol: String, tip: String, action: Selector) -> NSButton {
        let b = NSButton(frame: .zero)
        b.bezelStyle = .inline
        b.isBordered = false
        b.imagePosition = .imageOnly
        if let base = NSImage(systemSymbolName: symbol, accessibilityDescription: tip) {
            b.image = base.withSymbolConfiguration(.init(pointSize: 13, weight: .regular)) ?? base
        }
        b.contentTintColor = .tertiaryLabelColor
        b.target = self
        b.action = action
        b.toolTip = tip
        b.setAccessibilityLabel(tip)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }

    private func reload() {
        enabledSwitch.state = preferences.isEnabled ? .on : .off
        loginSwitch.state = preferences.launchAtLogin ? .on : .off

        let q = filter.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        func match(_ bid: String) -> Bool {
            guard !q.isEmpty else { return true }
            return Self.friendlyName(for: bid).lowercased().contains(q)
                || bid.lowercased().contains(q)
        }

        let custom = preferences.userWatchedBundleIDs.filter(match)
        let builtIn = preferences.activeBuiltInBundleIDs.filter(match)
        var rows: [Row] = []

        rows.append(.header(.custom, title: "User Apps", expanded: customExpanded))
        if customExpanded {
            if custom.isEmpty {
                rows.append(.empty(q.isEmpty ? "No user apps added." : "No matching applications."))
            } else {
                for bid in custom { rows.append(.app(bundleID: bid, removable: true)) }
            }
        }

        rows.append(.header(.builtIn, title: "Built-in Apps", expanded: builtInExpanded))
        if builtInExpanded {
            if builtIn.isEmpty {
                rows.append(.empty(q.isEmpty ? "No built-in apps." : "No matching applications."))
            } else {
                for bid in builtIn { rows.append(.app(bundleID: bid, removable: true)) }
            }
        }

        displayRows = rows
        table.reloadData()
    }

    @objc private func toggleEnabled() {
        preferences.isEnabled = (enabledSwitch.state == .on)
        NotificationCenter.default.post(name: .kenglitPrefsChanged, object: nil)
        statusLabel.stringValue = ""
    }

    @objc private func toggleLogin() {
        let want = loginSwitch.state == .on
        if LaunchAtLogin.setEnabled(want) {
            preferences.launchAtLogin = want
            statusLabel.stringValue = ""
        } else {
            statusLabel.textColor = .systemRed
            statusLabel.stringValue = "Couldn’t update login item"
            loginSwitch.state = preferences.launchAtLogin ? .on : .off
        }
    }

    @objc private func searchChanged() {
        filter = searchField.stringValue
        expandSectionsMatchingSearch()
        reload()
    }

    /// Expand sections that contain the current query so Enter / typing reveals hits.
    private func expandSectionsMatchingSearch() {
        let q = filter.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return }
        func match(_ bid: String) -> Bool {
            Self.friendlyName(for: bid).lowercased().contains(q) || bid.lowercased().contains(q)
        }
        if preferences.userWatchedBundleIDs.contains(where: match) {
            customExpanded = true
        }
        if preferences.activeBuiltInBundleIDs.contains(where: match) {
            builtInExpanded = true
        }
    }

    @objc private func showAbout(_ sender: Any?) {
        let anchor = (sender as? NSView) ?? window?.contentView
        guard let anchor else { return }
        HelpPopover.shared.show(
            relativeTo: anchor.bounds,
            of: anchor,
            text: """
            Kenglit switches the keyboard layout based on the frontmost app.

            User Apps
            Apps you add. Remove with −, or Restore Default to clear the list.

            Built-in Apps
            Terminals, editors, and IDEs included with Kenglit. Remove with − if you prefer.

            Other apps
            Switch to Vietnamese when focus leaves a listed app.
            """
        )
    }

    private func removeConfiguredApp(_ bid: String) {
        preferences.removeWatchedBundleID(bid)
        reload()
        NotificationCenter.default.post(name: .kenglitPrefsChanged, object: nil)
    }

    @objc private func addApplications() {
        let panel = NSOpenPanel()
        panel.title = "Enforce English on App"
        panel.prompt = "Enforce"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.treatsFilePackagesAsDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        if #available(macOS 11.0, *) {
            panel.allowedContentTypes = [.application]
        } else {
            panel.allowedFileTypes = ["app"]
        }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)

        let result = panel.runModal()
        defer {
            window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        guard result == .OK else { return }

        var failed = 0
        for url in panel.urls {
            guard let bid = Self.bundleID(fromAppURL: url), bid != "dev.finn.kenglit" else {
                failed += 1
                continue
            }
            preferences.addWatchedBundleID(bid)
            let name = FileManager.default.displayName(atPath: url.path)
                .replacingOccurrences(of: ".app", with: "")
            if !name.isEmpty { WatchedAppsUserNames.set(name, for: bid) }
        }
        reload()
        NotificationCenter.default.post(name: .kenglitPrefsChanged, object: nil)
        if failed > 0 {
            statusLabel.textColor = .systemRed
            statusLabel.stringValue = "Couldn’t read application"
        } else {
            statusLabel.stringValue = ""
        }
    }

    @objc private func restoreDefaults() {
        let alert = NSAlert()
        alert.messageText = "Restore default application list?"
        alert.informativeText = "This restores built-in applications and removes custom entries."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Restore Default")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        preferences.restoreDefaultApplications()
        filter = ""
        searchField.stringValue = ""
        customExpanded = true
        builtInExpanded = true
        reload()
        NotificationCenter.default.post(name: .kenglitPrefsChanged, object: nil)
        statusLabel.stringValue = ""
    }

    private func toggleSection(_ section: Section) {
        switch section {
        case .custom: customExpanded.toggle()
        case .builtIn: builtInExpanded.toggle()
        }
        reload()
    }

    private func sectionOwning(row: Int) -> Section? {
        var i = row
        while i >= 0 {
            if case let .header(section, _, _) = displayRows[i] {
                return section
            }
            i -= 1
        }
        return nil
    }


    private static func bundleID(fromAppURL url: URL) -> String? {
        let infoURL = url.appendingPathComponent("Contents/Info.plist")
        if let dict = NSDictionary(contentsOf: infoURL) as? [String: Any],
           let bid = dict["CFBundleIdentifier"] as? String, !bid.isEmpty {
            return bid
        }
        return Bundle(url: url)?.bundleIdentifier
    }

    private static func friendlyName(for bundleID: String) -> String {
        let mapped = WatchedAppsUserNames.displayName(for: bundleID)
        if mapped != bundleID { return mapped }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let info = url.appendingPathComponent("Contents/Info.plist")
            if let dict = NSDictionary(contentsOf: info) as? [String: Any] {
                if let n = dict["CFBundleDisplayName"] as? String, !n.isEmpty {
                    WatchedAppsUserNames.set(n, for: bundleID); return n
                }
                if let n = dict["CFBundleName"] as? String, !n.isEmpty {
                    WatchedAppsUserNames.set(n, for: bundleID); return n
                }
            }
            return url.deletingPathExtension().lastPathComponent
        }
        return bundleID
    }

    private func cachedIcon(for bid: String) -> NSImage {
        if let hit = iconCache[bid] { return hit }
        let img = Self.renderIcon(for: bid)
        iconCache[bid] = img
        return img
    }

    private static func renderIcon(for bundleID: String) -> NSImage {
        let point = NSSize(width: SettingsUI.icon, height: SettingsUI.icon)

        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
           FileManager.default.fileExists(atPath: url.path) {
            let source = NSWorkspace.shared.icon(forFile: url.path)
            let rendered = rasterize(source, to: point)
            // Real apps have rich icons; blank-ish placeholders fail the variance check.
            if iconLooksReal(rendered) {
                return rendered
            }
        }

        return genericAppIcon(size: point)
    }

    /// True when icon has enough non-flat content to look like a real app mark.
    private static func iconLooksReal(_ image: NSImage) -> Bool {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.bitmapData else { return false }
        let w = rep.pixelsWide
        let h = rep.pixelsHigh
        guard w > 0, h > 0 else { return false }
        let spp = max(rep.samplesPerPixel, 1)
        var opaque = 0
        var samples: [UInt8] = []
        samples.reserveCapacity(64)
        let stepX = max(w / 8, 1)
        let stepY = max(h / 8, 1)
        for y in stride(from: 0, to: h, by: stepY) {
            for x in stride(from: 0, to: w, by: stepX) {
                let i = (y * rep.bytesPerRow) + (x * spp)
                let a = spp >= 4 ? Int(data[i + 3]) : 255
                if a < 24 { continue }
                opaque += 1
                samples.append(data[i]) // R approx
            }
        }
        guard opaque >= 6, samples.count >= 4 else { return false }
        let minV = samples.min() ?? 0
        let maxV = samples.max() ?? 0
        // Flat gray workspace placeholders usually have almost no variance.
        return Int(maxV) - Int(minV) >= 18
    }

    /// Distinct generic application mark — never an empty/black/gray square.
    private static func genericAppIcon(size point: NSSize) -> NSImage {
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let pxW = max(Int(point.width * scale), 1)
        let pxH = max(Int(point.height * scale), 1)
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pxW,
            pixelsHigh: pxH,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        rep.size = point
        NSGraphicsContext.saveGraphicsState()
        if let ctx = NSGraphicsContext(bitmapImageRep: rep) {
            NSGraphicsContext.current = ctx
            ctx.cgContext.scaleBy(x: scale, y: scale)
            ctx.imageInterpolation = .high

            let bounds = NSRect(origin: .zero, size: point)
            NSColor.clear.setFill()
            bounds.fill()

            // Transparent canvas + monochrome SF Symbol only (no plate square).
            if let base = NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil)
                ?? NSImage(systemSymbolName: "app", accessibilityDescription: nil)
                ?? NSImage(systemSymbolName: "app.fill", accessibilityDescription: nil) {
                let conf = NSImage.SymbolConfiguration(pointSize: point.width * 0.78, weight: .regular)
                    .applying(NSImage.SymbolConfiguration(paletteColors: [.tertiaryLabelColor]))
                let glyph = base.withSymbolConfiguration(conf) ?? base
                glyph.isTemplate = false
                let gSize = NSSize(width: point.width * 0.86, height: point.height * 0.86)
                let gRect = NSRect(
                    x: (point.width - gSize.width) / 2,
                    y: (point.height - gSize.height) / 2,
                    width: gSize.width,
                    height: gSize.height
                )
                glyph.draw(
                    in: gRect,
                    from: .zero,
                    operation: .sourceOver,
                    fraction: 1,
                    respectFlipped: false,
                    hints: [.interpolation: NSNumber(value: NSImageInterpolation.high.rawValue)]
                )
            }
        }
        NSGraphicsContext.restoreGraphicsState()
        let out = NSImage(size: point)
        out.addRepresentation(rep)
        out.isTemplate = false
        return out
    }

    private static func rasterize(_ source: NSImage, to point: NSSize) -> NSImage {
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(point.width * scale),
            pixelsHigh: Int(point.height * scale),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        rep.size = point
        NSGraphicsContext.saveGraphicsState()
        if let ctx = NSGraphicsContext(bitmapImageRep: rep) {
            NSGraphicsContext.current = ctx
            // Clear to transparent first
            NSColor.clear.setFill()
            NSRect(origin: .zero, size: point).fill()
            source.draw(
                in: NSRect(origin: .zero, size: point),
                from: .zero,
                operation: .sourceOver,
                fraction: 1,
                respectFlipped: false,
                hints: [.interpolation: NSNumber(value: NSImageInterpolation.high.rawValue)]
            )
        }
        NSGraphicsContext.restoreGraphicsState()
        let out = NSImage(size: point)
        out.addRepresentation(rep)
        out.isTemplate = false
        return out
    }
}

extension SettingsWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        onClose?(); onClose = nil
    }
}

extension SettingsWindowController: NSSearchFieldDelegate {
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            filter = searchField.stringValue
            expandSectionsMatchingSearch()
            reload()
            return true
        }
        return false
    }
}

extension SettingsWindowController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int { displayRows.count }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard row >= 0, row < displayRows.count else { return SettingsUI.rowH }
        switch displayRows[row] {
        case .header, .empty: return SettingsUI.headerH
        case .app: return SettingsUI.rowH
        }
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        guard row >= 0, row < displayRows.count else { return false }
        if case .app = displayRows[row] { return true }
        return false
    }

    /// Returns true when the click was a section chrome row (handled).
    fileprivate func handleTableRowClick(_ row: Int) -> Bool {
        guard row >= 0, row < displayRows.count else { return false }
        switch displayRows[row] {
        case let .header(section, _, _):
            toggleSection(section)
            return true
        case .empty:
            if let section = sectionOwning(row: row) {
                toggleSection(section)
                return true
            }
            return false
        case .app:
            return false
        }
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0, row < displayRows.count else { return nil }
        switch displayRows[row] {
        case let .header(section, title, expanded):
            let id = NSUserInterfaceItemIdentifier("hdr")
            let cell = (tableView.makeView(withIdentifier: id, owner: nil) as? SectionHeaderCell)
                ?? SectionHeaderCell(frame: .zero)
            cell.identifier = id
            cell.configure(title: title, expanded: expanded) { [weak self] in
                self?.toggleSection(section)
            }
            return cell
        case let .empty(msg):
            let id = NSUserInterfaceItemIdentifier("empty")
            let cell = (tableView.makeView(withIdentifier: id, owner: nil) as? EmptyHintCell)
                ?? EmptyHintCell(frame: .zero)
            cell.identifier = id
            let section = sectionOwning(row: row)
            cell.configure(msg) { [weak self] in
                guard let self, let section else { return }
                // Collapse only when currently expanded (empty row only exists when expanded).
                self.toggleSection(section)
            }
            return cell
        case let .app(bid, _):
            let id = NSUserInterfaceItemIdentifier("app")
            let cell = (tableView.makeView(withIdentifier: id, owner: nil) as? AppRowCell)
                ?? AppRowCell(frame: .zero)
            cell.identifier = id
            let appName = Self.friendlyName(for: bid)
            cell.configure(
                icon: cachedIcon(for: bid),
                name: appName,
                toolTip: bid,
                removable: true,
                removeTip: "Remove \(appName) from Kenglit",
                onRemove: { [weak self] in self?.removeConfiguredApp(bid) }
            )
            return cell
        }
    }
}

/// Forwards header/empty clicks; app rows use normal NSTableView handling.
final class SettingsTableView: NSTableView {
    /// Return true if the click was fully handled (skip super.mouseDown).
    var onRowMouseDown: ((Int) -> Bool)?

    override func mouseDown(with event: NSEvent) {
        let local = convert(event.locationInWindow, from: nil)
        let row = self.row(at: local)
        if row >= 0, onRowMouseDown?(row) == true {
            // Header/empty handled — skip super so reload mid-click can't bounce.
            return
        }
        super.mouseDown(with: event)
    }
}

final class SectionHeaderCell: NSView {
    private let chevron = NSImageView(frame: .zero)
    private let title = NSTextField(labelWithString: "")
    private var onToggle: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        chevron.contentTintColor = .secondaryLabelColor
        addSubview(chevron)
        title.font = .systemFont(ofSize: 11, weight: .semibold)
        title.textColor = .secondaryLabelColor
        title.lineBreakMode = .byTruncatingTail
        title.isEditable = false
        title.isSelectable = false
        title.isEnabled = false
        title.refusesFirstResponder = true
        addSubview(title)
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
    func configure(title text: String, expanded: Bool, onToggle: @escaping () -> Void) {
        self.onToggle = onToggle
        title.stringValue = text
        let sym = expanded ? "chevron.down" : "chevron.right"
        if let b = NSImage(systemSymbolName: sym, accessibilityDescription: "Toggle") {
            chevron.image = b.withSymbolConfiguration(.init(pointSize: 9, weight: .bold)) ?? b
        }
        setAccessibilityLabel(text)
        setAccessibilityRole(.button)
        needsLayout = true
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    /// Claim full-row hits so label/chevron never steal collapse clicks.
    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }
    override func mouseDown(with event: NSEvent) {
        // Collapse/expand is handled in tableView(_:shouldSelectRow:).
    }
    override func layout() {
        super.layout()
        let h = max(bounds.height, SettingsUI.headerH)
        let w = max(bounds.width, 120)
        let c: CGFloat = 11
        chevron.frame = NSRect(x: 8, y: floor((h - c) / 2), width: c, height: c)
        title.frame = NSRect(x: 8 + c + 6, y: floor((h - 14) / 2), width: max(w - 40, 40), height: 14)
    }
}

final class EmptyHintCell: NSView {
    private let label = NSTextField(labelWithString: "")
    private var onCollapse: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        label.font = .systemFont(ofSize: 11)
        label.textColor = .tertiaryLabelColor
        label.lineBreakMode = .byTruncatingTail
        label.isEditable = false
        label.isSelectable = false
        label.isEnabled = false
        label.refusesFirstResponder = true
        addSubview(label)
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
    func configure(_ text: String, onCollapse: (() -> Void)? = nil) {
        label.stringValue = text
        self.onCollapse = onCollapse
        needsLayout = true
    }
    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {
        // Collapse handled in tableView(_:shouldSelectRow:).
    }
    override func layout() {
        super.layout()
        label.frame = NSRect(x: SettingsUI.iconPad + SettingsUI.icon + 8, y: 0,
                             width: max(bounds.width - 40, 40), height: bounds.height)
    }
}

final class AppRowCell: NSView {
    private let iconView = NSImageView(frame: .zero)
    private let nameField = NSTextField(labelWithString: "")
    private let removeButton = HoverRemoveButton(frame: .zero)
    private var onRemove: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.wantsLayer = true
        iconView.layer?.cornerRadius = 4
        iconView.layer?.masksToBounds = true
        addSubview(iconView)
        nameField.isEditable = false
        nameField.isBordered = false
        nameField.drawsBackground = false
        nameField.font = .systemFont(ofSize: 13)
        nameField.textColor = .labelColor
        nameField.lineBreakMode = .byTruncatingTail
        nameField.usesSingleLineMode = true
        addSubview(nameField)
        removeButton.target = self
        removeButton.action = #selector(removeTapped)
        removeButton.toolTip = "Remove from custom applications"
        removeButton.setAccessibilityLabel("Remove")
        addSubview(removeButton)
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    func configure(
        icon: NSImage,
        name: String,
        toolTip: String,
        removable: Bool,
        removeTip: String = "Remove",
        onRemove: (() -> Void)?
    ) {
        iconView.image = icon
        nameField.stringValue = name
        self.toolTip = toolTip
        removeButton.isHidden = !removable
        removeButton.isEnabled = removable
        removeButton.toolTip = removeTip
        removeButton.setAccessibilityLabel(removeTip)
        self.onRemove = onRemove
        setAccessibilityLabel(name)
        needsLayout = true
    }
    @objc private func removeTapped() { onRemove?() }
    override func layout() {
        super.layout()
        let h = max(bounds.height, SettingsUI.rowH)
        let w = max(bounds.width, 120)
        let icon = SettingsUI.icon
        let pad = SettingsUI.iconPad
        iconView.frame = NSRect(x: pad, y: floor((h - icon) / 2), width: icon, height: icon)
        var right = w - SettingsUI.trailing
        if !removeButton.isHidden {
            let b: CGFloat = 22
            right -= b
            removeButton.frame = NSRect(x: right, y: floor((h - b) / 2), width: b, height: b)
            right -= 6
        } else {
            removeButton.frame = .zero
        }
        let textX = pad + icon + 8
        nameField.frame = NSRect(x: textX, y: floor((h - 16) / 2), width: max(right - textX, 40), height: 16)
    }
}

final class HoverRemoveButton: NSButton {
    private var tracking: NSTrackingArea?
    private var hovered = false
    private var pressed = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isBordered = false
        bezelStyle = .inline
        imagePosition = .imageOnly
        focusRingType = .exterior
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
        if let base = NSImage(systemSymbolName: "minus", accessibilityDescription: "Remove") {
            image = base.withSymbolConfiguration(.init(pointSize: 10, weight: .bold)) ?? base
        }
        apply(animated: false)
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let a = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(a); tracking = a
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseEntered(with event: NSEvent) { hovered = true; apply(animated: true) }
    override func mouseExited(with event: NSEvent) { hovered = false; pressed = false; apply(animated: true) }
    override func mouseDown(with event: NSEvent) {
        pressed = true; apply(animated: true)
        super.mouseDown(with: event)
        pressed = false; apply(animated: true)
    }
    private func apply(animated: Bool) {
        let reduce = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let dur: CFTimeInterval = (animated && !reduce) ? 0.12 : 0
        let tint: NSColor
        let fill: CGColor
        if pressed { tint = .white; fill = NSColor.systemRed.cgColor }
        else if hovered { tint = .systemRed; fill = NSColor.systemRed.withAlphaComponent(0.14).cgColor }
        else { tint = .secondaryLabelColor; fill = NSColor.clear.cgColor }
        contentTintColor = tint
        let block = { self.layer?.backgroundColor = fill }
        if dur > 0 {
            NSAnimationContext.runAnimationGroup { c in
                c.duration = dur
                c.timingFunction = CAMediaTimingFunction(name: .easeOut)
                NSAnimationContext.current.allowsImplicitAnimation = true
                block()
            }
        } else { block() }
    }
}

@MainActor
final class HelpPopover {
    static let shared = HelpPopover()
    private let popover = NSPopover()
    private let label = NSTextField(wrappingLabelWithString: "")

    private init() {
        popover.behavior = .transient
        popover.animates = true
        label.isEditable = false
        label.isBordered = false
        label.drawsBackground = false
        label.font = .systemFont(ofSize: 12)
        label.textColor = .labelColor
        label.maximumNumberOfLines = 0
        let box = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 160))
        label.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -14),
            label.topAnchor.constraint(equalTo: box.topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -12),
            box.widthAnchor.constraint(equalToConstant: 320),
        ])
        let vc = NSViewController(); vc.view = box
        popover.contentViewController = vc
    }

    func show(relativeTo rect: NSRect, of view: NSView, text: String) {
        label.stringValue = text
        let size = label.sizeThatFits(NSSize(width: 292, height: 2000))
        popover.contentSize = NSSize(width: 320, height: max(size.height + 24, 80))
        if popover.isShown { popover.close() }
        popover.show(relativeTo: rect, of: view, preferredEdge: .maxY)
    }
}

extension Notification.Name {
    static let kenglitPrefsChanged = Notification.Name("dev.finn.kenglit.prefsChanged")
}
