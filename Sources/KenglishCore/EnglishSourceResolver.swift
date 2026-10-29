public enum EnglishSourceResolver {
    public static let abcID = "com.apple.keylayout.ABC"
    public static let usID = "com.apple.keylayout.US"

    public static func resolvePreferredID(
        availableIDs: [String],
        languagesByID: [String: [String]]
    ) -> String? {
        let set = Set(availableIDs)
        if set.contains(abcID) { return abcID }
        if set.contains(usID) { return usID }
        for id in availableIDs {
            let langs = languagesByID[id] ?? []
            if langs.contains(where: { $0.lowercased().hasPrefix("en") }) {
                return id
            }
        }
        return nil
    }

    public static func isEnglishID(
        _ id: String?,
        languagesByID: [String: [String]] = [:]
    ) -> Bool {
        guard let id else { return false }
        if id == abcID || id == usID { return true }
        let langs = languagesByID[id] ?? []
        return langs.contains(where: { $0.lowercased().hasPrefix("en") })
    }
}
