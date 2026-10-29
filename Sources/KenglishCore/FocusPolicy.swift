public struct FocusDecision: Equatable {
    public let shouldSwitchToEnglish: Bool
    public let reason: String

    public init(shouldSwitchToEnglish: Bool, reason: String) {
        self.shouldSwitchToEnglish = shouldSwitchToEnglish
        self.reason = reason
    }
}

public enum FocusPolicy {
    public static func decide(
        isEnabled: Bool,
        frontBundleID: String?,
        watched: Set<String>,
        currentIsEnglish: Bool
    ) -> FocusDecision {
        guard isEnabled else {
            return FocusDecision(shouldSwitchToEnglish: false, reason: "disabled")
        }
        guard let id = frontBundleID, !id.isEmpty else {
            return FocusDecision(shouldSwitchToEnglish: false, reason: "no-front-app")
        }
        guard watched.contains(id) else {
            return FocusDecision(shouldSwitchToEnglish: false, reason: "unwatched")
        }
        if currentIsEnglish {
            return FocusDecision(shouldSwitchToEnglish: false, reason: "already-english")
        }
        return FocusDecision(shouldSwitchToEnglish: true, reason: "watched-needs-english")
    }
}
