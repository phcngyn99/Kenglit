public enum VietnameseSourceResolver {
    /// Prefer Telex simple IM (common macOS default), then other vi sources.
    public static let preferredIDs: [String] = [
        "com.apple.inputmethod.VietnameseIM.VietnameseSimpleTelex",
        "com.apple.inputmethod.VietnameseIM.VietnameseTelex",
        "com.apple.inputmethod.VietnameseIM.VietnameseSimpleVNI",
        "com.apple.inputmethod.VietnameseIM.VietnameseVNI",
        "com.apple.keylayout.Vietnamese",
    ]

    public static func resolvePreferredID(
        availableIDs: [String],
        languagesByID: [String: [String]]
    ) -> String? {
        let set = Set(availableIDs)
        for id in preferredIDs {
            if set.contains(id) { return id }
        }
        for id in availableIDs {
            let lower = id.lowercased()
            if lower.contains("vietnamese") || lower.contains(".vi") {
                return id
            }
        }
        for id in availableIDs {
            let langs = languagesByID[id] ?? []
            if langs.contains(where: { $0.lowercased().hasPrefix("vi") }) {
                return id
            }
        }
        return nil
    }

    public static func isVietnameseID(
        _ id: String?,
        languagesByID: [String: [String]] = [:]
    ) -> Bool {
        guard let id else { return false }
        if preferredIDs.contains(id) { return true }
        let lower = id.lowercased()
        if lower.contains("vietnamese") { return true }
        let langs = languagesByID[id] ?? []
        return langs.contains(where: { $0.lowercased().hasPrefix("vi") })
    }
}
