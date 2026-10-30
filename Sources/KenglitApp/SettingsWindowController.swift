import AppKit
import UniformTypeIdentifiers
import KenglitCore

@MainActor
final class SettingsWindowController: NSWindowController {
    private let preferences: PreferencesStore
    private var table: NSTableView!
    private var loginButton: NSButton!
    private var errorLabel: NSTextField!
    /// Snapshot used by the table so scroll/recycle never reads a moving target.
    private var rows: [String] = []

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
            loginButton.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            loginButton.topAnchor.constraint(equalTo: root.topAnchor, constant: 14),

            errorLabel.leadingAnchor.constraint(equalTo: loginButton.trailingAnchor, constant: 12),
            errorLabel.centerYAnchor.constraint(equalTo: loginButton.centerYAnchor),
            errorLabel.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor, constant: -16),

            scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
            scroll.topAnchor.constraint(equalTo: loginButton.bottomAnchor, constant: 12),
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
        rows = preferences.watchedBundleIDs
        table.reloadData()
        loginButton.state = preferences.launchAtLogin ? .on : .off
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
        let removeIDs = selected.compactMap { idx -> String? in
            guard idx >= 0, idx < rows.count else { return nil }
            return rows[idx]
        }
        guard !removeIDs.isEmpty else { return }
        let removeSet = Set(removeIDs)
        let next = preferences.watchedBundleIDs.filter { !removeSet.contains($0) }
        preferences.setWatchedBundleIDs(next)
        reloadTable()
        NotificationCenter.default.post(name: .kenglitPrefsChanged, object: nil)
    }

    @objc private func addFrontmost() {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let id = app.bundleIdentifier,
              id != "dev.finn.kenglit" else { return }
        preferences.addWatchedBundleID(id)
        if let name = app.localizedName, !name.isEmpty {
            WatchedAppsUserNames.set(name, for: id)
        }
        reloadTable()
        scrollToBundleID(id)
        NotificationCenter.default.post(name: .kenglitPrefsChanged, object: nil)
        errorLabel.textColor = .secondaryLabelColor
        errorLabel.stringValue = "+1"
    }

    @objc private func pickFromApplications() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.treatsFilePackagesAsDirectories = false
        panel.canCreateDirectories = false
        panel.prompt = "Add"
        panel.message = "Choose apps for English"
        panel.allowedContentTypes = [.application, .applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)

        Self.log("pick open")
        let response = panel.runModal()
        Self.log("pick response=\(response.rawValue) count=\(panel.urls.count)")

        NSApp.setActivationPolicy(.accessory)

        guard response == .OK else {
            errorLabel.stringValue = ""
            window?.makeKeyAndOrderFront(nil)
            return
        }

        var added = 0
        var failed = 0
        var lastID: String?
        for url in panel.urls {
            let resolved = url.resolvingSymlinksInPath()
            Self.log("pick try \(resolved.path)")
            guard let bid = Self.bundleIdentifier(forAppURL: resolved),
                  bid != "dev.finn.kenglit" else {
                failed += 1
                Self.log("pick fail id \(resolved.path)")
                continue
            }
            let before = Set(preferences.watchedBundleIDs)
            preferences.addWatchedBundleID(bid)
            if !before.contains(bid) {
                added += 1
                lastID = bid
            }
            if let name = Self.displayName(forAppURL: resolved), !name.isEmpty {
                WatchedAppsUserNames.set(name, for: bid)
            }
            Self.log("pick ok \(bid)")
        }

        reloadTable()
        if let lastID {
            scrollToBundleID(lastID)
        }
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
        window?.makeKeyAndOrderFront(nil)
        Self.log("pick done added=\(added) failed=\(failed) total=\(preferences.watchedBundleIDs.count)")
    }

    @objc private func resetDefaults() {
        preferences.setWatchedBundleIDs(WatchedApps.defaults)
        reloadTable()
        NotificationCenter.default.post(name: .kenglitPrefsChanged, object: nil)
        errorLabel.stringValue = ""
    }

    private func scrollToBundleID(_ id: String) {
        if let idx = rows.firstIndex(of: id) {
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
        let size = NSSize(width: 28, height: 28)
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            icon.size = size
            return icon
        }
        if let generic = NSImage(systemSymbolName: "app.fill", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
            let img = generic.withSymbolConfiguration(config) ?? generic
            img.size = size
            return img
        }
        return NSImage(size: size)
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
}

extension SettingsWindowController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        rows.count
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        40
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0, row < rows.count else { return nil }
        let bid = rows[row]
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
        cell.configure(icon: icon, name: name, toolTip: bid)
        return cell
    }
}

/// Frame-based cell. No Auto Layout inside recycled rows (avoids scroll wipe).
final class AppIconNameCell: NSView {
    private let iconView = NSImageView(frame: .zero)
    private let nameField = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.imageAlignment = .alignCenter
        addSubview(iconView)

        nameField.isEditable = false
        nameField.isBordered = false
        nameField.drawsBackground = false
        nameField.font = .systemFont(ofSize: 13, weight: .medium)
        nameField.lineBreakMode = .byTruncatingTail
        nameField.cell?.truncatesLastVisibleLine = true
        addSubview(nameField)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func configure(icon: NSImage, name: String, toolTip: String) {
        iconView.image = icon
        nameField.stringValue = name
        self.toolTip = toolTip
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let h = bounds.height
        let icon: CGFloat = 28
        let inset: CGFloat = 8
        iconView.frame = NSRect(
            x: inset,
            y: (h - icon) / 2,
            width: icon,
            height: icon
        )
        let textX = iconView.frame.maxX + 10
        nameField.frame = NSRect(
            x: textX,
            y: 0,
            width: max(bounds.width - textX - inset, 0),
            height: h
        )
    }
}

extension Notification.Name {
    static let kenglitPrefsChanged = Notification.Name("dev.finn.kenglit.prefsChanged")
}
