import Foundation
import Carbon
import KenglitCore

final class CarbonInputSourceSwitcher: InputSourceSwitching {
    func currentSourceID() -> String? {
        guard let src = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return nil
        }
        return Self.stringProperty(src, key: kTISPropertyInputSourceID)
    }

    func englishSourceAvailable() -> Bool {
        preferredEnglishSource() != nil
    }

    func vietnameseSourceAvailable() -> Bool {
        preferredVietnameseSource() != nil
    }

    func isEnglish(_ sourceID: String?) -> Bool {
        EnglishSourceResolver.isEnglishID(sourceID, languagesByID: languagesByID())
    }

    func isVietnamese(_ sourceID: String?) -> Bool {
        VietnameseSourceResolver.isVietnameseID(sourceID, languagesByID: languagesByID())
    }

    @discardableResult
    func selectEnglish() -> Bool {
        if isEnglish(currentSourceID()) { return true }
        guard let src = preferredEnglishSource() else { return false }
        return TISSelectInputSource(src) == noErr
    }

    @discardableResult
    func selectVietnamese() -> Bool {
        if isVietnamese(currentSourceID()) { return true }
        guard let src = preferredVietnameseSource() else { return false }
        return TISSelectInputSource(src) == noErr
    }

    private func preferredEnglishSource() -> TISInputSource? {
        let sources = enabledSources()
        let ids = sources.compactMap { Self.stringProperty($0, key: kTISPropertyInputSourceID) }
        let langs = languagesByID(from: sources)
        guard let preferred = EnglishSourceResolver.resolvePreferredID(
            availableIDs: ids,
            languagesByID: langs
        ) else { return nil }
        return sources.first {
            Self.stringProperty($0, key: kTISPropertyInputSourceID) == preferred
        }
    }

    private func preferredVietnameseSource() -> TISInputSource? {
        let sources = enabledSources()
        let ids = sources.compactMap { Self.stringProperty($0, key: kTISPropertyInputSourceID) }
        let langs = languagesByID(from: sources)
        guard let preferred = VietnameseSourceResolver.resolvePreferredID(
            availableIDs: ids,
            languagesByID: langs
        ) else { return nil }
        return sources.first {
            Self.stringProperty($0, key: kTISPropertyInputSourceID) == preferred
        }
    }

    private func enabledSources() -> [TISInputSource] {
        let keys = [kTISPropertyInputSourceIsEnabled: true] as CFDictionary
        guard let list = TISCreateInputSourceList(keys, false)?.takeRetainedValue() as? [TISInputSource] else {
            return []
        }
        return list.filter {
            Self.stringProperty($0, key: kTISPropertyInputSourceCategory) ==
                String(kTISCategoryKeyboardInputSource)
        }
    }

    private func languagesByID(from sources: [TISInputSource]? = nil) -> [String: [String]] {
        let srcs = sources ?? enabledSources()
        var map: [String: [String]] = [:]
        for src in srcs {
            guard let id = Self.stringProperty(src, key: kTISPropertyInputSourceID) else { continue }
            if let langs = Self.arrayProperty(src, key: kTISPropertyInputSourceLanguages) as? [String] {
                map[id] = langs
            }
        }
        return map
    }

    private static func stringProperty(_ src: TISInputSource, key: CFString) -> String? {
        guard let ptr = TISGetInputSourceProperty(src, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }

    private static func arrayProperty(_ src: TISInputSource, key: CFString) -> NSArray? {
        guard let ptr = TISGetInputSourceProperty(src, key) else { return nil }
        return Unmanaged<CFArray>.fromOpaque(ptr).takeUnretainedValue() as NSArray
    }
}
