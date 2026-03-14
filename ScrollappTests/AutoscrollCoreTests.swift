import CoreGraphics
import Testing
@testable import Scrollapp

struct AutoscrollCoreTests {

    @Test func classifierPassesThroughLinks() {
        let behavior = AutoscrollTargetClassifier.behavior(
            for: AutoscrollTargetSnapshot(
                roles: ["AXLink", "AXWebArea"],
                subroles: [],
                isExplicitlyScrollable: true
            )
        )

        #expect(behavior == .passThrough)
    }

    @Test func classifierPassesThroughGenericTabChromeWithMetadata() {
        let behavior = AutoscrollTargetClassifier.behavior(
            for: AutoscrollTargetSnapshot(
                roles: ["AXGroup"],
                subroles: [],
                isExplicitlyScrollable: false,
                actions: ["AXPress"],
                title: "Close tab"
            )
        )

        #expect(behavior == .passThrough)
    }

    @Test func classifierKeepsGenericPressWithoutStrongMetadataUndetermined() {
        let behavior = AutoscrollTargetClassifier.behavior(
            for: AutoscrollTargetSnapshot(
                roles: ["AXGroup"],
                subroles: [],
                isExplicitlyScrollable: false,
                actions: ["AXPress"],
                title: "Editor"
            )
        )

        #expect(behavior == .undetermined)
    }

    @Test func classifierStartsLeafContentInsideWebArea() {
        let behavior = AutoscrollTargetClassifier.behavior(
            for: AutoscrollTargetSnapshot(
                roles: ["AXStaticText", "AXGroup", "AXWebArea"],
                subroles: [],
                isExplicitlyScrollable: false
            )
        )

        #expect(behavior == .startAutoscroll)
    }

    @Test func classifierTreatsTextFieldInsideWebAreaAsUndetermined() {
        let behavior = AutoscrollTargetClassifier.behavior(
            for: AutoscrollTargetSnapshot(
                roles: ["AXTextField", "AXWebArea"],
                subroles: [],
                isExplicitlyScrollable: false
            )
        )

        #expect(behavior == .undetermined)
    }

    @Test func fallbackAxesUseWebAreaAncestry() {
        let axes = AutoscrollTargetClassifier.fallbackAxes(
            for: AutoscrollTargetSnapshot(
                roles: ["AXStaticText", "AXGroup", "AXWebArea"],
                subroles: [],
                isExplicitlyScrollable: false
            )
        )

        #expect(axes == .both)
    }

    @Test func physicsUsesDeadZone() {
        let physics = AutoscrollPhysics(deadZone: 15)
        let velocity = physics.velocity(
            from: CGSize(width: 10, height: 10),
            sensitivity: 1.0,
            invertVertical: false,
            axes: .both
        )

        #expect(velocity == .zero)
    }

    @Test func physicsStartsImmediatelyOutsideDeadZone() {
        let physics = AutoscrollPhysics(deadZone: 15)

        let nearEdge = physics.velocity(
            from: CGSize(width: 18, height: 0),
            sensitivity: 1.0,
            invertVertical: false,
            axes: .both
        )

        #expect(nearEdge.horizontal > 0)
        #expect(nearEdge.horizontal < 14)
    }

    @Test func physicsVelocityGrowsWithDistance() {
        let physics = AutoscrollPhysics(deadZone: 15)

        let shortMove = physics.velocity(
            from: CGSize(width: 28, height: 0),
            sensitivity: 1.0,
            invertVertical: false,
            axes: .both
        )
        let mediumMove = physics.velocity(
            from: CGSize(width: 55, height: 0),
            sensitivity: 1.0,
            invertVertical: false,
            axes: .both
        )
        let farMove = physics.velocity(
            from: CGSize(width: 140, height: 0),
            sensitivity: 1.0,
            invertVertical: false,
            axes: .both
        )

        #expect(shortMove.horizontal > 0)
        #expect(mediumMove.horizontal > shortMove.horizontal)
        #expect(farMove.horizontal > mediumMove.horizontal)
        #expect(farMove.horizontal <= physics.maxStep)
    }

    @Test func physicsHonorsAxisRestrictions() {
        let physics = AutoscrollPhysics(deadZone: 15)

        let horizontalOnly = physics.velocity(
            from: CGSize(width: 60, height: 60),
            sensitivity: 1.0,
            invertVertical: false,
            axes: AutoscrollAxes(horizontal: true, vertical: false)
        )
        let verticalOnly = physics.velocity(
            from: CGSize(width: 60, height: 60),
            sensitivity: 1.0,
            invertVertical: false,
            axes: AutoscrollAxes(horizontal: false, vertical: true)
        )

        #expect(horizontalOnly.horizontal != 0)
        #expect(horizontalOnly.vertical == 0)
        #expect(verticalOnly.horizontal == 0)
        #expect(verticalOnly.vertical != 0)
    }

    @Test func physicsRespectsVerticalInversion() {
        let physics = AutoscrollPhysics(deadZone: 15)

        let normal = physics.velocity(
            from: CGSize(width: 0, height: 80),
            sensitivity: 1.0,
            invertVertical: false,
            axes: .both
        )
        let inverted = physics.velocity(
            from: CGSize(width: 0, height: 80),
            sensitivity: 1.0,
            invertVertical: true,
            axes: .both
        )

        #expect(normal.vertical == -inverted.vertical)
    }

    @Test func modeMachineTransitionsToHoldingAfterDeadZoneCrossing() {
        let mode = AutoscrollBehavior.transitionedMode(
            from: .initial,
            anchorPoint: .zero,
            currentPoint: CGPoint(x: 20, y: 0),
            activationButtonIsDown: true
        )

        #expect(mode == .holding)
    }

    @Test func clickReleaseInsideDeadZoneBecomesToggled() {
        let mode = AutoscrollBehavior.transitionedMode(
            from: .initial,
            anchorPoint: .zero,
            currentPoint: CGPoint(x: 3, y: 3),
            activationButtonIsDown: false
        )

        #expect(mode == .toggled)
    }

    @Test func movePastDeadZoneThenReleaseStops() {
        let mode = AutoscrollBehavior.transitionedMode(
            from: .holding,
            anchorPoint: .zero,
            currentPoint: CGPoint(x: 30, y: 0),
            activationButtonIsDown: false
        )

        #expect(mode == .inactive)
    }

    @Test func stopClickPolicySwallowsPrimaryClickOnly() {
        #expect(AutoscrollStopClickPolicy.shouldSwallow(buttonNumber: 0))
        #expect(AutoscrollStopClickPolicy.shouldSwallow(buttonNumber: 1) == false)
    }

    @Test func smoothedVelocityRampsTowardTarget() {
        let smoothed = AutoscrollBehavior.smoothedVelocity(
            previous: .zero,
            target: AutoscrollVelocity(horizontal: 20, vertical: -12)
        )

        #expect(smoothed.horizontal > 0)
        #expect(smoothed.horizontal < 20)
        #expect(smoothed.vertical < 0)
        #expect(abs(smoothed.vertical) < 12)
    }

    @Test func smoothedVelocityDecaysTowardZero() {
        let smoothed = AutoscrollBehavior.smoothedVelocity(
            previous: AutoscrollVelocity(horizontal: 12, vertical: -8),
            target: .zero
        )

        #expect(smoothed.horizontal > 0)
        #expect(smoothed.horizontal < 12)
        #expect(smoothed.vertical < 0)
        #expect(abs(smoothed.vertical) < 8)
    }
}
