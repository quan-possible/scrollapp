//
//  ScrollappTests.swift
//  ScrollappTests
//

import CoreGraphics
import Testing
@testable import Scrollapp

struct ScrollappTests {
    @Test func targetClassifierPassesThroughActionableTargets() async throws {
        let snapshot = AutoscrollTargetSnapshot(
            roles: ["AXGroup", "AXLink"],
            subroles: [],
            isExplicitlyScrollable: true
        )

        #expect(AutoscrollTargetClassifier.behavior(for: snapshot) == .passThrough)
    }

    @Test func targetClassifierStartsOnScrollableContent() async throws {
        let snapshot = AutoscrollTargetSnapshot(
            roles: ["AXWebArea", "AXGroup"],
            subroles: [],
            isExplicitlyScrollable: true
        )

        #expect(AutoscrollTargetClassifier.behavior(for: snapshot) == .startAutoscroll)
    }

    @Test func targetClassifierPassesThroughActionableSubrole() async throws {
        let snapshot = AutoscrollTargetSnapshot(
            roles: ["AXGroup"],
            subroles: ["AXCloseButton"],
            isExplicitlyScrollable: false
        )

        #expect(AutoscrollTargetClassifier.behavior(for: snapshot) == .passThrough)
    }

    @Test func modeMachineTransitionsToHoldingOutsideDeadZone() async throws {
        var machine = AutoscrollModeMachine()
        machine.start()
        let physics = AutoscrollPhysics(deadZone: 15)

        machine.notePointerOffset(CGSize(width: 20, height: 0), physics: physics)

        #expect(machine.mode == .holding)
    }

    @Test func modeMachineTogglesWhenActivationButtonReleasesInsideDeadZone() async throws {
        var machine = AutoscrollModeMachine()
        machine.start()

        let shouldStop = machine.activationButtonReleased()

        #expect(shouldStop == false)
        #expect(machine.mode == .toggled)
    }

    @Test func modeMachineStopsWhenActivationButtonReleasesAfterHolding() async throws {
        var machine = AutoscrollModeMachine()
        machine.start()
        let physics = AutoscrollPhysics(deadZone: 15)
        machine.notePointerOffset(CGSize(width: 25, height: 0), physics: physics)

        let shouldStop = machine.activationButtonReleased()

        #expect(shouldStop)
        #expect(machine.mode == .inactive)
    }

    @Test func velocityRespectsDeadZone() async throws {
        let physics = AutoscrollPhysics(deadZone: 15)

        let velocity = physics.velocity(
            from: CGSize(width: 10, height: 12),
            sensitivity: 1.0,
            invertVertical: false,
            axes: .both
        )

        #expect(velocity == .zero)
    }

    @Test func velocityProducesHorizontalAndVerticalMotionOutsideDeadZone() async throws {
        let physics = AutoscrollPhysics(deadZone: 15)

        let velocity = physics.velocity(
            from: CGSize(width: 80, height: -120),
            sensitivity: 1.0,
            invertVertical: false,
            axes: .both
        )

        #expect(velocity.horizontal > 0)
        #expect(velocity.vertical > 0)
    }

    @Test func lowerSensitivityProducesSlowerMotion() async throws {
        let physics = AutoscrollPhysics(deadZone: 15)

        let slowVelocity = physics.velocity(
            from: CGSize(width: 0, height: 100),
            sensitivity: 0.4,
            invertVertical: false,
            axes: .both
        )

        let fastVelocity = physics.velocity(
            from: CGSize(width: 0, height: 100),
            sensitivity: 1.0,
            invertVertical: false,
            axes: .both
        )

        #expect(abs(slowVelocity.vertical) < abs(fastVelocity.vertical))
    }

    @Test func transitionedModePromotesInitialToHoldingAndPreservesToggledAfterRelease() async throws {
        let holding = AutoscrollBehavior.transitionedMode(
            from: .initial,
            anchorPoint: .zero,
            currentPoint: CGPoint(x: 25, y: 0),
            activationButtonIsDown: true
        )

        let stillToggled = AutoscrollBehavior.transitionedMode(
            from: .toggled,
            anchorPoint: .zero,
            currentPoint: CGPoint(x: 25, y: 0),
            activationButtonIsDown: false
        )

        #expect(holding == .holding)
        #expect(stillToggled == .toggled)
    }
}
