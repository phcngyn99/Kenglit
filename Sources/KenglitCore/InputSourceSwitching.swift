public protocol InputSourceSwitching: AnyObject {
    func currentSourceID() -> String?

    @discardableResult
    func selectEnglish() -> Bool

    @discardableResult
    func selectVietnamese() -> Bool

    func englishSourceAvailable() -> Bool
    func vietnameseSourceAvailable() -> Bool

    func isEnglish(_ sourceID: String?) -> Bool
    func isVietnamese(_ sourceID: String?) -> Bool
}
