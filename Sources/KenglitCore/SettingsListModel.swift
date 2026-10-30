import Foundation

public struct SettingsListModel: Equatable {
    public enum Section: String, Equatable {
        case custom
        case builtIn
    }

    public enum Row: Equatable {
        case header(Section, title: String, expanded: Bool)
        case app(bundleID: String)
        case empty(String)
    }

    public var customExpanded: Bool
    public var builtInExpanded: Bool
    public var filter: String

    public init(
        customExpanded: Bool = true,
        builtInExpanded: Bool = true,
        filter: String = ""
    ) {
        self.customExpanded = customExpanded
        self.builtInExpanded = builtInExpanded
        self.filter = filter
    }

    public mutating func toggle(_ section: Section) {
        switch section {
        case .custom: customExpanded.toggle()
        case .builtIn: builtInExpanded.toggle()
        }
    }

    public mutating func expandSectionsMatching(
        customIDs: [String],
        builtInIDs: [String],
        name: (String) -> String
    ) {
        let q = filter.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return }
        if customIDs.contains(where: { matches($0, q: q, name: name) }) {
            customExpanded = true
        }
        if builtInIDs.contains(where: { matches($0, q: q, name: name) }) {
            builtInExpanded = true
        }
    }

    public func rows(
        customIDs: [String],
        builtInIDs: [String],
        name: (String) -> String
    ) -> [Row] {
        let q = filter.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let custom = customIDs.filter { matches($0, q: q, name: name) }
        let builtIn = builtInIDs.filter { matches($0, q: q, name: name) }

        var out: [Row] = []
        out.append(.header(.custom, title: "User Apps", expanded: customExpanded))
        if customExpanded {
            if custom.isEmpty {
                out.append(.empty(q.isEmpty ? "No user apps added." : "No matching applications."))
            } else {
                for bid in custom { out.append(.app(bundleID: bid)) }
            }
        }

        out.append(.header(.builtIn, title: "Built-in Apps", expanded: builtInExpanded))
        if builtInExpanded {
            if builtIn.isEmpty {
                out.append(.empty(q.isEmpty ? "No built-in apps." : "No matching applications."))
            } else {
                for bid in builtIn { out.append(.app(bundleID: bid)) }
            }
        }
        return out
    }

    public static func sectionOwning(row: Int, in rows: [Row]) -> Section? {
        var i = row
        while i >= 0 {
            if case let .header(section, _, _) = rows[i] { return section }
            i -= 1
        }
        return nil
    }

    public static func handleRowClick(_ row: Int, in rows: [Row]) -> Section? {
        guard row >= 0, row < rows.count else { return nil }
        switch rows[row] {
        case let .header(section, _, _):
            return section
        case .empty:
            return sectionOwning(row: row, in: rows)
        case .app:
            return nil
        }
    }

    private func matches(_ bid: String, q: String, name: (String) -> String) -> Bool {
        guard !q.isEmpty else { return true }
        return name(bid).lowercased().contains(q) || bid.lowercased().contains(q)
    }
}
