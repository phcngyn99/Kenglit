public enum FocusAction: Equatable {
    case none
    case switchToEnglish
    case switchToVietnamese
}

public struct FocusDecision: Equatable {
    public let action: FocusAction
    public let reason: String

    public init(action: FocusAction, reason: String) {
        self.action = action
        self.reason = reason
    }

    public var shouldSwitchToEnglish: Bool { action == .switchToEnglish }
    public var shouldSwitchToVietnamese: Bool { action == .switchToVietnamese }
}

public enum FocusPolicy {
    public static func decide(
        isEnabled: Bool,
        frontBundleID: String?,
        watched: Set<String>,
        currentIsEnglish: Bool,
        currentIsVietnamese: Bool
    ) -> FocusDecision {
        guard isEnabled else {
            return FocusDecision(action: .none, reason: "disabled")
        }
        guard let id = frontBundleID, !id.isEmpty else {
            return FocusDecision(action: .none, reason: "no-front-app")
        }

        if watched.contains(id) {
            if currentIsEnglish {
                return FocusDecision(action: .none, reason: "watched-already-english")
            }
            return FocusDecision(action: .switchToEnglish, reason: "watched-needs-english")
        }

        if currentIsVietnamese {
            return FocusDecision(action: .none, reason: "unwatched-already-vietnamese")
        }
        return FocusDecision(action: .switchToVietnamese, reason: "unwatched-needs-vietnamese")
    }
}
