import CoreGraphics
import Foundation

enum AutoscrollMode: Equatable {
    case inactive
    case initial
    case holding
    case toggled
}

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
    var deadZone: CGFloat = 15.0
    var horizontalScale: CGFloat = 74.0
    var verticalScale: CGFloat = 68.0
    var minimumStep: CGFloat = 3.6
    var launchBoost: CGFloat = 9.5
    var cruiseStep: CGFloat = 38.0
    var overflowGain: CGFloat = 14.0
    var maxStep: CGFloat = 72.0

    func effectiveSensitivity(from configuredValue: Double) -> CGFloat {
        if configuredValue < 1.0 {
            return CGFloat(pow(configuredValue, 1.5))
        }
        return CGFloat(configuredValue)
    }

    func exceededDeadZone(_ pointerOffset: CGSize) -> Bool {
        abs(pointerOffset.width) > deadZone || abs(pointerOffset.height) > deadZone
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
                invertDirection: false
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

        let normalizedDistance = min(distance / scale, 1.0)
        let launchDistance = max(scale * 0.2, 1)
        let launchBlend = min(distance / launchDistance, 1.0)
        let earlyResponse = easeOutQuart(launchBlend)
        let cruiseResponse = easeOutCubic(normalizedDistance)

        var magnitude = minimumStep
        magnitude += launchBoost * earlyResponse
        magnitude += max(0, cruiseStep - minimumStep - launchBoost) * cruiseResponse

        let overflowDistance = max(0, distance - scale)
        if overflowDistance > 0 {
            magnitude += pow(overflowDistance / scale, 1.05) * overflowGain
        }

        var signedVelocity = min(magnitude, maxStep) * adjustedSensitivity
        signedVelocity *= delta > 0 ? 1 : -1
        if invertDirection {
            signedVelocity *= -1
        }

        let threshold = min(0.1, adjustedSensitivity * 0.5)
        return abs(signedVelocity) < threshold ? 0 : signedVelocity
    }

    private func easeOutCubic(_ value: CGFloat) -> CGFloat {
        let clamped = min(max(value, 0), 1)
        let inverse = 1 - clamped
        return 1 - (inverse * inverse * inverse)
    }

    private func easeOutQuart(_ value: CGFloat) -> CGFloat {
        let clamped = min(max(value, 0), 1)
        let inverse = 1 - clamped
        return 1 - (inverse * inverse * inverse * inverse)
    }
}

enum AutoscrollTargetBehavior: Equatable {
    case startAutoscroll
    case passThrough
    case undetermined
}

struct AutoscrollTargetSnapshot: Equatable {
    var roles: [String]
    var subroles: [String]
    var isExplicitlyScrollable: Bool
    var actions: [String] = []
    var title: String? = nil
    var identifier: String? = nil
    var helpText: String? = nil
    var valueText: String? = nil

    var primaryRole: String? {
        roles.first
    }
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

    static let strongScrollableRoles: Set<String> = [
        "AXBrowser",
        "AXList",
        "AXOutline",
        "AXTable",
        "AXTextArea"
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

    static let actionableMetadataTokens: [String] = [
        "back",
        "button",
        "card",
        "chrome",
        "close",
        "forward",
        "link",
        "nav",
        "navigation",
        "post",
        "sidebar",
        "tab",
        "tabbar",
        "tabstrip",
        "thread",
        "toolbar",
        "tweet",
        "workspace"
    ]

    static func behavior(for snapshot: AutoscrollTargetSnapshot) -> AutoscrollTargetBehavior {
        if snapshot.roles.contains(where: actionableRoles.contains) {
            return .passThrough
        }

        if snapshot.subroles.contains(where: actionableSubroles.contains) {
            return .passThrough
        }

        if hasStrongActionableMetadata(snapshot) {
            return .passThrough
        }

        if snapshot.roles.contains("AXTextField") {
            return .undetermined
        }

        if hasGenericAction(snapshot) {
            return .undetermined
        }

        if snapshot.isExplicitlyScrollable {
            return .startAutoscroll
        }

        if snapshot.roles.contains("AXWebArea") {
            return .startAutoscroll
        }

        if snapshot.roles.contains(where: strongScrollableRoles.contains) {
            return .startAutoscroll
        }

        if snapshot.primaryRole == "AXScrollArea" {
            return .undetermined
        }

        return .undetermined
    }

    static func fallbackAxes(for snapshot: AutoscrollTargetSnapshot) -> AutoscrollAxes {
        if snapshot.roles.contains("AXTextField") {
            return .none
        }

        if snapshot.roles.contains("AXWebArea") {
            return .both
        }

        if snapshot.roles.contains(where: strongScrollableRoles.contains) {
            return AutoscrollAxes(horizontal: false, vertical: true)
        }

        return .none
    }

    static func hasGenericAction(_ snapshot: AutoscrollTargetSnapshot) -> Bool {
        let normalizedActions = Set(snapshot.actions.map(normalizeToken))
        return !normalizedActions.isDisjoint(with: genericActionNames)
    }

    static func hasStrongActionableMetadata(_ snapshot: AutoscrollTargetSnapshot) -> Bool {
        guard hasGenericAction(snapshot) else {
            return false
        }

        let metadata = normalizeText([
            snapshot.title,
            snapshot.identifier,
            snapshot.helpText,
            snapshot.valueText
        ].compactMap { $0 }.joined(separator: " "))

        guard !metadata.isEmpty else {
            return false
        }

        return actionableMetadataTokens.contains(where: metadata.contains)
    }

    static func normalizeToken(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func normalizeText(_ value: String) -> String {
        let scalars = value.lowercased().unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(String(scalar)) : " "
        }
        return String(scalars)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}

struct AutoscrollModeMachine {
    private(set) var mode: AutoscrollMode = .inactive

    init(mode: AutoscrollMode = .inactive) {
        self.mode = mode
    }

    mutating func start() {
        mode = .initial
    }

    mutating func notePointerOffset(_ pointerOffset: CGSize, physics: AutoscrollPhysics) {
        guard mode == .initial, physics.exceededDeadZone(pointerOffset) else { return }
        mode = .holding
    }

    mutating func activationButtonReleased() -> Bool {
        switch mode {
        case .initial:
            mode = .toggled
            return false
        case .holding:
            mode = .inactive
            return true
        case .inactive, .toggled:
            return false
        }
    }
}

struct AutoscrollSession {
    var anchorPoint: CGPoint
    var deliveryPoint: CGPoint
    var targetPID: pid_t?
    var canScrollHorizontally: Bool
    var canScrollVertically: Bool
    var activationButtonNumber: Int
    var mode: AutoscrollMode = .initial
    var velocity: AutoscrollVelocity = .zero
}

enum AutoscrollActivationDisposition {
    case passThrough
    case start(AutoscrollSession)
}

enum AutoscrollStopClickPolicy {
    static func shouldSwallow(buttonNumber: Int) -> Bool {
        buttonNumber == 0
    }
}

enum AutoscrollBehavior {
    static let activationDeadZone: CGFloat = 15.0
    private static let defaultPhysics = AutoscrollPhysics()

    static func transitionedMode(
        from mode: AutoscrollMode,
        anchorPoint: CGPoint,
        currentPoint: CGPoint,
        activationButtonIsDown: Bool
    ) -> AutoscrollMode {
        let pointerOffset = CGSize(
            width: currentPoint.x - anchorPoint.x,
            height: currentPoint.y - anchorPoint.y
        )

        var machine = AutoscrollModeMachine(mode: mode)
        machine.notePointerOffset(pointerOffset, physics: defaultPhysics)
        if !activationButtonIsDown {
            _ = machine.activationButtonReleased()
        }
        return machine.mode
    }

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
        target: AutoscrollVelocity
    ) -> AutoscrollVelocity {
        AutoscrollVelocity(
            horizontal: smoothAxis(previous: previous.horizontal, target: target.horizontal),
            vertical: smoothAxis(previous: previous.vertical, target: target.vertical)
        )
    }

    private static func smoothAxis(previous: CGFloat, target: CGFloat) -> CGFloat {
        let blend: CGFloat
        if target == 0 {
            blend = 0.28
        } else if previous == 0 || (previous > 0) != (target > 0) {
            blend = 0.82
        } else if abs(target) > abs(previous) {
            blend = 0.7
        } else {
            blend = 0.4
        }

        let value = previous + ((target - previous) * blend)
        return abs(value) < 0.35 ? 0 : value
    }
}
