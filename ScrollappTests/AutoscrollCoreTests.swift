import Cocoa
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

    @Test func classifierPassesThroughDirectGenericActionInsideWebContent() {
        let behavior = AutoscrollTargetClassifier.behavior(
            for: AutoscrollTargetSnapshot(
                roles: ["AXGroup", "AXWebArea"],
                subroles: [],
                isExplicitlyScrollable: false,
                actions: ["AXPress"]
            )
        )

        #expect(behavior == .passThrough)
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

    @Test func classifierStartsPlainGroupContentOutsideWebArea() {
        let behavior = AutoscrollTargetClassifier.behavior(
            for: AutoscrollTargetSnapshot(
                roles: ["AXGroup"],
                subroles: [],
                isExplicitlyScrollable: false
            )
        )

        #expect(behavior == .startAutoscroll)
    }

    @Test func classifierUsesBidirectionalFallbackAxesForPlainGroupOutsideWebArea() {
        let axes = AutoscrollTargetClassifier.fallbackAxes(
            for: AutoscrollTargetSnapshot(
                roles: ["AXGroup"],
                subroles: [],
                isExplicitlyScrollable: false
            )
        )

        #expect(axes == .both)
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

    @Test func classifierPassesThroughCompactTextFieldInsideWebArea() {
        let behavior = AutoscrollTargetClassifier.behavior(
            for: AutoscrollTargetSnapshot(
                roles: ["AXTextField", "AXWebArea"],
                subroles: [],
                isExplicitlyScrollable: false
            )
        )

        #expect(behavior == .passThrough)
    }

    @Test func classifierStartsEditorLikeTextArea() {
        let behavior = AutoscrollTargetClassifier.behavior(
            for: AutoscrollTargetSnapshot(
                roles: ["AXTextArea"],
                subroles: [],
                isExplicitlyScrollable: true
            )
        )

        #expect(behavior == .startAutoscroll)
    }

    @Test func classifierStartsEditorLikeTextAreaEvenWithGenericAction() {
        let behavior = AutoscrollTargetClassifier.behavior(
            for: AutoscrollTargetSnapshot(
                roles: ["AXTextArea"],
                subroles: [],
                isExplicitlyScrollable: false,
                actions: ["AXPress"]
            )
        )

        #expect(behavior == .startAutoscroll)
    }

    @Test func classifierStartsScrollAreaTargets() {
        let behavior = AutoscrollTargetClassifier.behavior(
            for: AutoscrollTargetSnapshot(
                roles: ["AXScrollArea"],
                subroles: [],
                isExplicitlyScrollable: false
            )
        )

        #expect(behavior == .startAutoscroll)
    }

    @Test func fallbackAxesUseBidirectionalFallbackForScrollArea() {
        let axes = AutoscrollTargetClassifier.fallbackAxes(
            for: AutoscrollTargetSnapshot(
                roles: ["AXScrollArea"],
                subroles: [],
                isExplicitlyScrollable: false
            )
        )

        #expect(axes == .both)
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

    @Test func fallbackAxesDoNotOverrideExplicitScrollAxes() {
        let axes = AutoscrollTargetClassifier.fallbackAxes(
            for: AutoscrollTargetSnapshot(
                roles: ["AXGroup"],
                subroles: [],
                isExplicitlyScrollable: true
            )
        )

        #expect(axes == .none)
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

    @Test func physicsVelocityGrowsWithDistanceAndUsesFlippedHorizontalDirection() {
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

        #expect(shortMove.horizontal < 0)
        #expect(abs(mediumMove.horizontal) > abs(shortMove.horizontal))
    }

    @Test func invertDirectionToggleFlipsBothHorizontalAndVerticalAxes() {
        let physics = AutoscrollPhysics(deadZone: 15)

        let normalDirection = physics.velocity(
            from: CGSize(width: 40, height: 40),
            sensitivity: 1.0,
            invertVertical: false,
            axes: .both
        )
        let invertedDirection = physics.velocity(
            from: CGSize(width: 40, height: 40),
            sensitivity: 1.0,
            invertVertical: true,
            axes: .both
        )

        #expect(normalDirection.horizontal == -invertedDirection.horizontal)
        #expect(normalDirection.vertical == -invertedDirection.vertical)
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

    @MainActor
    @Test func syntheticPixelWheelEventChangesRealScrollViewOffset() {
        let harness = ScrollObservationHarness()
        harness.setVerticalOffset(320)
        let initialOffset = harness.verticalOffset
        guard let scrollEvent = makeScrollEvent(verticalAmount: -120) else {
            Issue.record("Failed to create synthetic scroll event")
            return
        }
        harness.apply(scrollEvent)
        #expect(harness.verticalOffset != initialOffset)
    }

    @MainActor
    @Test func syntheticPixelWheelEventChangesRealScrollViewHorizontalOffset() {
        let harness = ScrollObservationHarness()
        harness.setHorizontalOffset(320)
        let initialOffset = harness.horizontalOffset
        guard let scrollEvent = makeScrollEvent(verticalAmount: 0, horizontalAmount: -120) else {
            Issue.record("Failed to create synthetic horizontal scroll event")
            return
        }
        harness.apply(scrollEvent)
        #expect(harness.horizontalOffset != initialOffset)
    }

    @MainActor
    @Test func sessionTapFallbackDeliveryChangesRealScrollViewOffset() throws {
        guard let capture = try? ScrollEventCapture() else {
            return
        }
        defer { capture.stop() }

        let delegate = AppDelegate()
        let session = AutoscrollSession(
            anchorPoint: CGPoint(x: 120, y: 120),
            deliveryPoint: CGPoint(x: 120, y: 120),
            targetPID: nil,
            targetWindowID: nil,
            latchedScrollOwner: nil,
            canScrollHorizontally: false,
            canScrollVertically: true,
            activationButtonNumber: 2
        )
        guard let scrollEvent = makeScrollEvent(verticalAmount: -120) else {
            Issue.record("Failed to create synthetic scroll event")
            return
        }

        scrollEvent.location = CGPoint(x: 280, y: 120)
        markAsSyntheticScroll(scrollEvent)
        delegate.deliverScrollEvent(
            scrollEvent,
            session: session,
            horizontalAmount: 0,
            verticalAmount: -120
        )

        let deliveredEvent = try #require(capture.waitForEvent())
        #expect(deliveredEvent.location == CGPoint(x: 280, y: 120))

        let harness = ScrollObservationHarness()
        harness.setVerticalOffset(320)
        let initialOffset = harness.verticalOffset
        harness.apply(deliveredEvent)

        #expect(harness.verticalOffset != initialOffset)
    }

    @MainActor
    @Test func currentProcessDeliveryChangesRealScrollViewOffset() throws {
        guard let capture = try? ScrollEventCapture() else {
            return
        }
        defer { capture.stop() }

        let delegate = AppDelegate()
        let session = AutoscrollSession(
            anchorPoint: CGPoint(x: 120, y: 120),
            deliveryPoint: CGPoint(x: 120, y: 120),
            targetPID: getpid(),
            targetWindowID: nil,
            latchedScrollOwner: nil,
            canScrollHorizontally: false,
            canScrollVertically: true,
            activationButtonNumber: 2
        )
        guard let scrollEvent = makeScrollEvent(verticalAmount: -120) else {
            Issue.record("Failed to create synthetic scroll event")
            return
        }

        scrollEvent.location = CGPoint(x: 280, y: 120)
        markAsSyntheticScroll(scrollEvent)
        delegate.deliverScrollEvent(
            scrollEvent,
            session: session,
            horizontalAmount: 0,
            verticalAmount: -120
        )

        let deliveredEvent = try #require(capture.waitForEvent())
        #expect(deliveredEvent.location == CGPoint(x: 280, y: 120))

        let harness = ScrollObservationHarness()
        harness.setVerticalOffset(320)
        let initialOffset = harness.verticalOffset
        harness.apply(deliveredEvent)

        #expect(harness.verticalOffset != initialOffset)
    }

    @MainActor
    @Test func currentProcessDeliveryChangesRealScrollViewHorizontalOffset() throws {
        guard let capture = try? ScrollEventCapture() else {
            return
        }
        defer { capture.stop() }

        let delegate = AppDelegate()
        let session = AutoscrollSession(
            anchorPoint: CGPoint(x: 120, y: 120),
            deliveryPoint: CGPoint(x: 120, y: 120),
            targetPID: getpid(),
            targetWindowID: nil,
            latchedScrollOwner: nil,
            canScrollHorizontally: true,
            canScrollVertically: false,
            activationButtonNumber: 2
        )
        guard let scrollEvent = makeScrollEvent(verticalAmount: 0, horizontalAmount: -120) else {
            Issue.record("Failed to create synthetic horizontal scroll event")
            return
        }

        scrollEvent.location = CGPoint(x: 280, y: 120)
        markAsSyntheticScroll(scrollEvent)
        delegate.deliverScrollEvent(
            scrollEvent,
            session: session,
            horizontalAmount: -120,
            verticalAmount: 0
        )

        let deliveredEvent = try #require(capture.waitForEvent())
        #expect(deliveredEvent.location == CGPoint(x: 280, y: 120))

        let harness = ScrollObservationHarness()
        harness.setHorizontalOffset(320)
        let initialOffset = harness.horizontalOffset
        harness.apply(deliveredEvent)

        #expect(harness.horizontalOffset != initialOffset)
    }

    @MainActor
    @Test func sameOwnerEmitsAndScrollsRealNSScrollView() throws {
        guard let capture = try? ScrollEventCapture() else {
            return
        }
        defer { capture.stop() }

        let delegate = AppDelegate()
        delegate.windowIDResolver = { _ in 11 }
        let session = AutoscrollSession(
            anchorPoint: CGPoint(x: 80, y: 120),
            deliveryPoint: CGPoint(x: 80, y: 120),
            targetPID: nil,
            targetWindowID: 11,
            latchedScrollOwner: AutoscrollScrollOwner(
                role: "AXScrollArea",
                subrole: nil,
                frame: CGRect(x: 0, y: 0, width: 160, height: 240)
            ),
            canScrollHorizontally: false,
            canScrollVertically: true,
            activationButtonNumber: 2
        )
        guard let scrollEvent = makeScrollEvent(verticalAmount: -120) else {
            Issue.record("Failed to create synthetic scroll event")
            return
        }

        scrollEvent.location = CGPoint(x: 80, y: 120)
        markAsSyntheticScroll(scrollEvent)
        delegate.deliverScrollEvent(
            scrollEvent,
            session: session,
            horizontalAmount: 0,
            verticalAmount: -120
        )

        let deliveredEvent = try #require(capture.waitForEvent())
        #expect(deliveredEvent.location == CGPoint(x: 80, y: 120))

        let harness = SplitPaneScrollHarness()
        let initialLeft = harness.left.verticalOffset
        let initialRight = harness.right.verticalOffset
        harness.apply(deliveredEvent)

        #expect(harness.left.verticalOffset != initialLeft)
        #expect(harness.right.verticalOffset == initialRight)
    }

    @MainActor
    @Test func differentWindowEmitsNoEventAndKeepsSessionActive() throws {
        guard let capture = try? ScrollEventCapture() else {
            return
        }
        defer { capture.stop() }

        let delegate = AppDelegate()
        delegate.windowIDResolver = { point in
            point.x < 160 ? 11 : 44
        }
        let session = AutoscrollSession(
            anchorPoint: CGPoint(x: 80, y: 120),
            deliveryPoint: CGPoint(x: 80, y: 120),
            targetPID: nil,
            targetWindowID: 11,
            latchedScrollOwner: AutoscrollScrollOwner(
                role: "AXScrollArea",
                subrole: nil,
                frame: CGRect(x: 0, y: 0, width: 160, height: 240)
            ),
            canScrollHorizontally: false,
            canScrollVertically: true,
            activationButtonNumber: 2
        )
        delegate.activeSession = session
        delegate.isAutoScrolling = true

        guard let scrollEvent = makeScrollEvent(verticalAmount: -120) else {
            Issue.record("Failed to create synthetic scroll event")
            return
        }

        scrollEvent.location = CGPoint(x: 260, y: 120)
        markAsSyntheticScroll(scrollEvent)
        delegate.deliverScrollEvent(
            scrollEvent,
            session: session,
            horizontalAmount: 0,
            verticalAmount: -120
        )

        #expect(capture.waitForEvent(timeout: 0.15) == nil)
        #expect(delegate.isAutoScrolling == true)
        let activeSession = try #require(delegate.activeSession)
        #expect(activeSession.targetWindowID == 11)
    }

    @MainActor
    @Test func differentPaneInSameWindowEmitsNoEventAndKeepsSessionActive() throws {
        guard let capture = try? ScrollEventCapture() else {
            return
        }
        defer { capture.stop() }

        let delegate = AppDelegate()
        delegate.windowIDResolver = { _ in 11 }
        let session = AutoscrollSession(
            anchorPoint: CGPoint(x: 80, y: 120),
            deliveryPoint: CGPoint(x: 80, y: 120),
            targetPID: nil,
            targetWindowID: 11,
            latchedScrollOwner: AutoscrollScrollOwner(
                role: "AXScrollArea",
                subrole: nil,
                frame: CGRect(x: 0, y: 0, width: 160, height: 240)
            ),
            canScrollHorizontally: false,
            canScrollVertically: true,
            activationButtonNumber: 2
        )
        delegate.activeSession = session
        delegate.isAutoScrolling = true

        guard let scrollEvent = makeScrollEvent(verticalAmount: -120) else {
            Issue.record("Failed to create synthetic scroll event")
            return
        }

        scrollEvent.location = CGPoint(x: 260, y: 120)
        markAsSyntheticScroll(scrollEvent)
        delegate.deliverScrollEvent(
            scrollEvent,
            session: session,
            horizontalAmount: 0,
            verticalAmount: -120
        )

        #expect(capture.waitForEvent(timeout: 0.15) == nil)
        #expect(delegate.isAutoScrolling == true)
        let activeSession = try #require(delegate.activeSession)
        #expect(activeSession.latchedScrollOwner == session.latchedScrollOwner)
    }

    @MainActor
    @Test func returnToOriginalOwnerEmitsAgainAndRealScrollingResumes() throws {
        guard let capture = try? ScrollEventCapture() else {
            return
        }
        defer { capture.stop() }

        let delegate = AppDelegate()
        delegate.windowIDResolver = { _ in 11 }
        let session = AutoscrollSession(
            anchorPoint: CGPoint(x: 80, y: 120),
            deliveryPoint: CGPoint(x: 80, y: 120),
            targetPID: nil,
            targetWindowID: 11,
            latchedScrollOwner: AutoscrollScrollOwner(
                role: "AXScrollArea",
                subrole: nil,
                frame: CGRect(x: 0, y: 0, width: 160, height: 240)
            ),
            canScrollHorizontally: false,
            canScrollVertically: true,
            activationButtonNumber: 2
        )
        delegate.activeSession = session
        delegate.isAutoScrolling = true

        guard let pausedEvent = makeScrollEvent(verticalAmount: -120),
              let resumedEvent = makeScrollEvent(verticalAmount: -120) else {
            Issue.record("Failed to create synthetic scroll event")
            return
        }

        pausedEvent.location = CGPoint(x: 260, y: 120)
        markAsSyntheticScroll(pausedEvent)
        delegate.deliverScrollEvent(
            pausedEvent,
            session: session,
            horizontalAmount: 0,
            verticalAmount: -120
        )

        #expect(capture.waitForEvent(timeout: 0.15) == nil)
        #expect(delegate.isAutoScrolling == true)
        #expect(delegate.activeSession != nil)

        resumedEvent.location = CGPoint(x: 80, y: 120)
        markAsSyntheticScroll(resumedEvent)
        delegate.deliverScrollEvent(
            resumedEvent,
            session: session,
            horizontalAmount: 0,
            verticalAmount: -120
        )

        let deliveredEvent = try #require(capture.waitForEvent())
        #expect(deliveredEvent.location == CGPoint(x: 80, y: 120))

        let harness = SplitPaneScrollHarness()
        let initialLeft = harness.left.verticalOffset
        harness.apply(deliveredEvent)
        #expect(harness.left.verticalOffset != initialLeft)
        #expect(delegate.isAutoScrolling == true)
    }

    @MainActor
    @Test func targetPIDLossStillStops() throws {
        guard let capture = try? ScrollEventCapture() else {
            return
        }
        defer { capture.stop() }

        let delegate = AppDelegate()
        let session = AutoscrollSession(
            anchorPoint: CGPoint(x: 80, y: 120),
            deliveryPoint: CGPoint(x: 80, y: 120),
            targetPID: pid_t.max,
            targetWindowID: nil,
            latchedScrollOwner: nil,
            canScrollHorizontally: false,
            canScrollVertically: true,
            activationButtonNumber: 2
        )
        delegate.activeSession = session
        delegate.isAutoScrolling = true

        guard let scrollEvent = makeScrollEvent(verticalAmount: -120) else {
            Issue.record("Failed to create synthetic scroll event")
            return
        }

        scrollEvent.location = CGPoint(x: 80, y: 120)
        markAsSyntheticScroll(scrollEvent)
        delegate.deliverScrollEvent(
            scrollEvent,
            session: session,
            horizontalAmount: 0,
            verticalAmount: -120
        )

        #expect(capture.waitForEvent(timeout: 0.15) == nil)
        #expect(delegate.isAutoScrolling == false)
    }

}

private final class ScrollEventCapture {
    private let syntheticScrollUserData: Int64 = 0x5352434C
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private(set) var capturedEvent: CGEvent?

    init() throws {
        let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard type == .scrollWheel,
                  let userInfo else {
                return Unmanaged.passUnretained(event)
            }

            let capture = Unmanaged<ScrollEventCapture>.fromOpaque(userInfo).takeUnretainedValue()
            if event.getIntegerValueField(.eventSourceUserData) == capture.syntheticScrollUserData {
                capture.capturedEvent = event
            }
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            throw CaptureError.failedToCreateTap
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        eventTap = tap
        runLoopSource = source
        if let source {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    deinit {
        stop()
    }

    func waitForEvent(timeout: TimeInterval = 0.35) -> CGEvent? {
        let deadline = Date().addingTimeInterval(timeout)
        while capturedEvent == nil && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        return capturedEvent
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        if let tap = eventTap {
            CFMachPortInvalidate(tap)
        }
        runLoopSource = nil
        eventTap = nil
        capturedEvent = nil
    }

    enum CaptureError: Error {
        case failedToCreateTap
    }
}

@MainActor
private struct ScrollObservationHarness {
    let scrollView: NSScrollView
    let documentView: NSView

    init() {
        scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 320, height: 240))
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.borderType = .bezelBorder

        documentView = NSView(frame: NSRect(x: 0, y: 0, width: 2400, height: 2400))
        scrollView.documentView = documentView
    }

    var horizontalOffset: CGFloat {
        scrollView.contentView.bounds.origin.x
    }

    var verticalOffset: CGFloat {
        scrollView.contentView.bounds.origin.y
    }

    func setHorizontalOffset(_ offset: CGFloat) {
        let maxOffset = max(0, documentView.bounds.width - scrollView.contentView.bounds.width)
        let constrainedX = max(0, min(offset, maxOffset))
        scrollView.contentView.scroll(to: CGPoint(x: constrainedX, y: verticalOffset))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    func setVerticalOffset(_ offset: CGFloat) {
        let maxOffset = max(0, documentView.bounds.height - scrollView.contentView.bounds.height)
        let constrainedY = max(0, min(offset, maxOffset))
        scrollView.contentView.scroll(to: CGPoint(x: horizontalOffset, y: constrainedY))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    func apply(_ event: CGEvent) {
        let verticalPointDelta = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
        let verticalLineDelta = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        let horizontalPointDelta = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2)
        let horizontalLineDelta = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
        let resolvedVerticalDelta = verticalPointDelta != 0 ? CGFloat(verticalPointDelta) : CGFloat(verticalLineDelta)
        let resolvedHorizontalDelta = horizontalPointDelta != 0 ? CGFloat(horizontalPointDelta) : CGFloat(horizontalLineDelta)
        guard resolvedVerticalDelta != 0 || resolvedHorizontalDelta != 0 else {
            return
        }

        let maxHorizontalOffset = max(0, documentView.bounds.width - scrollView.contentView.bounds.width)
        let maxVerticalOffset = max(0, documentView.bounds.height - scrollView.contentView.bounds.height)
        let nextHorizontalOffset = max(0, min(horizontalOffset - resolvedHorizontalDelta, maxHorizontalOffset))
        let nextVerticalOffset = max(0, min(verticalOffset - resolvedVerticalDelta, maxVerticalOffset))
        scrollView.contentView.scroll(to: CGPoint(x: nextHorizontalOffset, y: nextVerticalOffset))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        pumpMainRunLoop(for: 0.02)
    }
}

@MainActor
private struct SplitPaneScrollHarness {
    let left = ScrollObservationHarness()
    let right = ScrollObservationHarness()
    let splitX: CGFloat = 160

    init() {
        left.setVerticalOffset(320)
        right.setVerticalOffset(320)
    }

    func apply(_ event: CGEvent) {
        if event.location.x < splitX {
            left.apply(event)
        } else {
            right.apply(event)
        }
    }
}

@MainActor
private func pumpMainRunLoop(for duration: TimeInterval) {
    let deadline = Date().addingTimeInterval(duration)
    repeat {
        RunLoop.main.run(mode: .default, before: deadline)
    } while Date() < deadline
}

private func makeScrollEvent(verticalAmount: Int32, horizontalAmount: Int32 = 0) -> CGEvent? {
    let scrollEvent = CGEvent(
        scrollWheelEvent2Source: nil,
        units: .pixel,
        wheelCount: 2,
        wheel1: verticalAmount,
        wheel2: horizontalAmount,
        wheel3: 0
    )
    scrollEvent?.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
    scrollEvent?.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: Int64(verticalAmount))
    scrollEvent?.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: Int64(horizontalAmount))
    scrollEvent?.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: Int64(verticalAmount))
    scrollEvent?.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: Int64(horizontalAmount))
    return scrollEvent
}

private func markAsSyntheticScroll(_ scrollEvent: CGEvent) {
    scrollEvent.setIntegerValueField(.eventSourceUserData, value: 0x5352434C)
}
