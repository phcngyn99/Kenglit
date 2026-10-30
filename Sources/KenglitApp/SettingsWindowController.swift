import AppKit
import UniformTypeIdentifiers
import KenglitCore

@MainActor
final class SettingsWindowController: NSWindowController {
    private let preferences: PreferencesStore
    private var table: NSTableView!
    private var loginButton: NSButton!
    private var errorLabel: NSTextField!

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

        // Top bar
        loginButton = NSButton(checkboxWithTitle: "Login start", target: self, action: #selector(toggleLogin))
        loginButton.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(loginButton)

        errorLabel = NSTextField(labelWithString: "")
        errorLabel.textColor = .secondaryLabelColor
        errorLabel.font = .systemFont(ofSize: 11)
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(errorLabel)

        // Table
        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.drawsBackground = true

        table = NSTableView()
        table.headerView = nil
        table.rowHeight = 36
        table.allowsMultipleSelection = true
        table.usesAlternatingRowBackgroundColors = true
        table.style = .inset

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("app"))
        col.title = "EN apps"
        col.width = 400
        table.addTableColumn(col)
        table.dataSource = self
        table.delegate = self
        scroll.documentView = table
        root.addSubview(scroll)

        // Bottom buttons — browse-first
        let pickApps = NSButton(title: "Add Apps…", target: self, action: #selector(pickFromApplications))
        pickApps.translatesAutoresizingMaskIntoConstraints = false
        pickApps.bezelStyle = .rounded
        pickApps.keyEquivalent = "\r"
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
        let rows = table.selectedRowIndexes.sorted(by: >)
        guard !rows.isEmpty else { return }
        var ids = preferences.watchedBundleIDs
        for row in rows where row >= 0 && row < ids.count {
            ids.remove(at: row)
        }
        preferences.setWatchedBundleIDs(ids)
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
        panel.canSelectHiddenExtension = true

        // Accessory apps need temporary regular policy or open panel dies silently.
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
        if let idx = preferences.watchedBundleIDs.firstIndex(of: id) {
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
        // Generic app icon fallback
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
    func windowDidBecomeKey(_ notification: Notification) {
        reloadTable()
    }
}

extension SettingsWindowController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        preferences.watchedBundleIDs.count
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        36
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let bid = preferences.watchedBundleIDs[row]
        let name = Self.friendlyName(for: bid)
        let icon = Self.appIcon(for: bid)

        let id = NSUserInterfaceItemIdentifier("AppCell")
        let cell = tableView.makeView(withIdentifier: id, owner: nil) as? NSTableCellView
            ?? {
                let cell = NSTableCellView()
                cell.identifier = id

                let imageView = NSImageView()
                imageView.identifier = NSUserInterfaceItemIdentifier("icon")
                imageView.imageScaling = .scaleProportionallyUpOrDown
                imageView.translatesAutoresizingMaskIntoConstraints = false
                cell.addSubview(imageView)
                cell.imageView = imageView

                let text = NSTextField(labelWithString: "")
                text.identifier = NSUserInterfaceItemIdentifier("name")
                text.font = .systemFont(ofSize: 13, weight: .medium)
                text.lineBreakMode = .byTruncatingTail
                text.translatesAutoresizingMaskIntoConstraints = false
                cell.addSubview(text)
                cell.textField = text

                NSLayoutConstraint.activate([
                    imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                    imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                    imageView.widthAnchor.constraint(equalToConstant: 28),
                    imageView.heightAnchor.constraint(equalToConstant: 28),

                    text.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 10),
                    text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                    text.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                ])
                return cell
            }()

        cell.imageView?.image = icon
        cell.textField?.stringValue = name
        cell.toolTip = bid
        return cell
    }
}

extension Notification.Name {
    static let kenglitPrefsChanged = Notification.Name("dev.finn.kenglit.prefsChanged")
}
