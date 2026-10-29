import AppKit
import KenglitCore

@MainActor
final class SettingsWindowController: NSWindowController {
    private let preferences: PreferencesStore
    private var table: NSTableView!
    private var bundleField: NSTextField!
    private var enabledButton: NSButton!
    private var loginButton: NSButton!
    private var errorLabel: NSTextField!

    init(preferences: PreferencesStore) {
        self.preferences = preferences
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "kenglit Settings"
        window.center()
        super.init(window: window)
        window.contentView = buildContent()
        reloadTable()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func buildContent() -> NSView {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 420))

        enabledButton = NSButton(checkboxWithTitle: "Enabled", target: self, action: #selector(toggleEnabled))
        enabledButton.state = preferences.isEnabled ? .on : .off
        enabledButton.frame = NSRect(x: 20, y: 380, width: 200, height: 24)
        root.addSubview(enabledButton)

        loginButton = NSButton(checkboxWithTitle: "Launch at login", target: self, action: #selector(toggleLogin))
        loginButton.state = preferences.launchAtLogin ? .on : .off
        loginButton.frame = NSRect(x: 20, y: 352, width: 200, height: 24)
        root.addSubview(loginButton)

        errorLabel = NSTextField(labelWithString: "")
        errorLabel.textColor = .systemRed
        errorLabel.font = .systemFont(ofSize: 11)
        errorLabel.frame = NSRect(x: 230, y: 352, width: 260, height: 24)
        root.addSubview(errorLabel)

        let scroll = NSScrollView(frame: NSRect(x: 20, y: 90, width: 480, height: 250))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        table = NSTableView(frame: scroll.bounds)
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("id"))
        col.title = "Watched bundle IDs"
        col.width = 460
        table.addTableColumn(col)
        table.headerView = NSTableHeaderView()
        table.dataSource = self
        table.delegate = self
        scroll.documentView = table
        root.addSubview(scroll)

        bundleField = NSTextField(frame: NSRect(x: 20, y: 50, width: 300, height: 24))
        bundleField.placeholderString = "bundle.id"
        root.addSubview(bundleField)

        let add = NSButton(title: "Add", target: self, action: #selector(addBundle))
        add.frame = NSRect(x: 330, y: 48, width: 70, height: 28)
        root.addSubview(add)

        let remove = NSButton(title: "Remove", target: self, action: #selector(removeSelected))
        remove.frame = NSRect(x: 410, y: 48, width: 90, height: 28)
        root.addSubview(remove)

        let addFront = NSButton(title: "Add frontmost app", target: self, action: #selector(addFrontmost))
        addFront.frame = NSRect(x: 20, y: 16, width: 160, height: 28)
        root.addSubview(addFront)

        let reset = NSButton(title: "Reset to defaults", target: self, action: #selector(resetDefaults))
        reset.frame = NSRect(x: 190, y: 16, width: 150, height: 28)
        root.addSubview(reset)

        return root
    }

    private func reloadTable() {
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
            errorLabel.stringValue = "Could not update login item"
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
        guard let id = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
              id != "dev.finn.kenglit" else { return }
        preferences.addWatchedBundleID(id)
        reloadTable()
        NotificationCenter.default.post(name: .kenglitPrefsChanged, object: nil)
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
                t.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
                return t
            }()
        cell.stringValue = preferences.watchedBundleIDs[row]
        return cell
    }
}

extension Notification.Name {
    static let kenglitPrefsChanged = Notification.Name("dev.finn.kenglit.prefsChanged")
}
