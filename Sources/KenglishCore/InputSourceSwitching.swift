public protocol InputSourceSwitching: AnyObject {
    func currentSourceID() -> String?
    /// Returns true if selection was attempted successfully (or already English).
    func selectEnglish() -> Bool
    func englishSourceAvailable() -> Bool
    func isEnglish(_ sourceID: String?) -> Bool
}
