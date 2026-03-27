import Cocoa
import CoreGraphics
import Testing
@testable import Scrollapp

struct AutoscrollCoreTests {

    @Test func classifierPassesThroughInteractiveTargets() {
        let targets: [AutoscrollTargetSnapshot] = [
            AutoscrollTargetSnapshot(
                roles: ["AXLink", "AXWebArea"],
                subroles: [],
                isExplicitlyScrollable: true
            ),
            AutoscrollTargetSnapshot(
                roles: ["AXGroup"],
                subroles: [],
                isExplicitlyScrollable: false,
                actions: ["AXPress"]
            ),
            AutoscrollTargetSnapshot(
                roles: ["AXTextField", "AXWebArea"],
                subroles: [],
                isExplicitlyScrollable: false
            )
        ]

        for target in targets {
            #expect(AutoscrollTargetClassifier.classify(target).shouldStart == false)
        }
    }

    @Test func classifierStartsScrollableContent() {
        let targets: [AutoscrollTargetSnapshot] = [
            AutoscrollTargetSnapshot(
                roles: ["AXGroup"],
                subroles: [],
                isExplicitlyScrollable: false
            ),
            AutoscrollTargetSnapshot(
                roles: ["AXTextArea"],
                subroles: [],
                isExplicitlyScrollable: true
            ),
            AutoscrollTargetSnapshot(
                roles: ["AXScrollArea"],
                subroles: [],
                isExplicitlyScrollable: false
            )
        ]

        for target in targets {
            #expect(AutoscrollTargetClassifier.classify(target).shouldStart)
        }
    }

    @Test func classifierUsesFallbackAxesForPlainAndScrollableTargets() {
        let plainAxes = AutoscrollTargetClassifier.classify(
            AutoscrollTargetSnapshot(
                roles: ["AXGroup"],
                subroles: [],
                isExplicitlyScrollable: false
            )
        ).fallbackAxes
        let explicitAxes = AutoscrollTargetClassifier.classify(
            AutoscrollTargetSnapshot(
                roles: ["AXGroup"],
                subroles: [],
                isExplicitlyScrollable: true
            )
        ).fallbackAxes

        #expect(plainAxes == .both)
        #expect(explicitAxes == .none)
    }

    @Test func physicsSuppressesSmallMotionInsideDeadZone() {
        let physics = AutoscrollPhysics(deadZone: 15)
        let velocity = physics.velocity(
            from: CGSize(width: 10, height: 10),
            sensitivity: 1.0,
            invertVertical: false,
            axes: .both
        )

        #expect(velocity == .zero)
    }

    @Test func physicsAcceleratesWithDistanceAndInvertsBothAxes() {
        let physics = AutoscrollPhysics(deadZone: 5)

        let mediumMove = physics.velocity(
            from: CGSize(width: 120, height: 0),
            sensitivity: 1.0,
            invertVertical: false,
            axes: .both
        )
        let farMove = physics.velocity(
            from: CGSize(width: 260, height: 0),
            sensitivity: 1.0,
            invertVertical: false,
            axes: .both
        )
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

        #expect(abs(mediumMove.horizontal) < 1_700)
        #expect(abs(farMove.horizontal) > abs(mediumMove.horizontal) * 4.5)
        #expect(abs(farMove.horizontal) > 8_000)
        #expect(normalDirection.horizontal == -invertedDirection.horizontal)
        #expect(normalDirection.vertical == -invertedDirection.vertical)
    }

    @Test func emissionStepProducesComparableDistanceAcrossTickRates() {
        let velocity = AutoscrollVelocity(horizontal: 0, vertical: 4_750)
        var carryAt60Hz = AutoscrollVelocity.zero
        var carryAt100Hz = AutoscrollVelocity.zero
        var totalAt60Hz: CGFloat = 0
        var totalAt100Hz: CGFloat = 0

        for _ in 0..<60 {
            let step = AutoscrollBehavior.emissionStep(
                velocity: velocity,
                elapsedTime: 1.0 / 60.0,
                carry: carryAt60Hz
            )
            carryAt60Hz = step.carry
            totalAt60Hz += step.delta.vertical
        }

        for _ in 0..<100 {
            let step = AutoscrollBehavior.emissionStep(
                velocity: velocity,
                elapsedTime: 1.0 / 100.0,
                carry: carryAt100Hz
            )
            carryAt100Hz = step.carry
            totalAt100Hz += step.delta.vertical
        }

        #expect(abs(totalAt60Hz - totalAt100Hz) <= 2)
    }

    @Test func smoothingKeepsLowSpeedNearCenterResponsive() {
        let smoothedVelocity = AutoscrollBehavior.smoothedVelocity(
            previous: .zero,
            target: AutoscrollVelocity(horizontal: 0, vertical: 27),
            elapsedTime: AutoscrollBehavior.preferredTickInterval
        )

        #expect(smoothedVelocity.vertical > 0)
        #expect(smoothedVelocity.vertical < 27)
    }

    @MainActor
    @Test func middleClickStartsAutoscrollOnButtonRelease() {
        let delegate = AppDelegate()
        delegate.accessibilityTargetInfoResolver = { _ in
            var info = AppDelegate.AccessibilityTargetInfo()
            info.roles = ["AXScrollArea"]
            info.canScrollVertically = true
            return info
        }

        let clickPoint = CGPoint(x: 120, y: 140)
        guard let mouseDown = makeOtherMouseEvent(type: .otherMouseDown, location: clickPoint, buttonNumber: 2),
              let mouseUp = makeOtherMouseEvent(type: .otherMouseUp, location: clickPoint, buttonNumber: 2) else {
            Issue.record("Failed to create middle-click events")
            return
        }

        _ = delegate.handleOtherMouseDown(mouseDown, buttonNumber: 2)
        _ = delegate.handleOtherMouseUp(mouseUp, buttonNumber: 2)

        let session = try? #require(delegate.activeSession)
        #expect(delegate.isAutoScrolling)
        #expect(session?.activationButtonNumber == 2)
    }

    @MainActor
    @Test func leftClickStopsAutoscrollAndIsSwallowedOnce() {
        let delegate = AppDelegate()
        primeDelegateForPerformScroll(
            delegate,
            session: makePerformScrollSession(),
            physicalPointer: CGPoint(x: 80, y: 120),
            deliveryPointer: CGPoint(x: 80, y: 120)
        )

        guard let leftDown = makeOtherMouseEvent(
            type: .leftMouseDown,
            location: CGPoint(x: 80, y: 120),
            buttonNumber: 0
        ),
        let leftUp = makeOtherMouseEvent(
            type: .leftMouseUp,
            location: CGPoint(x: 80, y: 120),
            buttonNumber: 0
        ) else {
            Issue.record("Failed to create left-click events")
            return
        }

        #expect(delegate.handleStopClick(leftDown, buttonNumber: 0) == nil)
        #expect(delegate.isAutoScrolling == false)
        #expect(delegate.swallowIfNeeded(leftUp, buttonNumber: 0) == nil)
    }

    @MainActor
    @Test func rightClickStopsAutoscrollButStillForwardsEvent() {
        let delegate = AppDelegate()
        primeDelegateForPerformScroll(
            delegate,
            session: makePerformScrollSession(),
            physicalPointer: CGPoint(x: 80, y: 120),
            deliveryPointer: CGPoint(x: 80, y: 120)
        )

        guard let rightDown = makeOtherMouseEvent(
            type: .rightMouseDown,
            location: CGPoint(x: 80, y: 120),
            buttonNumber: 1
        ),
        let rightUp = makeOtherMouseEvent(
            type: .rightMouseUp,
            location: CGPoint(x: 80, y: 120),
            buttonNumber: 1
        ) else {
            Issue.record("Failed to create right-click events")
            return
        }

        #expect(delegate.handleStopClick(rightDown, buttonNumber: 1) != nil)
        #expect(delegate.isAutoScrolling == false)
        #expect(delegate.swallowIfNeeded(rightUp, buttonNumber: 1) != nil)
    }

    @MainActor
    @Test func externalWheelInputDoesNotCancelActiveAutoscroll() {
        let delegate = AppDelegate()
        primeDelegateForPerformScroll(
            delegate,
            session: makePerformScrollSession(),
            physicalPointer: CGPoint(x: 80, y: 120),
            deliveryPointer: CGPoint(x: 80, y: 120)
        )

        guard let scrollEvent = makeScrollEvent(verticalAmount: -40) else {
            Issue.record("Failed to create external scroll event")
            return
        }

        let proxy = unsafeBitCast(0x1, to: CGEventTapProxy.self)
        let forwardedEvent = delegate.handleEventTap(proxy: proxy, type: .scrollWheel, event: scrollEvent)

        #expect(forwardedEvent != nil)
        #expect(delegate.isAutoScrolling)
        #expect(delegate.activeSession != nil)
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
        guard let capture = makeScrollEventCapture() else {
            return
        }
        defer { capture.stop() }

        let delegate = AppDelegate()
        let session = AutoscrollSession(
            anchorPoint: CGPoint(x: 120, y: 120),
            targetWindowID: nil,
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
    @Test func performScrollEmitsAndScrollsInMatchedWindow() throws {
        guard let capture = makeScrollEventCapture() else {
            return
        }
        defer { capture.stop() }

        let delegate = AppDelegate()
        delegate.windowIDResolver = { _ in 11 }
        primeDelegateForPerformScroll(
            delegate,
            session: makePerformScrollSession(targetWindowID: 11),
            physicalPointer: CGPoint(x: 80, y: 220),
            deliveryPointer: CGPoint(x: 80, y: 220)
        )
        let harness = ScrollObservationHarness()
        harness.setVerticalOffset(320)
        let initialOffset = harness.verticalOffset

        var deliveredEvent: CGEvent?
        for _ in 0..<8 {
            delegate.performScroll()
            deliveredEvent = capture.waitForEvent(timeout: 0.05)
            if deliveredEvent != nil {
                break
            }
        }

        let scrollEvent = try #require(deliveredEvent)
        #expect(scrollEvent.getIntegerValueField(.eventSourceUserData) == 0x5352434C)
        #expect(scrollEvent.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) != 0)
        harness.apply(scrollEvent)
        #expect(harness.verticalOffset != initialOffset)
        #expect(delegate.isAutoScrolling == true)
    }

    @MainActor
    @Test func windowMismatchPausesEmissionButKeepsSessionActive() throws {
        guard let capture = makeScrollEventCapture() else {
            return
        }
        defer { capture.stop() }

        let delegate = AppDelegate()
        delegate.windowIDResolver = { point in
            point.x < 160 ? 11 : 44
        }
        primeDelegateForPerformScroll(
            delegate,
            session: makePerformScrollSession(targetWindowID: 11),
            physicalPointer: CGPoint(x: 260, y: 220),
            deliveryPointer: CGPoint(x: 260, y: 220)
        )
        capture.reset()

        delegate.performScroll()

        #expect(capture.waitForEvent(timeout: 0.15) == nil)
        #expect(delegate.isAutoScrolling == true)
        #expect(delegate.activeSession != nil)
    }

    @MainActor
    @Test func returningInsideWindowResumesEmissionAndScrolling() throws {
        guard let capture = makeScrollEventCapture() else {
            return
        }
        defer { capture.stop() }

        let delegate = AppDelegate()
        delegate.windowIDResolver = { point in
            point.x < 160 ? 11 : 44
        }
        primeDelegateForPerformScroll(
            delegate,
            session: makePerformScrollSession(targetWindowID: 11),
            physicalPointer: CGPoint(x: 260, y: 220),
            deliveryPointer: CGPoint(x: 260, y: 220)
        )
        capture.reset()

        delegate.performScroll()

        #expect(capture.waitForEvent(timeout: 0.15) == nil)
        #expect(delegate.isAutoScrolling == true)

        delegate.windowIDResolver = { _ in 11 }
        delegate.lastPhysicalPointerLocation = CGPoint(x: 80, y: 220)
        delegate.lastDeliveryPointerLocation = CGPoint(x: 80, y: 220)
        let harness = ScrollObservationHarness()
        harness.setVerticalOffset(320)
        let initialOffset = harness.verticalOffset

        delegate.performScroll()

        let deliveredEvent = try #require(capture.waitForEvent())
        #expect(deliveredEvent.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) != 0)
        harness.apply(deliveredEvent)
        #expect(harness.verticalOffset != initialOffset)
        #expect(delegate.isAutoScrolling == true)
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

    func reset() {
        capturedEvent = nil
        RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        capturedEvent = nil
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

private func makeOtherMouseEvent(type: CGEventType, location: CGPoint, buttonNumber: Int) -> CGEvent? {
    let mouseButton: CGMouseButton
    switch buttonNumber {
    case 0:
        mouseButton = .left
    case 1:
        mouseButton = .right
    default:
        mouseButton = .center
    }

    let event = CGEvent(
        mouseEventSource: nil,
        mouseType: type,
        mouseCursorPosition: location,
        mouseButton: mouseButton
    )
    event?.setIntegerValueField(.mouseEventButtonNumber, value: Int64(buttonNumber))
    return event
}

private func markAsSyntheticScroll(_ scrollEvent: CGEvent) {
    scrollEvent.setIntegerValueField(.eventSourceUserData, value: 0x5352434C)
}

private func makeScrollEventCapture() -> ScrollEventCapture? {
    do {
        return try ScrollEventCapture()
    } catch {
        Issue.record("Failed to create scroll event capture: \(error)")
        return nil
    }
}

private func makePerformScrollSession(
    targetWindowID: CGWindowID? = nil
) -> AutoscrollSession {
    AutoscrollSession(
        anchorPoint: CGPoint(x: 80, y: 120),
        targetWindowID: targetWindowID,
        canScrollHorizontally: false,
        canScrollVertically: true,
        activationButtonNumber: 2
    )
}

private func primeDelegateForPerformScroll(
    _ delegate: AppDelegate,
    session: AutoscrollSession,
    physicalPointer: CGPoint,
    deliveryPointer: CGPoint
) {
    delegate.activeSession = session
    delegate.isAutoScrolling = true
    delegate.activationButtonIsDown = false
    delegate.lastPhysicalPointerLocation = physicalPointer
    delegate.lastDeliveryPointerLocation = deliveryPointer
    delegate.scrollSensitivity = 1.0
    delegate.isDirectionInverted = false
}
