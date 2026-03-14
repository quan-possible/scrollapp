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

    @Test func classifierPassesThroughDirectGenericActionOutsideWebContent() {
        let behavior = AutoscrollTargetClassifier.behavior(
            for: AutoscrollTargetSnapshot(
                roles: ["AXGroup"],
                subroles: [],
                isExplicitlyScrollable: false,
                actions: ["AXPress"]
            )
        )

        #expect(behavior == .passThrough)
    }

    @Test func classifierStartsGenericPressInsideWebContent() {
        let behavior = AutoscrollTargetClassifier.behavior(
            for: AutoscrollTargetSnapshot(
                roles: ["AXGroup", "AXWebArea"],
                subroles: [],
                isExplicitlyScrollable: false,
                actions: ["AXPress"]
            )
        )

        #expect(behavior == .startAutoscroll)
    }

    @Test func classifierPassesThroughDirectLinkedContainerInsideWebArea() {
        let behavior = AutoscrollTargetClassifier.behavior(
            for: AutoscrollTargetSnapshot(
                roles: ["AXGroup", "AXWebArea"],
                subroles: [],
                isExplicitlyScrollable: false,
                linkedAncestorDepth: 0
            )
        )

        #expect(behavior == .passThrough)
    }

    @Test func classifierPassesThroughTextInsideNearbyLinkedContainer() {
        let behavior = AutoscrollTargetClassifier.behavior(
            for: AutoscrollTargetSnapshot(
                roles: ["AXStaticText", "AXGroup", "AXWebArea"],
                subroles: [],
                isExplicitlyScrollable: false,
                linkedAncestorDepth: 1
            )
        )

        #expect(behavior == .passThrough)
    }

    @Test func classifierPassesThroughGroupInsideNearbyLinkedContainer() {
        let behavior = AutoscrollTargetClassifier.behavior(
            for: AutoscrollTargetSnapshot(
                roles: ["AXGroup", "AXGroup", "AXWebArea"],
                subroles: [],
                isExplicitlyScrollable: false,
                linkedAncestorDepth: 2
            )
        )

        #expect(behavior == .passThrough)
    }

    @Test func classifierPassesThroughTextInsideNearbyActionableContainer() {
        let behavior = AutoscrollTargetClassifier.behavior(
            for: AutoscrollTargetSnapshot(
                roles: ["AXStaticText", "AXGroup", "AXWebArea"],
                subroles: [],
                isExplicitlyScrollable: false,
                actionableAncestorDepth: 1
            )
        )

        #expect(behavior == .passThrough)
    }

    @Test func classifierStartsPlainLeafContentInsideWebArea() {
        let behavior = AutoscrollTargetClassifier.behavior(
            for: AutoscrollTargetSnapshot(
                roles: ["AXStaticText", "AXGroup", "AXWebArea"],
                subroles: [],
                isExplicitlyScrollable: false
            )
        )

        #expect(behavior == .startAutoscroll)
    }

    @Test func classifierStartsPlainGroupContentInsideWebArea() {
        let behavior = AutoscrollTargetClassifier.behavior(
            for: AutoscrollTargetSnapshot(
                roles: ["AXGroup", "AXWebArea"],
                subroles: [],
                isExplicitlyScrollable: false
            )
        )

        #expect(behavior == .startAutoscroll)
    }

    @Test func classifierIgnoresDistantLinkedAncestorInsideWebArea() {
        let behavior = AutoscrollTargetClassifier.behavior(
            for: AutoscrollTargetSnapshot(
                roles: ["AXStaticText", "AXGroup", "AXGroup", "AXWebArea"],
                subroles: [],
                isExplicitlyScrollable: false,
                linkedAncestorDepth: 5
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

    @Test func appLayerIgnoresPageLevelURLAncestorsForLinkedPassThrough() {
        let delegate = AppDelegate()

        #expect(delegate.isLinkedAncestor(role: "AXWebArea", urlString: "https://example.com") == false)
        #expect(delegate.isLinkedAncestor(role: "AXWindow", urlString: "https://example.com") == false)
    }

    @Test func appLayerKeepsGenericURLBackedContainersLinked() {
        let delegate = AppDelegate()

        #expect(delegate.isLinkedAncestor(role: "AXGroup", urlString: "https://example.com"))
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

        #expect(shortMove.horizontal > 0)
        #expect(mediumMove.horizontal > shortMove.horizontal)
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
}
