import AppKit
import UniformTypeIdentifiers
import KenglitCore

@MainActor
final class SettingsWindowController: NSWindowController {
    private let preferences: PreferencesStore
    private var table: NSTableView!
    private var enabledButton: NSButton!
    private var loginButton: NSButton!
    private var errorLabel: NSTextField!
    var onClose: (() -> Void)?
    /// Snapshot rows so scroll/recycle never reads a moving target.
    private var displayRows: [SettingsRow] = []

    private enum SettingsRow {
        case header(title: String, subtitle: String)
        case app(bundleID: String, isUser: Bool)
    }

    init(preferences: PreferencesStore) {
        self.preferences = preferences
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Kenglit"
        window.minSize = NSSize(width: 420, height: 360)
        window.center()
        super.init(window: window)
        window.contentView = buildContent()
        window.delegate = self
        reloadTable()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func buildContent() -> NSView {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 520))

        enabledButton = NSButton(checkboxWithTitle: "Enable", target: self, action: #selector(toggleEnabled))
        enabledButton.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(enabledButton)

        loginButton = NSButton(checkboxWithTitle: "Login start", target: self, action: #selector(toggleLogin))
        loginButton.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(loginButton)

        errorLabel = NSTextField(labelWithString: "")
        errorLabel.textColor = .secondaryLabelColor
        errorLabel.font = .systemFont(ofSize: 11)
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(errorLabel)

        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .bezelBorder
        scroll.drawsBackground = true
        scroll.backgroundColor = .controlBackgroundColor

        table = NSTableView()
        table.headerView = nil
        table.rowHeight = 40
        table.allowsMultipleSelection = true
        table.usesAlternatingRowBackgroundColors = true
        table.selectionHighlightStyle = .regular
        table.gridStyleMask = []
        table.intercellSpacing = NSSize(width: 0, height: 2)
        if #available(macOS 11.0, *) {
            table.style = .fullWidth
        }

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("app"))
        col.title = "EN apps"
        col.resizingMask = .autoresizingMask
        col.width = 440
        col.minWidth = 200
        table.addTableColumn(col)
        table.dataSource = self
        table.delegate = self
        table.doubleAction = nil
        scroll.documentView = table
        root.addSubview(scroll)

        let pickApps = NSButton(title: "Add Apps…", target: self, action: #selector(pickFromApplications))
        pickApps.translatesAutoresizingMaskIntoConstraints = false
        pickApps.bezelStyle = .rounded
        root.addSubview(pickApps)

        let addFront = NSButton(title: "Add front", target: self, action: #selector(addFrontmost))
        addFront.translatesAutoresizingMaskIntoConstraints = false
        addFront.bezelStyle = .rounded
        root.addSubview(addFront)

        let remove = NSButton(title: "Del", target: self, action: #selector(removeSelected))
        remove.translatesAutoresizingMaskIntoConstraints = false
        remove.bezelStyle = .rounded
        root.addSubview(remove)

        let reset = NSButton(title: "Reset", target: self, action: #selector(resetDefaults))
        reset.translatesAutoresizingMaskIntoConstraints = false
        reset.bezelStyle = .rounded
        root.addSubview(reset)

        NSLayoutConstraint.activate([
            enabledButton.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            enabledButton.topAnchor.constraint(equalTo: root.topAnchor, constant: 14),

            loginButton.leadingAnchor.constraint(equalTo: enabledButton.trailingAnchor, constant: 16),
            loginButton.centerYAnchor.constraint(equalTo: enabledButton.centerYAnchor),

            errorLabel.leadingAnchor.constraint(equalTo: loginButton.trailingAnchor, constant: 12),
            errorLabel.centerYAnchor.constraint(equalTo: enabledButton.centerYAnchor),
            errorLabel.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor, constant: -16),

            scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
            scroll.topAnchor.constraint(equalTo: enabledButton.bottomAnchor, constant: 12),
            scroll.bottomAnchor.constraint(equalTo: pickApps.topAnchor, constant: -12),

            pickApps.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            pickApps.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -14),

            addFront.leadingAnchor.constraint(equalTo: pickApps.trailingAnchor, constant: 8),
            addFront.centerYAnchor.constraint(equalTo: pickApps.centerYAnchor),

            remove.leadingAnchor.constraint(equalTo: addFront.trailingAnchor, constant: 8),
            remove.centerYAnchor.constraint(equalTo: pickApps.centerYAnchor),

            reset.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
            reset.centerYAnchor.constraint(equalTo: pickApps.centerYAnchor),
        ])

        return root
    }

    private func reloadTable() {
        let user = preferences.userWatchedBundleIDs
        let builtin = WatchedApps.defaults
        var next: [SettingsRow] = []

        // User first (editable)
        next.append(.header(
            title: "Yours",
            subtitle: user.isEmpty ? "none yet" : "\(user.count)"
        ))
        for bid in user {
            next.append(.app(bundleID: bid, isUser: true))
        }

        next.append(.header(
            title: "Default",
            subtitle: "\(builtin.count) · always EN"
        ))
        for bid in builtin {
            next.append(.app(bundleID: bid, isUser: false))
        }

        displayRows = next
        table.reloadData()
        enabledButton.state = preferences.isEnabled ? .on : .off
        loginButton.state = preferences.launchAtLogin ? .on : .off
    }

    @objc private func toggleEnabled() {
        preferences.isEnabled = (enabledButton.state == .on)
        NotificationCenter.default.post(name: .kenglitPrefsChanged, object: nil)
    }

    @objc private func toggleLogin() {
        let want = loginButton.state == .on
        if LaunchAtLogin.setEnabled(want) {
            preferences.launchAtLogin = want
            errorLabel.stringValue = ""
        } else {
            errorLabel.textColor = .systemRed
            errorLabel.stringValue = "Login fail"
            loginButton.state = preferences.launchAtLogin ? .on : .off
        }
    }

    @objc private func removeSelected() {
        let selected = table.selectedRowIndexes
        guard !selected.isEmpty else { return }
        let removeIDs: [String] = selected.compactMap { idx in
            guard idx >= 0, idx < displayRows.count else { return nil }
            if case let .app(bid, isUser) = displayRows[idx], isUser {
                return bid
            }
            return nil
        }
        guard !removeIDs.isEmpty else {
            errorLabel.textColor = .secondaryLabelColor
            errorLabel.stringValue = "Default locked"
            return
        }
        let removeSet = Set(removeIDs)
        let next = preferences.userWatchedBundleIDs.filter { !removeSet.contains($0) }
        preferences.setUserWatchedBundleIDs(next)
        reloadTable()
        NotificationCenter.default.post(name: .kenglitPrefsChanged, object: nil)
        errorLabel.textColor = .secondaryLabelColor
        errorLabel.stringValue = "−\(removeIDs.count)"
    }

    @objc private func addFrontmost() {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let id = app.bundleIdentifier,
              id != "dev.finn.kenglit" else { return }
        if WatchedApps.defaults.contains(id) {
            reloadTable()
            scrollToBundleID(id)
            errorLabel.textColor = .secondaryLabelColor
            errorLabel.stringValue = "Default"
            return
        }
        let before = Set(preferences.userWatchedBundleIDs)
        preferences.addWatchedBundleID(id)
        if let name = app.localizedName, !name.isEmpty {
            WatchedAppsUserNames.set(name, for: id)
        }
        reloadTable()
        scrollToBundleID(id)
        NotificationCenter.default.post(name: .kenglitPrefsChanged, object: nil)
        errorLabel.textColor = .secondaryLabelColor
        errorLabel.stringValue = before.contains(id) ? "None new" : "+1"
    }

    @objc private func pickFromApplications() {
        let panel = NSOpenPanel()
        panel.title = "Add Apps"
        panel.prompt = "Add"
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
        // Icon/column browser like Finder
        panel.message = ""

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)

        // runModal always shows for accessory apps; beginSheet can hang.
        let result = panel.runModal()
        defer {
            // Stay regular while Settings open
            window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        guard result == .OK else { return }

        var added = 0
        var failed = 0
        for url in panel.urls {
            guard let bid = Self.bundleID(fromAppURL: url) else {
                failed += 1
                continue
            }
            if bid == "dev.finn.kenglit" { continue }
            let before = Set(preferences.userWatchedBundleIDs)
            preferences.addWatchedBundleID(bid)
            let name = FileManager.default.displayName(atPath: url.path)
                .replacingOccurrences(of: ".app", with: "")
            if !name.isEmpty {
                WatchedAppsUserNames.set(name, for: bid)
            }
            if !before.contains(bid) { added += 1 }
        }

        reloadTable()
        NotificationCenter.default.post(name: .kenglitPrefsChanged, object: nil)

        if added > 0 {
            errorLabel.textColor = .secondaryLabelColor
            errorLabel.stringValue = "+\(added)"
        } else if failed > 0 {
            errorLabel.textColor = .systemRed
            errorLabel.stringValue = "Read fail"
        } else {
            errorLabel.textColor = .secondaryLabelColor
            errorLabel.stringValue = "None new"
        }
    }

    private static func bundleID(fromAppURL url: URL) -> String? {
        // Prefer Info.plist — Bundle(url:) often nil for arbitrary .app picks.
        let infoURL = url.appendingPathComponent("Contents/Info.plist")
        if let dict = NSDictionary(contentsOf: infoURL) as? [String: Any],
           let bid = dict["CFBundleIdentifier"] as? String,
           !bid.isEmpty {
            return bid
        }
        if let bid = Bundle(url: url)?.bundleIdentifier, !bid.isEmpty {
            return bid
        }
        return nil
    }

    @objc private func resetDefaults() {
        preferences.resetUserExtras()
        reloadTable()
        NotificationCenter.default.post(name: .kenglitPrefsChanged, object: nil)
        errorLabel.textColor = .secondaryLabelColor
        errorLabel.stringValue = "Cleared"
    }

    private func scrollToBundleID(_ id: String) {
        if let idx = displayRows.firstIndex(where: {
            if case let .app(bid, _) = $0 { return bid == id }
            return false
        }) {
            table.scrollRowToVisible(idx)
            table.selectRowIndexes(IndexSet(integer: idx), byExtendingSelection: false)
        }
    }

    // MARK: - Bundle helpers

    private static func bundleIdentifier(forAppURL url: URL) -> String? {
        let appURL = normalizeAppURL(url)
        if let id = Bundle(url: appURL)?.bundleIdentifier, !id.isEmpty {
            return id
        }
        let info = appURL.appendingPathComponent("Contents/Info.plist")
        if let dict = NSDictionary(contentsOf: info) as? [String: Any],
           let id = dict["CFBundleIdentifier"] as? String,
           !id.isEmpty {
            return id
        }
        let cfURL = appURL as CFURL
        if let cfBundle = CFBundleCreate(kCFAllocatorDefault, cfURL),
           let cfID = CFBundleGetIdentifier(cfBundle) as String?,
           !cfID.isEmpty {
            return cfID
        }
        return nil
    }

    private static func displayName(forAppURL url: URL) -> String? {
        let appURL = normalizeAppURL(url)
        let info = appURL.appendingPathComponent("Contents/Info.plist")
        if let dict = NSDictionary(contentsOf: info) as? [String: Any] {
            if let name = dict["CFBundleDisplayName"] as? String, !name.isEmpty { return name }
            if let name = dict["CFBundleName"] as? String, !name.isEmpty { return name }
        }
        return appURL.deletingPathExtension().lastPathComponent
    }

    private static func normalizeAppURL(_ url: URL) -> URL {
        var u = url.resolvingSymlinksInPath()
        while u.pathExtension.lowercased() != "app", u.path != "/", !u.path.isEmpty {
            let parent = u.deletingLastPathComponent()
            if parent.path == u.path { break }
            u = parent
        }
        return u
    }

    private static func friendlyName(for bundleID: String) -> String {
        let mapped = WatchedAppsUserNames.displayName(for: bundleID)
        if mapped != bundleID { return mapped }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            if let name = displayName(forAppURL: url), !name.isEmpty {
                WatchedAppsUserNames.set(name, for: bundleID)
                return name
            }
            return url.deletingPathExtension().lastPathComponent
        }
        return bundleID
    }

    private static func appIcon(for bundleID: String) -> NSImage {
        let point = NSSize(width: 28, height: 28)
        let source: NSImage
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            source = NSWorkspace.shared.icon(forFile: url.path)
        } else if let generic = NSImage(systemSymbolName: "app.fill", accessibilityDescription: nil) {
            source = generic
        } else {
            return NSImage(size: point)
        }

        // Draw into a fixed-size bitmap so NSImageView always has real pixels
        // (mutating icon.size alone is unreliable across AppKit versions).
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let px = NSSize(width: point.width * scale, height: point.height * scale)
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(px.width),
            pixelsHigh: Int(px.height),
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
            let dst = NSRect(origin: .zero, size: point)
            source.draw(
                in: dst,
                from: NSRect(origin: .zero, size: source.size),
                operation: .sourceOver,
                fraction: 1.0,
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

    private static func log(_ msg: String) {
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(msg)\n"
        let path = "/tmp/kenglit-picker.log"
        guard let data = line.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: path),
           let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: path)) {
            defer { try? handle.close() }
            handle.seekToEndOfFile()
            handle.write(data)
        } else {
            try? data.write(to: URL(fileURLWithPath: path))
        }
        NSLog("Kenglit %@", msg)
    }
}

extension SettingsWindowController: NSWindowDelegate {
    // Intentionally no reload on become-key / scroll. That wiped the UI.

    func windowWillClose(_ notification: Notification) {
        onClose?()
        onClose = nil
    }
}

extension SettingsWindowController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        displayRows.count
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard row >= 0, row < displayRows.count else { return 40 }
        switch displayRows[row] {
        case .header: return 28
        case .app: return 40
        }
    }

    func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
        guard row >= 0, row < displayRows.count else { return false }
        if case .header = displayRows[row] { return true }
        return false
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        guard row >= 0, row < displayRows.count else { return false }
        switch displayRows[row] {
        case .header:
            return false
        case .app(_, let isUser):
            return isUser
        }
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0, row < displayRows.count else { return nil }
        switch displayRows[row] {
        case let .header(title, subtitle):
            let id = NSUserInterfaceItemIdentifier("SectionHeaderCell")
            let cell: SectionHeaderCell
            if let reused = tableView.makeView(withIdentifier: id, owner: nil) as? SectionHeaderCell {
                cell = reused
            } else {
                cell = SectionHeaderCell(frame: .zero)
                cell.identifier = id
            }
            cell.configure(title: title, subtitle: subtitle)
            return cell

        case let .app(bid, isUser):
            let name = Self.friendlyName(for: bid)
            let icon = Self.appIcon(for: bid)
            let id = NSUserInterfaceItemIdentifier("AppIconNameCell")
            let cell: AppIconNameCell
            if let reused = tableView.makeView(withIdentifier: id, owner: nil) as? AppIconNameCell {
                cell = reused
            } else {
                cell = AppIconNameCell(frame: .zero)
                cell.identifier = id
            }
            cell.configure(icon: icon, name: name, toolTip: bid, dimmed: !isUser)
            return cell
        }
    }
}

/// Section header row (Default / Yours).
final class SectionHeaderCell: NSView {
    private let titleField = NSTextField(labelWithString: "")
    private let subField = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        titleField.isEditable = false
        titleField.isBordered = false
        titleField.drawsBackground = false
        titleField.backgroundColor = .clear
        titleField.font = .systemFont(ofSize: 11, weight: .semibold)
        titleField.textColor = .secondaryLabelColor
        addSubview(titleField)

        subField.isEditable = false
        subField.isBordered = false
        subField.drawsBackground = false
        subField.backgroundColor = .clear
        subField.font = .systemFont(ofSize: 11, weight: .regular)
        subField.textColor = .tertiaryLabelColor
        subField.alignment = .right
        addSubview(subField)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String, subtitle: String) {
        titleField.stringValue = title.uppercased()
        subField.stringValue = subtitle
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let h = max(bounds.height, 28)
        let w = max(bounds.width, 120)
        let inset: CGFloat = 10
        titleField.frame = NSRect(x: inset, y: 0, width: w * 0.55, height: h)
        let subW = w * 0.4
        subField.frame = NSRect(x: w - subW - inset, y: 0, width: subW, height: h)
    }
}

/// Frame-based cell. No Auto Layout inside recycled rows (avoids scroll wipe).
final class AppIconNameCell: NSTableCellView {
    private let iconView = NSImageView(frame: .zero)
    private let nameField = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        iconView.wantsLayer = true
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.imageAlignment = .alignCenter
        iconView.animates = false
        addSubview(iconView)

        nameField.isEditable = false
        nameField.isBordered = false
        nameField.drawsBackground = false
        nameField.backgroundColor = .clear
        nameField.font = .systemFont(ofSize: 13, weight: .medium)
        nameField.textColor = .labelColor
        nameField.lineBreakMode = .byTruncatingTail
        nameField.cell?.truncatesLastVisibleLine = true
        nameField.cell?.lineBreakMode = .byTruncatingTail
        addSubview(nameField)

        // NSTableCellView expected refs
        imageView = iconView
        textField = nameField
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func configure(icon: NSImage, name: String, toolTip: String, dimmed: Bool = false) {
        iconView.image = icon
        iconView.alphaValue = dimmed ? 0.55 : 1.0
        nameField.stringValue = name
        nameField.textColor = dimmed ? .secondaryLabelColor : .labelColor
        self.toolTip = toolTip
        needsLayout = true
        layoutSubtreeIfNeeded()
    }

    override func layout() {
        super.layout()
        let h = max(bounds.height, 40)
        let w = max(bounds.width, 120)
        let icon: CGFloat = 28
        let inset: CGFloat = 10
        iconView.frame = NSRect(x: inset, y: (h - icon) / 2, width: icon, height: icon)
        let textX = iconView.frame.maxX + 10
        nameField.frame = NSRect(x: textX, y: 0, width: max(w - textX - inset, 40), height: h)
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: 40)
    }
}

extension Notification.Name {
    static let kenglitPrefsChanged = Notification.Name("dev.finn.kenglit.prefsChanged")
}
