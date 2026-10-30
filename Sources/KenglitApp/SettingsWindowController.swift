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
        errorLabel.textColor = .systemRed
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
            errorLabel.stringValue = "Login fail"
            loginButton.state = preferences.launchAtLogin ? .on : .off
        }
    }

    @objc private func addBundle() {
        let id = bundleField.stringValue
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
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
    }

    @objc private func pickFromApplications() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.prompt = "Add"
        panel.message = "Pick apps → EN"

        // Also allow ~/Applications
        panel.treatsFilePackagesAsDirectories = false

        guard let win = window else { return }
        panel.beginSheetModal(for: win) { [weak self] response in
            guard let self, response == .OK else { return }
            var added = 0
            for url in panel.urls {
                guard let bid = Bundle(url: url)?.bundleIdentifier,
                      bid != "dev.finn.kenglit" else { continue }
                let before = Set(self.preferences.watchedBundleIDs)
                self.preferences.addWatchedBundleID(bid)
                if !before.contains(bid) { added += 1 }

                // Remember friendly name if we can read it from the app bundle
                if let name = Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleName") as? String,
                   !name.isEmpty {
                    WatchedAppsUserNames.set(name, for: bid)
                } else if let name = Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
                          !name.isEmpty {
                    WatchedAppsUserNames.set(name, for: bid)
                }
            }
            self.reloadTable()
            NotificationCenter.default.post(name: .kenglitPrefsChanged, object: nil)
            if added == 0 {
                self.errorLabel.stringValue = "None new"
            } else {
                self.errorLabel.stringValue = ""
            }
        }
    }

    @objc private func resetDefaults() {
        preferences.setWatchedBundleIDs(WatchedApps.defaults)
        reloadTable()
        NotificationCenter.default.post(name: .kenglitPrefsChanged, object: nil)
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
        let name = WatchedAppsUserNames.displayName(for: bid)
        cell.stringValue = name == bid ? bid : name
        return cell
    }
}

extension Notification.Name {
    static let kenglitPrefsChanged = Notification.Name("dev.finn.kenglit.prefsChanged")
}
