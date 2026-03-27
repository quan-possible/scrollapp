import CoreGraphics
import Foundation

struct AutoscrollAxes: Equatable {
    var horizontal: Bool
    var vertical: Bool

    static let none = AutoscrollAxes(horizontal: false, vertical: false)
    static let both = AutoscrollAxes(horizontal: true, vertical: true)
}

struct AutoscrollVelocity: Equatable {
    var horizontal: CGFloat
    var vertical: CGFloat

    static let zero = AutoscrollVelocity(horizontal: 0, vertical: 0)

    var isZero: Bool {
        horizontal == 0 && vertical == 0
    }
}

struct AutoscrollPhysics {
    static let `default` = AutoscrollPhysics()

    var deadZone: CGFloat = 5.0
    var horizontalScale: CGFloat = 50.0
    var verticalScale: CGFloat = 50.0
    var curveExponent: CGFloat = 2.2
    var quadraticGainPerSecond: CGFloat = 250.0
    var maxSpeedPerSecond: CGFloat = 9000.0

    func effectiveSensitivity(from configuredValue: Double) -> CGFloat {
        if configuredValue < 1.0 {
            return CGFloat(pow(configuredValue, 1.5))
        }
        return CGFloat(configuredValue)
    }

    func velocity(
        from pointerOffset: CGSize,
        sensitivity: Double,
        invertVertical: Bool,
        axes: AutoscrollAxes
    ) -> AutoscrollVelocity {
        let adjustedSensitivity = effectiveSensitivity(from: sensitivity)

        let horizontalVelocity = axes.horizontal
            ? axisVelocity(
                delta: pointerOffset.width,
                scale: horizontalScale,
                adjustedSensitivity: adjustedSensitivity,
                invertDirection: invertVertical
            )
            : 0

        let verticalVelocity = axes.vertical
            ? axisVelocity(
                delta: pointerOffset.height,
                scale: verticalScale,
                adjustedSensitivity: adjustedSensitivity,
                invertDirection: !invertVertical
            )
            : 0

        return AutoscrollVelocity(horizontal: horizontalVelocity, vertical: verticalVelocity)
    }

    private func axisVelocity(
        delta: CGFloat,
        scale: CGFloat,
        adjustedSensitivity: CGFloat,
        invertDirection: Bool
    ) -> CGFloat {
        let distance = max(0, abs(delta) - deadZone)
        guard distance > 0 else { return 0 }

        let normalizedDistance = distance / max(scale, 1)
        let magnitude = min(pow(normalizedDistance, curveExponent) * quadraticGainPerSecond, maxSpeedPerSecond)

        var signedVelocity = min(magnitude, maxSpeedPerSecond) * adjustedSensitivity
        signedVelocity *= delta > 0 ? 1 : -1
        if invertDirection {
            signedVelocity *= -1
        }

        let threshold = min(10.0, adjustedSensitivity * 25.0)
        return abs(signedVelocity) < threshold ? 0 : signedVelocity
    }
}

struct AutoscrollTargetResolution: Equatable {
    var shouldStart: Bool
    var fallbackAxes: AutoscrollAxes
}

struct AutoscrollTargetSnapshot: Equatable {
    var roles: [String]
    var subroles: [String]
    var isExplicitlyScrollable: Bool
    var actions: [String] = []
    var actionableAncestorDepth: Int? = nil
    var linkedAncestorDepth: Int? = nil
}

enum AutoscrollTargetClassifier {
    static let actionableRoles: Set<String> = [
        "AXButton",
        "AXCheckBox",
        "AXCloseButton",
        "AXDisclosureTriangle",
        "AXLink",
        "AXMenuBarItem",
        "AXMenuButton",
        "AXPopUpButton",
        "AXRadioButton",
        "AXSwitch",
        "AXTab",
        "AXToolbarButton"
    ]

    static let actionableSubroles: Set<String> = [
        "AXCloseButton",
        "AXDeleteButton",
        "AXFullScreenButton",
        "AXMinimizeButton",
        "AXOverflowButton",
        "AXTabButton",
        "AXZoomButton"
    ]

    static let compactTextInputRoles: Set<String> = [
        "AXTextField"
    ]

    static let compactTextInputSubroles: Set<String> = [
        "AXSearchField"
    ]

    static let genericActionNames: Set<String> = [
        "axconfirm",
        "axopen",
        "axpick",
        "axpress",
        "axshowdefaultui",
        "axshowmenu",
        "confirm",
        "open",
        "pick",
        "press",
        "showdefaultui",
        "showmenu"
    ]

    static let nearActionableAncestorDepthLimit = 2
    static let nearInteractiveAncestorDepthLimit = 3

    static func classify(_ snapshot: AutoscrollTargetSnapshot) -> AutoscrollTargetResolution {
        if isCompactTextInputControl(snapshot) {
            return AutoscrollTargetResolution(shouldStart: false, fallbackAxes: .none)
        }

        if isDirectlyActionable(snapshot) {
            return AutoscrollTargetResolution(shouldStart: false, fallbackAxes: .none)
        }

        if hasNearInteractiveAncestor(snapshot) {
            return AutoscrollTargetResolution(shouldStart: false, fallbackAxes: .none)
        }

        if hasDirectGenericAction(snapshot) {
            return AutoscrollTargetResolution(shouldStart: false, fallbackAxes: .none)
        }

        let fallbackAxes = inferredFallbackAxes(for: snapshot)
        return AutoscrollTargetResolution(shouldStart: true, fallbackAxes: fallbackAxes)
    }

    private static func inferredFallbackAxes(for snapshot: AutoscrollTargetSnapshot) -> AutoscrollAxes {
        if isCompactTextInputControl(snapshot) {
            return .none
        }

        if snapshot.isExplicitlyScrollable {
            return .none
        }

        return .both
    }

    static func hasGenericAction(_ snapshot: AutoscrollTargetSnapshot) -> Bool {
        let normalizedActions = Set(snapshot.actions.map(normalizeToken))
        return !normalizedActions.isDisjoint(with: genericActionNames)
    }

    static func hasNearInteractiveAncestor(_ snapshot: AutoscrollTargetSnapshot) -> Bool {
        if hasNearActionableAncestor(snapshot.actionableAncestorDepth) {
            return true
        }

        if hasNearLinkedAncestor(snapshot.linkedAncestorDepth) {
            return true
        }

        return false
    }

    static func hasDirectGenericAction(_ snapshot: AutoscrollTargetSnapshot) -> Bool {
        if isEditorLikeTextSurface(snapshot) {
            return false
        }
        return hasGenericAction(snapshot)
    }

    static func isCompactTextInputControl(_ snapshot: AutoscrollTargetSnapshot) -> Bool {
        if snapshot.roles.contains(where: compactTextInputRoles.contains) {
            return true
        }

        if snapshot.subroles.contains(where: compactTextInputSubroles.contains) {
            return true
        }

        return false
    }

    static func isEditorLikeTextSurface(_ snapshot: AutoscrollTargetSnapshot) -> Bool {
        snapshot.roles.contains("AXTextArea")
    }

    static func hasNearActionableAncestor(_ depth: Int?) -> Bool {
        guard let depth else {
            return false
        }

        return depth > 0 && depth <= nearActionableAncestorDepthLimit
    }

    static func hasNearLinkedAncestor(_ depth: Int?) -> Bool {
        guard let depth else {
            return false
        }

        return depth > 0 && depth <= nearInteractiveAncestorDepthLimit
    }

    static func isDirectlyActionable(_ snapshot: AutoscrollTargetSnapshot) -> Bool {
        if let primaryRole = snapshot.roles.first,
           actionableRoles.contains(primaryRole) {
            return true
        }

        if let primarySubrole = snapshot.subroles.first,
           actionableSubroles.contains(primarySubrole) {
            return true
        }

        if snapshot.actionableAncestorDepth == 0 || snapshot.linkedAncestorDepth == 0 {
            return true
        }

        return false
    }

    static func normalizeToken(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

struct AutoscrollSession {
    var anchorPoint: CGPoint
    var targetWindowID: CGWindowID?
    var canScrollHorizontally: Bool
    var canScrollVertically: Bool
    var activationButtonNumber: Int
    var velocity: AutoscrollVelocity = .zero
    var emissionCarry: AutoscrollVelocity = .zero
}

enum AutoscrollBehavior {
    private static let defaultPhysics = AutoscrollPhysics.default
    static let preferredTickInterval: TimeInterval = 1.0 / 100.0
    private static let defaultReleaseResponse: TimeInterval = 0.04
    private static let defaultTurnResponse: TimeInterval = 0.012
    private static let defaultAccelerationResponse: TimeInterval = 0.018
    private static let defaultDecelerationResponse: TimeInterval = 0.03

    static func velocity(
        anchorPoint: CGPoint,
        currentPoint: CGPoint,
        sensitivity: Double,
        invertVertical: Bool,
        axes: AutoscrollAxes = .both
    ) -> AutoscrollVelocity {
        defaultPhysics.velocity(
            from: CGSize(
                width: currentPoint.x - anchorPoint.x,
                height: currentPoint.y - anchorPoint.y
            ),
            sensitivity: sensitivity,
            invertVertical: invertVertical,
            axes: axes
        )
    }

    static func shouldEmitScroll(_ velocity: AutoscrollVelocity) -> Bool {
        !velocity.isZero
    }

    static func smoothedVelocity(
        previous: AutoscrollVelocity,
        target: AutoscrollVelocity,
        elapsedTime: TimeInterval = preferredTickInterval
    ) -> AutoscrollVelocity {
        AutoscrollVelocity(
            horizontal: smoothAxis(previous: previous.horizontal, target: target.horizontal, elapsedTime: elapsedTime),
            vertical: smoothAxis(previous: previous.vertical, target: target.vertical, elapsedTime: elapsedTime)
        )
    }

    static func normalizedElapsedTime(_ rawElapsedTime: TimeInterval?) -> TimeInterval {
        guard let rawElapsedTime,
              rawElapsedTime.isFinite,
              rawElapsedTime > 0 else {
            return preferredTickInterval
        }

        if rawElapsedTime < preferredTickInterval * 0.5 {
            return preferredTickInterval
        }

        return min(rawElapsedTime, 1.0 / 15.0)
    }

    static func emissionStep(
        velocity: AutoscrollVelocity,
        elapsedTime: TimeInterval,
        carry: AutoscrollVelocity
    ) -> (delta: AutoscrollVelocity, carry: AutoscrollVelocity) {
        let horizontal = emissionAxis(
            velocity: velocity.horizontal,
            elapsedTime: elapsedTime,
            carry: carry.horizontal
        )
        let vertical = emissionAxis(
            velocity: velocity.vertical,
            elapsedTime: elapsedTime,
            carry: carry.vertical
        )

        return (
            delta: AutoscrollVelocity(horizontal: horizontal.delta, vertical: vertical.delta),
            carry: AutoscrollVelocity(horizontal: horizontal.carry, vertical: vertical.carry)
        )
    }

    private static func smoothAxis(previous: CGFloat, target: CGFloat, elapsedTime: TimeInterval) -> CGFloat {
        let responseTime: TimeInterval
        if target == 0 {
            responseTime = defaultReleaseResponse
        } else if previous == 0 || (previous > 0) != (target > 0) {
            responseTime = defaultTurnResponse
        } else if abs(target) > abs(previous) {
            responseTime = defaultAccelerationResponse
        } else {
            responseTime = defaultDecelerationResponse
        }

        let clampedElapsedTime = normalizedElapsedTime(elapsedTime)
        let blend = CGFloat(1 - Foundation.exp(-clampedElapsedTime / responseTime))
        let value = previous + ((target - previous) * blend)
        return abs(value) < 0.35 ? 0 : value
    }

    private static func emissionAxis(
        velocity: CGFloat,
        elapsedTime: TimeInterval,
        carry: CGFloat
    ) -> (delta: CGFloat, carry: CGFloat) {
        let exactDelta = (velocity * CGFloat(elapsedTime)) + carry
        let roundedDelta = exactDelta.rounded()
        return (delta: roundedDelta, carry: exactDelta - roundedDelta)
    }
}
