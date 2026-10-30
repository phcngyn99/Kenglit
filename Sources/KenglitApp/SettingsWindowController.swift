import AppKit
import UniformTypeIdentifiers
import KenglitCore

@MainActor
final class SettingsWindowController: NSWindowController {
    private let preferences: PreferencesStore
    private var table: NSTableView!
    private var bundleField: NSTextField!
    private var loginButton: NSButton!
    private var errorLabel: NSTextField!

    init(preferences: PreferencesStore) {
        self.preferences = preferences
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 460),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Kenglit"
        window.center()
        super.init(window: window)
        window.contentView = buildContent()
        window.delegate = self
        reloadTable()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func buildContent() -> NSView {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 460))

        loginButton = NSButton(checkboxWithTitle: "Login start", target: self, action: #selector(toggleLogin))
        loginButton.state = preferences.launchAtLogin ? .on : .off
        loginButton.frame = NSRect(x: 20, y: 420, width: 200, height: 24)
        root.addSubview(loginButton)

        errorLabel = NSTextField(labelWithString: "")
        errorLabel.textColor = .secondaryLabelColor
        errorLabel.font = .systemFont(ofSize: 11)
        errorLabel.frame = NSRect(x: 230, y: 420, width: 300, height: 24)
        root.addSubview(errorLabel)

        let scroll = NSScrollView(frame: NSRect(x: 20, y: 90, width: 520, height: 310))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        table = NSTableView(frame: scroll.bounds)
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("id"))
        col.title = "EN apps"
        col.width = 500
        table.addTableColumn(col)
        table.headerView = NSTableHeaderView()
        table.dataSource = self
        table.delegate = self
        scroll.documentView = table
        root.addSubview(scroll)

        bundleField = NSTextField(frame: NSRect(x: 20, y: 50, width: 340, height: 24))
        bundleField.placeholderString = "bundle.id"
        root.addSubview(bundleField)

        let add = NSButton(title: "Add", target: self, action: #selector(addBundle))
        add.frame = NSRect(x: 370, y: 48, width: 70, height: 28)
        root.addSubview(add)

        let remove = NSButton(title: "Del", target: self, action: #selector(removeSelected))
        remove.frame = NSRect(x: 450, y: 48, width: 90, height: 28)
        root.addSubview(remove)

        let addFront = NSButton(title: "Add front", target: self, action: #selector(addFrontmost))
        addFront.frame = NSRect(x: 20, y: 16, width: 100, height: 28)
        root.addSubview(addFront)

        let pickApps = NSButton(title: "Apps…", target: self, action: #selector(pickFromApplications))
        pickApps.frame = NSRect(x: 130, y: 16, width: 90, height: 28)
        root.addSubview(pickApps)

        let reset = NSButton(title: "Reset", target: self, action: #selector(resetDefaults))
        reset.frame = NSRect(x: 230, y: 16, width: 80, height: 28)
        root.addSubview(reset)

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

    @objc private func addBundle() {
        let id = bundleField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return }
        preferences.addWatchedBundleID(id)
        bundleField.stringValue = ""
        reloadTable()
        NotificationCenter.default.post(name: .kenglitPrefsChanged, object: nil)
    }

    @objc private func removeSelected() {
        let row = table.selectedRow
        guard row >= 0, row < preferences.watchedBundleIDs.count else { return }
        let id = preferences.watchedBundleIDs[row]
        preferences.removeWatchedBundleID(id)
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
        panel.message = "Pick apps -> EN"
        panel.allowedFileTypes = ["app"]
        let appsDir = URL(fileURLWithPath: "/Applications", isDirectory: true)
        if FileManager.default.fileExists(atPath: appsDir.path) {
            panel.directoryURL = appsDir
        }

        // LSUIElement / accessory: open panels often fail unless app is regular.
        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)

        Self.log("pick open")
        let response = panel.runModal()
        Self.log("pick response=\(response.rawValue) count=\(panel.urls.count)")

        NSApp.setActivationPolicy(.accessory)
        _ = previousPolicy

        guard response == .OK else {
            errorLabel.stringValue = ""
            return
        }

        var added = 0
        var failed = 0
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
            }
            if let name = Self.displayName(forAppURL: resolved), !name.isEmpty {
                WatchedAppsUserNames.set(name, for: bid)
            }
            Self.log("pick ok \(bid)")
        }

        reloadTable()
        table.needsDisplay = true
        let last = preferences.watchedBundleIDs.count - 1
        if last >= 0 {
            table.scrollRowToVisible(last)
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
    }

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

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("cell")
        let cell = tableView.makeView(withIdentifier: id, owner: nil) as? NSTextField
            ?? {
                let t = NSTextField(labelWithString: "")
                t.identifier = id
                t.font = .systemFont(ofSize: 12)
                t.lineBreakMode = .byTruncatingMiddle
                return t
            }()
        let bid = preferences.watchedBundleIDs[row]
        let name = Self.friendlyName(for: bid)
        // Always show name + id so bundle-only entries are findable
        cell.stringValue = name == bid ? bid : "\(name)  ·  \(bid)"
        return cell
    }
}

extension Notification.Name {
    static let kenglitPrefsChanged = Notification.Name("dev.finn.kenglit.prefsChanged")
}
