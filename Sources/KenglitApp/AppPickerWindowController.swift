import AppKit
import KenglitCore

/// Finder-like browser of installed apps (icon + name), multi-select, add to EN list.
@MainActor
final class AppPickerWindowController: NSWindowController {
    private let preferences: PreferencesStore
    private var table: NSTableView!
    private var searchField: NSSearchField!
    private var statusLabel: NSTextField!
    private var allApps: [InstalledApp] = []
    private var filtered: [InstalledApp] = []
    var onAdded: (() -> Void)?
    var onDone: (() -> Void)?

    struct InstalledApp {
        let bundleID: String
        let name: String
        let path: String
        let icon: NSImage
    }

    init(preferences: PreferencesStore) {
        self.preferences = preferences
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Choose Apps"
        window.minSize = NSSize(width: 420, height: 400)
        window.center()
        super.init(window: window)
        window.contentView = buildContent()
        window.delegate = self
        reloadAppsAsync()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func buildContent() -> NSView {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 560))

        searchField = NSSearchField()
        searchField.placeholderString = "Search"
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.target = self
        searchField.action = #selector(searchChanged)
        root.addSubview(searchField)

        statusLabel = NSTextField(labelWithString: "Loading…")
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(statusLabel)

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
            table.allowsEmptySelection = true
        }
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("app"))
        col.width = 480
        col.resizingMask = .autoresizingMask
        table.addTableColumn(col)
        table.dataSource = self
        table.delegate = self
        table.doubleAction = #selector(addSelected)
        table.target = self
        scroll.documentView = table
        root.addSubview(scroll)

        let addBtn = NSButton(title: "Add", target: self, action: #selector(addSelected))
        addBtn.translatesAutoresizingMaskIntoConstraints = false
        addBtn.bezelStyle = .rounded
        addBtn.keyEquivalent = "\r"
        root.addSubview(addBtn)

        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false
        cancelBtn.bezelStyle = .rounded
        cancelBtn.keyEquivalent = "\u{1b}"
        root.addSubview(cancelBtn)

        NSLayoutConstraint.activate([
            searchField.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            searchField.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
            searchField.topAnchor.constraint(equalTo: root.topAnchor, constant: 14),

            statusLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            statusLabel.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 6),

            scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
            scroll.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
            scroll.bottomAnchor.constraint(equalTo: addBtn.topAnchor, constant: -12),

            cancelBtn.trailingAnchor.constraint(equalTo: addBtn.leadingAnchor, constant: -8),
            cancelBtn.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -14),

            addBtn.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
            addBtn.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -14),
        ])

        return root
    }

    private func reloadAppsAsync() {
        statusLabel.stringValue = "Loading…"
        let watched = Set(preferences.watchedBundleIDs)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let apps = Self.scanInstalledApps(excluding: watched)
            DispatchQueue.main.async {
                guard let self else { return }
                self.allApps = apps
                self.applyFilter()
                self.statusLabel.stringValue = "\(apps.count) apps"
            }
        }
    }

    private func applyFilter() {
        let q = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty {
            filtered = allApps
        } else {
            filtered = allApps.filter {
                $0.name.lowercased().contains(q) || $0.bundleID.lowercased().contains(q)
            }
        }
        table.reloadData()
    }

    @objc private func searchChanged() {
        applyFilter()
    }

    @objc private func addSelected() {
        let indexes = table.selectedRowIndexes
        guard !indexes.isEmpty else {
            statusLabel.stringValue = "Pick app"
            return
        }
        var added = 0
        for idx in indexes {
            guard idx >= 0, idx < filtered.count else { continue }
            let app = filtered[idx]
            let before = Set(preferences.watchedBundleIDs)
            preferences.addWatchedBundleID(app.bundleID)
            WatchedAppsUserNames.set(app.name, for: app.bundleID)
            if !before.contains(app.bundleID) { added += 1 }
        }
        NotificationCenter.default.post(name: .kenglitPrefsChanged, object: nil)
        // Remove added from picker list
        let watched = Set(preferences.watchedBundleIDs)
        allApps = allApps.filter { !watched.contains($0.bundleID) }
        applyFilter()
        statusLabel.stringValue = added > 0 ? "+\(added)" : "None new"
        onAdded?()
    }

    @objc private func cancel() {
        window?.performClose(nil)
    }

    // MARK: - Scan like Finder Applications

    nonisolated private static func scanInstalledApps(excluding watched: Set<String>) -> [InstalledApp] {
        var roots = [
            "/Applications",
            NSString(string: "~/Applications").expandingTildeInPath,
            "/System/Applications",
            "/System/Applications/Utilities",
        ]
        // Also common dev locations
        roots.append(NSString(string: "~/Applications").expandingTildeInPath)

        var seen = Set<String>()
        var result: [InstalledApp] = []
        let fm = FileManager.default

        for root in roots {
            guard fm.fileExists(atPath: root) else { continue }
            guard let enumerator = fm.enumerator(
                at: URL(fileURLWithPath: root),
                includingPropertiesForKeys: [.isApplicationKey, .isDirectoryKey, .nameKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for case let url as URL in enumerator {
                // Only top-level .app and one level of folders (don't deep-dive into .app bundles)
                if url.pathExtension.lowercased() == "app" {
                    enumerator.skipDescendants()
                    if let app = makeInstalledApp(url: url),
                       !watched.contains(app.bundleID),
                       app.bundleID != "dev.finn.kenglit",
                       seen.insert(app.bundleID).inserted {
                        result.append(app)
                    }
                } else {
                    // Skip deep package contents
                    var isDir: ObjCBool = false
                    if fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                        // continue into folders like Utilities
                    }
                }
            }
        }

        // Prefer Launch Services known apps as supplement (covers /System apps better)
        // Also walk NSWorkspace - limited API, stick to folder scan.

        return result.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    nonisolated private static func makeInstalledApp(url: URL) -> InstalledApp? {
        let appURL = url
        let info = appURL.appendingPathComponent("Contents/Info.plist")
        let dict = NSDictionary(contentsOf: info) as? [String: Any]
        let bid = dict?["CFBundleIdentifier"] as? String
            ?? Bundle(url: appURL)?.bundleIdentifier
        guard let bundleID = bid, !bundleID.isEmpty else { return nil }

        let name = (dict?["CFBundleDisplayName"] as? String)
            ?? (dict?["CFBundleName"] as? String)
            ?? appURL.deletingPathExtension().lastPathComponent

        // Skip background helpers / XPC-ish if UIElement-only sometimes still show - keep simple.
        let icon = rasterIcon(forFile: appURL.path, point: 28)
        return InstalledApp(bundleID: bundleID, name: name, path: appURL.path, icon: icon)
    }

    nonisolated private static func rasterIcon(forFile path: String, point: CGFloat) -> NSImage {
        let source = NSWorkspace.shared.icon(forFile: path)
        let size = NSSize(width: point, height: point)
        let scale: CGFloat = 2.0
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(point * scale),
            pixelsHigh: Int(point * scale),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        if let ctx = NSGraphicsContext(bitmapImageRep: rep) {
            NSGraphicsContext.current = ctx
            source.draw(
                in: NSRect(origin: .zero, size: size),
                from: .zero,
                operation: .sourceOver,
                fraction: 1.0,
                respectFlipped: false,
                hints: [.interpolation: NSNumber(value: NSImageInterpolation.high.rawValue)]
            )
        }
        NSGraphicsContext.restoreGraphicsState()
        let out = NSImage(size: size)
        out.addRepresentation(rep)
        out.isTemplate = false
        return out
    }
}

extension AppPickerWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        onDone?()
    }
}

extension AppPickerWindowController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        filtered.count
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        40
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0, row < filtered.count else { return nil }
        let app = filtered[row]
        let id = NSUserInterfaceItemIdentifier("PickerCell")
        let cell: AppIconNameCell
        if let reused = tableView.makeView(withIdentifier: id, owner: nil) as? AppIconNameCell {
            cell = reused
        } else {
            cell = AppIconNameCell(frame: .zero)
            cell.identifier = id
        }
        cell.configure(icon: app.icon, name: app.name, toolTip: app.bundleID)
        return cell
    }
}
