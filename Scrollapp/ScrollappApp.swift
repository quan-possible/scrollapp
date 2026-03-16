//
//  ScrollappApp.swift
//  Scrollapp
//

import SwiftUI
import Cocoa
import ServiceManagement
import ApplicationServices

@main
struct ScrollappApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let syntheticScrollUserData: Int64 = 0x5352434C

    var statusItem: NSStatusItem!
    var diagnosticsMenuItems = [RuntimeDiagnosticItem: NSMenuItem]()
    var diagnosticsState = [RuntimeDiagnosticItem: String]()
    var scrollTimer: Timer?
    var eventTap: CFMachPort?
    var eventTapSource: CFRunLoopSource?
    var indicatorPanel: NSPanel?
    var activeSession: AutoscrollSession?
    var activationButtonIsDown = false
    var swallowedButtons = Set<Int>()
    var lastObservedFlags: CGEventFlags = []
    var lastPhysicalPointerLocation: CGPoint?
    var lastDeliveryPointerLocation: CGPoint?
    var isAutoScrolling = false
    var isDirectionInverted = false
    var launchAtLogin = false
    var scrollSensitivity: Double = 1.0
    var runtimePermissionStatus = RuntimePermissionStatus()
    var isStatusMenuOpen = false
    var diagnosticsRefreshPending = false
    var windowIDResolver: ((CGPoint) -> CGWindowID?)?

    struct AccessibilityTargetInfo {
        var pid: pid_t?
        var roles = [String]()
        var subroles = [String]()
        var actionNames = [String]()
        var actionableAncestorDepth: Int?
        var linkedAncestorDepth: Int?
        var actionabilityReasons = [String]()
        var canScrollHorizontally = false
        var canScrollVertically = false
        var scrollOwnerRole: String?
        var scrollOwnerSubrole: String?
        var scrollOwnerFrame: CGRect?
    }

    struct ScrollOwnerCandidate: Equatable {
        var role: String?
        var subrole: String?
        var frame: CGRect?
        var hasHorizontalScrollBar: Bool
        var hasVerticalScrollBar: Bool
        var hopCount: Int
    }

    struct RuntimePermissionStatus {
        var accessibilityTrusted = false
        var canListenEvents = false
        var canPostEvents = false
    }

    var activationButtonNumber: Int {
        2
    }

    final class AutoscrollIndicatorView: NSView {
        override var isOpaque: Bool {
            false
        }

        override func draw(_ dirtyRect: NSRect) {
            NSColor.clear.setFill()
            dirtyRect.fill()

            let bounds = self.bounds.insetBy(dx: 3, dy: 3)

            NSColor.windowBackgroundColor.withAlphaComponent(0.12).setFill()
            let fillPath = NSBezierPath(ovalIn: bounds)
            fillPath.fill()

            NSColor.labelColor.withAlphaComponent(0.42).setStroke()
            let outerRing = NSBezierPath(ovalIn: bounds)
            outerRing.lineWidth = 1
            outerRing.stroke()

            let innerRingRect = bounds.insetBy(dx: 4.5, dy: 4.5)
            NSColor.labelColor.withAlphaComponent(0.12).setStroke()
            let innerRing = NSBezierPath(ovalIn: innerRingRect)
            innerRing.lineWidth = 1
            innerRing.stroke()
        }
    }

    enum RuntimeDiagnosticItem: CaseIterable {
        case accessibility
        case listenEvent
        case postEvent
        case eventTap
        case lastMouseTrigger
        case activationMatch
        case axHitTest
        case activationDecision
        case sessionState
        case scrollEmission
        case scrollDelivery
        case stopReason

        var placeholderTitle: String {
            switch self {
            case .accessibility:
                return "Accessibility: Checking..."
            case .listenEvent:
                return "Input Monitoring: Checking..."
            case .postEvent:
                return "Event Posting: Checking..."
            case .eventTap:
                return "Event Tap: Checking..."
            case .lastMouseTrigger:
                return "Last Mouse Trigger: Waiting..."
            case .activationMatch:
                return "Activation Match: Waiting..."
            case .axHitTest:
                return "AX Hit-Test: Waiting..."
            case .activationDecision:
                return "Activation Decision: Waiting..."
            case .sessionState:
                return "Session State: Inactive"
            case .scrollEmission:
                return "Scroll Emission: Waiting..."
            case .scrollDelivery:
                return "Scroll Delivery: Waiting..."
            case .stopReason:
                return "Stop Reason: None"
            }
        }

        var titlePrefix: String {
            switch self {
            case .accessibility:
                return "Accessibility"
            case .listenEvent:
                return "Input Monitoring"
            case .postEvent:
                return "Event Posting"
            case .eventTap:
                return "Event Tap"
            case .lastMouseTrigger:
                return "Last Mouse Trigger"
            case .activationMatch:
                return "Activation Match"
            case .axHitTest:
                return "AX Hit-Test"
            case .activationDecision:
                return "Activation Decision"
            case .sessionState:
                return "Session State"
            case .scrollEmission:
                return "Scroll Emission"
            case .scrollDelivery:
                return "Scroll Delivery"
            case .stopReason:
                return "Stop Reason"
            }
        }
    }

    var isAutomatedTestMode: Bool {
        let environment = ProcessInfo.processInfo.environment
        let arguments = ProcessInfo.processInfo.arguments

        if isEnabledTestEnvironmentValue(environment["SCROLLAPP_TEST_MODE"]) {
            return true
        }

        if isEnabledTestEnvironmentValue(environment["SCROLLAPP_UI_TEST_MODE"]) {
            return true
        }

        if arguments.contains("--scrollapp-test-mode") {
            return true
        }

        return environment["XCTestConfigurationFilePath"] != nil
    }

    func isEnabledTestEnvironmentValue(_ value: String?) -> Bool {
        guard let rawValue = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawValue.isEmpty else {
            return false
        }

        let normalized = rawValue.lowercased()
        return normalized != "0" && normalized != "false" && normalized != "no"
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        isDirectionInverted = UserDefaults.standard.bool(forKey: "invertScrollDirection")
        launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
        scrollSensitivity = UserDefaults.standard.double(forKey: "scrollSensitivity")
        if scrollSensitivity == 0 {
            scrollSensitivity = 1.0
        }

        setupMenuBar()

        guard !isAutomatedTestMode else {
            return
        }

        updateLoginItemState()
        refreshRuntimeDiagnostics(promptForMissingPermissions: true, retryEventTap: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopAutoScroll()
        tearDownEventTap()
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "arrow.up.and.down.circle", accessibilityDescription: "Scrollapp")
        }

        let menu = NSMenu()
        menu.delegate = self

        let sensitivityItem = NSMenuItem(title: String(format: "Scroll Speed: %.1fx", scrollSensitivity), action: nil, keyEquivalent: "")
        let sensitivityView = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: 30))

        let slider = NSSlider(frame: NSRect(x: 20, y: 5, width: 150, height: 20))
        slider.minValue = 0.2
        slider.maxValue = 3.0
        slider.doubleValue = scrollSensitivity
        slider.target = self
        slider.action = #selector(sensitivityChanged(_:))
        slider.isContinuous = true

        let label = NSTextField(labelWithString: String(format: "%.1fx", scrollSensitivity))
        label.frame = NSRect(x: 180, y: 5, width: 50, height: 20)
        label.alignment = .center
        label.tag = 100

        sensitivityView.addSubview(slider)
        sensitivityView.addSubview(label)
        sensitivityItem.view = sensitivityView
        menu.addItem(sensitivityItem)
        menu.addItem(NSMenuItem.separator())

        let invertItem = NSMenuItem(title: "Invert Scrolling Direction", action: #selector(toggleDirectionInversion), keyEquivalent: "")
        invertItem.state = isDirectionInverted ? .on : .off
        menu.addItem(invertItem)

        let launchItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.state = launchAtLogin ? .on : .off
        menu.addItem(launchItem)

        menu.addItem(NSMenuItem.separator())
        addDiagnosticsItems(to: menu)
        menu.addItem(NSMenuItem(title: "Refresh Permissions", action: #selector(refreshPermissionsMenuSelected), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "About Scrollapp", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
        updateDiagnosticsMenu()
    }

    func addDiagnosticsItems(to menu: NSMenu) {
        for diagnostic in RuntimeDiagnosticItem.allCases {
            let item = NSMenuItem(title: diagnostic.placeholderTitle, action: nil, keyEquivalent: "")
            item.isEnabled = false
            diagnosticsMenuItems[diagnostic] = item
            menu.addItem(item)
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        guard !isAutomatedTestMode else {
            return
        }
        isStatusMenuOpen = true
        diagnosticsRefreshPending = false
        updateDiagnosticsMenu()
        refreshRuntimeDiagnostics(promptForMissingPermissions: false, retryEventTap: false)
    }

    func menuDidClose(_ menu: NSMenu) {
        isStatusMenuOpen = false
        diagnosticsRefreshPending = false
    }

    func updateDiagnosticsMenu() {
        diagnosticsMenuItems[.accessibility]?.title = statusLine(
            label: "Accessibility",
            isGranted: runtimePermissionStatus.accessibilityTrusted
        )
        diagnosticsMenuItems[.listenEvent]?.title = statusLine(
            label: "Input Monitoring",
            isGranted: runtimePermissionStatus.canListenEvents
        )
        diagnosticsMenuItems[.postEvent]?.title = statusLine(
            label: "Event Posting",
            isGranted: runtimePermissionStatus.canPostEvents
        )
        for item in RuntimeDiagnosticItem.allCases
            where item != .accessibility && item != .listenEvent && item != .postEvent {
            diagnosticsMenuItems[item]?.title = diagnosticsState[item] ?? item.placeholderTitle
        }
    }

    func statusLine(label: String, isGranted: Bool) -> String {
        "\(label): \(isGranted ? "Granted" : "Missing")"
    }

    func setDiagnostic(_ item: RuntimeDiagnosticItem, description: String) {
        let value = "\(item.titlePrefix): \(description)"
        guard diagnosticsState[item] != value else {
            return
        }
        diagnosticsState[item] = value
        scheduleDiagnosticsMenuRefresh()
    }

    func updateLastMouseTrigger(buttonNumber: Int, location: CGPoint) {
        setDiagnostic(
            .lastMouseTrigger,
            description: String(
                format: "otherMouseDown button=%d @ (%.0f, %.0f)",
                buttonNumber,
                location.x,
                location.y
            )
        )
    }

    func scheduleDiagnosticsMenuRefresh() {
        guard isStatusMenuOpen, !diagnosticsRefreshPending else {
            return
        }

        diagnosticsRefreshPending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            guard let self else {
                return
            }
            self.diagnosticsRefreshPending = false
            guard self.isStatusMenuOpen else {
                return
            }
            self.updateDiagnosticsMenu()
        }
    }

    func updateActivationMatchStatus(_ description: String) {
        setDiagnostic(.activationMatch, description: description)
    }

    func updateAXHitTestStatus(_ description: String) {
        setDiagnostic(.axHitTest, description: description)
    }

    func updateActivationDecisionStatus(_ description: String) {
        setDiagnostic(.activationDecision, description: description)
    }

    func updateSessionStateStatus(_ description: String) {
        setDiagnostic(.sessionState, description: description)
    }

    func updateScrollEmissionStatus(_ description: String) {
        setDiagnostic(.scrollEmission, description: description)
    }

    func updateScrollDeliveryStatus(_ description: String) {
        setDiagnostic(.scrollDelivery, description: description)
    }

    func updateStopReasonStatus(_ description: String) {
        setDiagnostic(.stopReason, description: description)
    }

    func summarizeRoles(_ roles: [String]) -> String {
        let summary = roles.prefix(4).joined(separator: " > ")
        if roles.count > 4 {
            return "\(summary) > ..."
        }
        return summary.isEmpty ? "no roles" : summary
    }

    func summarizeActionability(_ reasons: [String]) -> String {
        guard !reasons.isEmpty else {
            return ""
        }
        return " \(reasons.prefix(2).joined(separator: ", "))"
    }

    func missingPermissionNames(from status: RuntimePermissionStatus) -> [String] {
        var names = [String]()
        if !status.accessibilityTrusted {
            names.append("Accessibility")
        }
        if !status.canListenEvents {
            names.append("Input Monitoring")
        }
        if !status.canPostEvents {
            names.append("Event Posting")
        }
        return names
    }

    func refreshRuntimeDiagnostics(promptForMissingPermissions: Bool, retryEventTap: Bool) {
        runtimePermissionStatus = checkPermissions(promptForMissingPermissions: promptForMissingPermissions)
        if retryEventTap {
            setupEventTap()
        } else {
            updateDiagnosticsMenu()
        }
    }

    func setupEventTap() {
        tearDownEventTap()

        let interestedTypes: [CGEventType] = [
            .leftMouseDown,
            .leftMouseUp,
            .mouseMoved,
            .leftMouseDragged,
            .rightMouseDown,
            .rightMouseUp,
            .rightMouseDragged,
            .otherMouseDown,
            .otherMouseUp,
            .otherMouseDragged,
            .flagsChanged,
            .scrollWheel
        ]
        let mask = interestedTypes.reduce(CGEventMask(0)) { partial, type in
            partial | (1 << type.rawValue)
        }

        let callback: CGEventTapCallBack = { proxy, type, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(userInfo).takeUnretainedValue()
            return delegate.handleEventTap(proxy: proxy, type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            let missingPermissions = missingPermissionNames(from: runtimePermissionStatus)
            if missingPermissions.isEmpty {
                diagnosticsState[.eventTap] = "Event Tap: Unavailable"
            } else {
                diagnosticsState[.eventTap] = "Event Tap: Unavailable (\(missingPermissions.joined(separator: ", ")))"
            }
            updateDiagnosticsMenu()
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        eventTap = tap
        eventTapSource = source
        if let source {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
        diagnosticsState[.eventTap] = "Event Tap: Active"
        updateDiagnosticsMenu()
    }

    func tearDownEventTap() {
        if let source = eventTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap = eventTap {
            CFMachPortInvalidate(tap)
        }
        eventTapSource = nil
        eventTap = nil
        diagnosticsState[.eventTap] = "Event Tap: Inactive"
        updateDiagnosticsMenu()
    }

    func handleEventTap(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
                diagnosticsState[.eventTap] = "Event Tap: Active"
                updateDiagnosticsMenu()
            }
            return Unmanaged.passUnretained(event)
        }

        lastObservedFlags = event.flags
        notePhysicalPointerLocationIfNeeded(for: type, event: event)
        let buttonNumber = Int(event.getIntegerValueField(.mouseEventButtonNumber))

        switch type {
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            return Unmanaged.passUnretained(event)
        case .otherMouseDown:
            return handleOtherMouseDown(event, buttonNumber: buttonNumber)
        case .otherMouseUp:
            return handleOtherMouseUp(event, buttonNumber: buttonNumber)
        case .scrollWheel:
            return handleScrollWheel(event)
        case .leftMouseDown:
            return handleStopClick(event, buttonNumber: 0)
        case .leftMouseUp:
            return swallowIfNeeded(event, buttonNumber: 0)
        case .rightMouseDown:
            return handleStopClick(event, buttonNumber: 1)
        case .rightMouseUp:
            return swallowIfNeeded(event, buttonNumber: 1)
        case .flagsChanged:
            return Unmanaged.passUnretained(event)
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    func handleScrollWheel(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        if event.getIntegerValueField(.eventSourceUserData) == syntheticScrollUserData {
            return Unmanaged.passUnretained(event)
        }

        if isAutoScrolling {
            updateStopReasonStatus("interrupted by external scroll input")
            stopAutoScroll()
        }
        return Unmanaged.passUnretained(event)
    }

    func handleOtherMouseDown(_ event: CGEvent, buttonNumber: Int) -> Unmanaged<CGEvent>? {
        let activationPoint = event.unflippedLocation
        let deliveryPoint = event.location
        lastPhysicalPointerLocation = activationPoint
        lastDeliveryPointerLocation = deliveryPoint
        updateLastMouseTrigger(buttonNumber: buttonNumber, location: activationPoint)

        if swallowedButtons.contains(buttonNumber) {
            return nil
        }

        if isAutoScrolling {
            if buttonNumber == activationButtonNumber {
                updateActivationMatchStatus("already active")
                updateActivationDecisionStatus("stop active autoscroll")
                updateStopReasonStatus("replaced by new activation button")
                swallowedButtons.insert(buttonNumber)
                stopAutoScroll()
                return nil
            }
            return Unmanaged.passUnretained(event)
        }

        if buttonNumber != activationButtonNumber {
            updateActivationMatchStatus("no (button \(buttonNumber) != \(activationButtonNumber))")
            updateActivationDecisionStatus("pass through (button mismatch)")
            return Unmanaged.passUnretained(event)
        }

        activationButtonIsDown = true
        updateActivationMatchStatus("yes")

        switch classifyActivation(at: deliveryPoint) {
        case .passThrough:
            activationButtonIsDown = false
            return Unmanaged.passUnretained(event)
        case .start(let session):
            swallowedButtons.insert(buttonNumber)
            startAutoScroll(
                with: AutoscrollSession(
                    anchorPoint: activationPoint,
                    deliveryPoint: deliveryPoint,
                    targetPID: session.targetPID,
                    targetWindowID: session.targetWindowID,
                    latchedScrollOwner: session.latchedScrollOwner,
                    canScrollHorizontally: session.canScrollHorizontally,
                    canScrollVertically: session.canScrollVertically,
                    activationButtonNumber: session.activationButtonNumber,
                    mode: session.mode,
                    velocity: session.velocity
                )
            )
            return nil
        }
    }

    func handleOtherMouseUp(_ event: CGEvent, buttonNumber: Int) -> Unmanaged<CGEvent>? {
        lastPhysicalPointerLocation = event.unflippedLocation
        lastDeliveryPointerLocation = event.location
        if buttonNumber == activationButtonNumber {
            activationButtonIsDown = false
        }

        if swallowedButtons.contains(buttonNumber) {
            swallowedButtons.remove(buttonNumber)

            if var session = activeSession, buttonNumber == session.activationButtonNumber {
                session.mode = AutoscrollBehavior.transitionedMode(
                    from: session.mode,
                    anchorPoint: session.anchorPoint,
                    currentPoint: event.unflippedLocation,
                    activationButtonIsDown: false
                )

                if session.mode == .inactive {
                    updateSessionStateStatus("mode=inactive buttonDown=N")
                    updateStopReasonStatus("activation button released after hold")
                    stopAutoScroll()
                } else {
                    activeSession = session
                    updateSessionStateStatus("mode=\(String(describing: session.mode)) buttonDown=N")
                }
            }
            return nil
        }

        return Unmanaged.passUnretained(event)
    }

    func handleStopClick(_ event: CGEvent, buttonNumber: Int) -> Unmanaged<CGEvent>? {
        guard isAutoScrolling else {
            return Unmanaged.passUnretained(event)
        }

        updateStopReasonStatus("stopped by click \(buttonNumber)")
        stopAutoScroll()
        if AutoscrollStopClickPolicy.shouldSwallow(buttonNumber: buttonNumber) {
            swallowedButtons.insert(buttonNumber)
            return nil
        }
        return Unmanaged.passUnretained(event)
    }

    func swallowIfNeeded(_ event: CGEvent, buttonNumber: Int) -> Unmanaged<CGEvent>? {
        if swallowedButtons.contains(buttonNumber) {
            swallowedButtons.remove(buttonNumber)
            return nil
        }
        return Unmanaged.passUnretained(event)
    }

    func classifyActivation(at eventPoint: CGPoint) -> AutoscrollActivationDisposition {
        guard let info = accessibilityTargetInfo(at: eventPoint) else {
            updateAXHitTestStatus("failed @ \(Int(eventPoint.x.rounded())),\(Int(eventPoint.y.rounded()))")
            updateActivationDecisionStatus("pass through (no AX target)")
            return .passThrough
        }

        let snapshot = targetSnapshot(for: info)
        updateAXHitTestStatus(
            "\(summarizeRoles(info.roles)) [H:\(info.canScrollHorizontally ? "Y" : "N") V:\(info.canScrollVertically ? "Y" : "N")\(!info.actionabilityReasons.isEmpty ? " actionable" : "")\(summarizeActionability(info.actionabilityReasons))]"
        )

        let targetBehavior = AutoscrollTargetClassifier.behavior(for: snapshot)

        if targetBehavior == .passThrough {
            updateActivationDecisionStatus("pass through (classifier)")
            return .passThrough
        }

        if targetBehavior == .undetermined {
            updateActivationDecisionStatus("pass through (undetermined target)")
            return .passThrough
        }

        let fallbackAxes = AutoscrollTargetClassifier.fallbackAxes(for: snapshot)
        let canScrollHorizontally = info.canScrollHorizontally || fallbackAxes.horizontal
        let canScrollVertically = info.canScrollVertically || fallbackAxes.vertical

        guard canScrollHorizontally || canScrollVertically else {
            updateActivationDecisionStatus("pass through (no scroll axes)")
            return .passThrough
        }

        let axisDescription: String
        switch (canScrollHorizontally, canScrollVertically) {
        case (true, true):
            axisDescription = "start (horizontal + vertical)"
        case (true, false):
            axisDescription = "start (horizontal)"
        case (false, true):
            axisDescription = "start (vertical)"
        case (false, false):
            axisDescription = "pass through (no scroll axes)"
        }
        updateActivationDecisionStatus(axisDescription)

        return .start(
            AutoscrollSession(
                anchorPoint: eventPoint,
                deliveryPoint: eventPoint,
                targetPID: info.pid,
                targetWindowID: windowID(at: eventPoint),
                latchedScrollOwner: scrollOwner(for: info),
                canScrollHorizontally: canScrollHorizontally,
                canScrollVertically: canScrollVertically,
                activationButtonNumber: activationButtonNumber
            )
        )
    }

    func startAutoScroll(with session: AutoscrollSession) {
        let wasActivationButtonDown = activationButtonIsDown
        stopAutoScroll()
        activationButtonIsDown = wasActivationButtonDown
        activeSession = session
        isAutoScrolling = true
        updateScrollEmissionStatus(
            "armed @ \(Int(session.anchorPoint.x.rounded())),\(Int(session.anchorPoint.y.rounded()))"
        )
        let pidDescription = session.targetPID.map { "pid=\($0)" } ?? "pid=none"
        let windowDescription = session.targetWindowID.map { "window=\($0)" } ?? "window=none"
        updateScrollDeliveryStatus("armed session tap live-pointer delivery (\(pidDescription), \(windowDescription))")
        updateSessionStateStatus("mode=initial buttonDown=Y dx=0 dy=0")
        updateStopReasonStatus("None")
        updateIndicator(for: session)

        scrollTimer = Timer.scheduledTimer(withTimeInterval: (1.0 / 60.0), repeats: true) { [weak self] _ in
            self?.performScroll()
        }
        RunLoop.current.add(scrollTimer!, forMode: .common)
    }

    func performScroll() {
        guard var session = activeSession else { return }

        let currentPoint = lastPhysicalPointerLocation ?? session.anchorPoint
        let currentDeliveryPoint = lastDeliveryPointerLocation ?? session.deliveryPoint
        let ownerDeliveryAllowed = ownerMatchState(for: currentDeliveryPoint, session: session)
        if activationButtonIsDown {
            session.mode = AutoscrollBehavior.transitionedMode(
                from: session.mode,
                anchorPoint: session.anchorPoint,
                currentPoint: currentPoint,
                activationButtonIsDown: true
            )
        }

        let targetVelocity: AutoscrollVelocity
        if session.mode == .initial {
            targetVelocity = .zero
        } else {
            targetVelocity = AutoscrollBehavior.velocity(
                anchorPoint: session.anchorPoint,
                currentPoint: currentPoint,
                sensitivity: scrollSensitivity,
                invertVertical: isDirectionInverted,
                axes: AutoscrollAxes(
                    horizontal: session.canScrollHorizontally,
                    vertical: session.canScrollVertically
                )
            )
        }

        session.velocity = AutoscrollBehavior.smoothedVelocity(
            previous: session.velocity,
            target: targetVelocity
        )
        if isStatusMenuOpen {
            updateSessionStateStatus(
                String(
                    format: "mode=%@ buttonDown=%@ dx=%.0f dy=%.0f",
                    String(describing: session.mode) as NSString,
                    activationButtonIsDown ? "Y" : "N",
                    currentPoint.x - session.anchorPoint.x,
                    currentPoint.y - session.anchorPoint.y
                )
            )
            updateScrollEmissionStatus(
                String(
                    format: "mode=%@ vx=%.1f vy=%.1f",
                    String(describing: session.mode) as NSString,
                    session.velocity.horizontal,
                    session.velocity.vertical
                )
            )
        }

        activeSession = session
        updateIndicator(for: session)

        if !ownerDeliveryAllowed.isMatched {
            if isStatusMenuOpen {
                updateScrollDeliveryStatus(ownerDeliveryAllowed.statusText)
            }
            return
        }

        guard AutoscrollBehavior.shouldEmitScroll(session.velocity) else {
            if isStatusMenuOpen {
                updateScrollDeliveryStatus("idle (inside dead zone)")
            }
            return
        }

        let horizontalAmount = session.canScrollHorizontally ? Int32(session.velocity.horizontal.rounded()) : 0
        let verticalAmount = session.canScrollVertically ? Int32(session.velocity.vertical.rounded()) : 0
        guard horizontalAmount != 0 || verticalAmount != 0 else {
            if isStatusMenuOpen {
                updateScrollDeliveryStatus("idle (rounded to zero)")
            }
            return
        }

        if let scrollEvent = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: verticalAmount,
            wheel2: horizontalAmount,
            wheel3: 0
        ) {
            scrollEvent.flags = forwardedModifierFlags()
            scrollEvent.setIntegerValueField(.eventSourceUserData, value: syntheticScrollUserData)
            scrollEvent.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
            scrollEvent.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: Int64(verticalAmount))
            scrollEvent.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: Int64(horizontalAmount))
            scrollEvent.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: Int64(verticalAmount))
            scrollEvent.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: Int64(horizontalAmount))

            deliverScrollEvent(
                scrollEvent,
                session: session,
                horizontalAmount: horizontalAmount,
                verticalAmount: verticalAmount
            )
        } else {
            updateScrollDeliveryStatus("failed to create CGEvent")
        }
    }

    func forwardedModifierFlags() -> CGEventFlags {
        let supported: CGEventFlags = [.maskCommand, .maskShift, .maskControl, .maskAlternate, .maskSecondaryFn, .maskNonCoalesced]
        return lastObservedFlags.intersection(supported).union(.maskNonCoalesced)
    }

    @objc func sensitivityChanged(_ sender: NSSlider) {
        scrollSensitivity = sender.doubleValue
        UserDefaults.standard.set(scrollSensitivity, forKey: "scrollSensitivity")

        if let sensitivityItem = statusItem.menu?.items.first(where: { $0.title.starts(with: "Scroll Speed") }) {
            sensitivityItem.title = String(format: "Scroll Speed: %.1fx", scrollSensitivity)
            if let view = sensitivityItem.view,
               let label = view.viewWithTag(100) as? NSTextField {
                label.stringValue = String(format: "%.1fx", scrollSensitivity)
            }
        }
    }

    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "About Scrollapp"
        alert.informativeText = "Scrollapp enables Windows-style auto-scrolling on macOS.\n\nHow to activate:\n• Mouse: Middle click on plain scrollable content\n\nWhile active, move the pointer to control speed and direction.\nHolding Command while autoscroll is running forwards Command+Scroll so apps can zoom instead of plain-scroll when they support it."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    func stopAutoScroll() {
        scrollTimer?.invalidate()
        scrollTimer = nil
        hideIndicator()
        isAutoScrolling = false
        activeSession = nil
        activationButtonIsDown = false
        updateSessionStateStatus("inactive")
    }

    func updateIndicator(for session: AutoscrollSession) {
        if indicatorPanel == nil {
            let size = NSSize(width: 20, height: 20)
            let anchorPoint = session.anchorPoint
            let origin = CGPoint(
                x: anchorPoint.x - size.width / 2,
                y: anchorPoint.y - size.height / 2
            )
            let panel = NSPanel(
                contentRect: NSRect(origin: origin, size: size),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isReleasedWhenClosed = false
            panel.level = .floating
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

            let view = AutoscrollIndicatorView(frame: NSRect(origin: .zero, size: size))
            panel.contentView = view
            indicatorPanel = panel
            panel.orderFront(nil)
        }
    }

    func hideIndicator() {
        indicatorPanel?.orderOut(nil)
        indicatorPanel = nil
    }

    func notePhysicalPointerLocationIfNeeded(for type: CGEventType, event: CGEvent) {
        switch type {
        case .leftMouseDown, .leftMouseUp, .mouseMoved, .leftMouseDragged,
             .rightMouseDown, .rightMouseUp, .rightMouseDragged,
             .otherMouseDown, .otherMouseUp, .otherMouseDragged:
            lastPhysicalPointerLocation = event.unflippedLocation
            lastDeliveryPointerLocation = event.location
        default:
            break
        }
    }

    func accessibilityTargetInfo(at eventPoint: CGPoint) -> AccessibilityTargetInfo? {
        let systemWide = AXUIElementCreateSystemWide()
        for candidate in accessibilityPointCandidates(for: eventPoint) {
            var hitElement: AXUIElement?
            let result = AXUIElementCopyElementAtPosition(systemWide, Float(candidate.x), Float(candidate.y), &hitElement)
            if result == .success, let hitElement {
                return buildAccessibilityTargetInfo(from: hitElement)
            }
        }
        return nil
    }

    func buildAccessibilityTargetInfo(from hitElement: AXUIElement) -> AccessibilityTargetInfo {
        var info = AccessibilityTargetInfo()
        var current: AXUIElement? = hitElement
        var hopCount = 0
        let ancestryDepthLimit = 12
        let urlDepthLimit = 3
        let scrollProbeDepthLimit = 4
        var leafRole: String?
        var leafSubrole: String?
        var leafFrame: CGRect?
        var bestScrollOwnerCandidate: ScrollOwnerCandidate?

        while let element = current, hopCount < ancestryDepthLimit {
            let role = copyAXString(element, attribute: kAXRoleAttribute)
            let subrole = copyAXString(element, attribute: kAXSubroleAttribute)
            let urlString = hopCount <= urlDepthLimit ? copyAXValueString(element, attribute: "AXURL") : nil
            let frame = copyAXFrame(element)

            if let role {
                info.roles.append(role)
            }
            if let subrole {
                info.subroles.append(subrole)
            }

            let actionNames = copyAXStringArray(element, attribute: "AXActions")
            if hopCount == 0, !actionNames.isEmpty {
                info.actionNames = actionNames
                leafRole = role
                leafSubrole = subrole
                leafFrame = normalizedScrollOwnerFrame(frame)
            }

            if info.actionableAncestorDepth == nil,
               isActionableAncestor(
                role: role,
                subrole: subrole,
                actionNames: actionNames
               ) {
                info.actionableAncestorDepth = hopCount
                if hopCount > 0 {
                    info.actionabilityReasons.append("ancestor")
                }
            }
            if info.linkedAncestorDepth == nil,
               isLinkedAncestor(role: role, urlString: urlString) {
                info.linkedAncestorDepth = hopCount
            }

            if let pid = copyPID(for: element) {
                info.pid = pid
            }
            let hasHorizontalScrollBar = copyAXElement(element, attribute: kAXHorizontalScrollBarAttribute) != nil
            let hasVerticalScrollBar = copyAXElement(element, attribute: kAXVerticalScrollBarAttribute) != nil
            if !info.canScrollHorizontally,
               hopCount <= scrollProbeDepthLimit,
               hasHorizontalScrollBar {
                info.canScrollHorizontally = true
            }
            if !info.canScrollVertically,
               hopCount <= scrollProbeDepthLimit,
               hasVerticalScrollBar {
                info.canScrollVertically = true
            }
            if isScrollOwnerCandidate(
                role: role,
                hasHorizontalScrollBar: hasHorizontalScrollBar,
                hasVerticalScrollBar: hasVerticalScrollBar
               ) {
                let candidate = ScrollOwnerCandidate(
                    role: role,
                    subrole: subrole,
                    frame: normalizedScrollOwnerFrame(frame),
                    hasHorizontalScrollBar: hasHorizontalScrollBar,
                    hasVerticalScrollBar: hasVerticalScrollBar,
                    hopCount: hopCount
                )
                if shouldPreferScrollOwnerCandidate(candidate, over: bestScrollOwnerCandidate) {
                    bestScrollOwnerCandidate = candidate
                }
            }

            if hopCount == 0 {
                let actionabilityReasons = actionabilityReasons(
                    role: role,
                    subrole: subrole,
                    actionNames: actionNames,
                    urlString: urlString
                )
                if !actionabilityReasons.isEmpty {
                    info.actionabilityReasons.append(contentsOf: actionabilityReasons)
                }
            }

            current = copyAXElement(element, attribute: kAXParentAttribute)
            hopCount += 1
        }

        info.actionabilityReasons = Array(Set(info.actionabilityReasons)).sorted()
        if let bestScrollOwnerCandidate {
            info.scrollOwnerRole = bestScrollOwnerCandidate.role
            info.scrollOwnerSubrole = bestScrollOwnerCandidate.subrole
            info.scrollOwnerFrame = bestScrollOwnerCandidate.frame
        } else {
            info.scrollOwnerRole = leafRole
            info.scrollOwnerSubrole = leafSubrole
            info.scrollOwnerFrame = leafFrame
        }
        return info
    }


    func targetSnapshot(for info: AccessibilityTargetInfo) -> AutoscrollTargetSnapshot {
        AutoscrollTargetSnapshot(
            roles: info.roles,
            subroles: info.subroles,
            isExplicitlyScrollable: info.canScrollHorizontally || info.canScrollVertically,
            actions: info.actionNames,
            actionableAncestorDepth: info.actionableAncestorDepth,
            linkedAncestorDepth: info.linkedAncestorDepth
        )
    }

    func accessibilityPointCandidates(for eventPoint: CGPoint) -> [CGPoint] {
        var candidates = [eventPoint]
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(eventPoint) }) {
            let flippedPoint = CGPoint(
                x: eventPoint.x,
                y: screen.frame.maxY - eventPoint.y
            )
            if abs(flippedPoint.y - eventPoint.y) > 0.5 {
                candidates.append(flippedPoint)
            }
        }
        return candidates
    }

    func copyAXString(_ element: AXUIElement, attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    func copyAXValueString(_ element: AXUIElement, attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value else {
            return nil
        }
        if let string = value as? String {
            return string
        }
        if let url = value as? URL {
            return url.absoluteString
        }
        if let nsURL = value as? NSURL {
            return nsURL.absoluteString
        }
        return nil
    }

    func copyAXStringArray(_ element: AXUIElement, attribute: String) -> [String] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let strings = value as? [String] else {
            return []
        }
        return strings
    }

    func copyAXElement(_ element: AXUIElement, attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        guard let value else { return nil }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    func copyAXCGPoint(_ element: AXUIElement, attribute: String) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value else {
            return nil
        }
        let axValue = unsafeBitCast(value, to: AXValue.self)
        guard AXValueGetType(axValue) == .cgPoint else {
            return nil
        }
        var point = CGPoint.zero
        guard AXValueGetValue(axValue, .cgPoint, &point) else {
            return nil
        }
        return point
    }

    func copyAXCGSize(_ element: AXUIElement, attribute: String) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value else {
            return nil
        }
        let axValue = unsafeBitCast(value, to: AXValue.self)
        guard AXValueGetType(axValue) == .cgSize else {
            return nil
        }
        var size = CGSize.zero
        guard AXValueGetValue(axValue, .cgSize, &size) else {
            return nil
        }
        return size
    }

    func copyAXFrame(_ element: AXUIElement) -> CGRect? {
        guard let origin = copyAXCGPoint(element, attribute: kAXPositionAttribute),
              let size = copyAXCGSize(element, attribute: kAXSizeAttribute) else {
            return nil
        }
        return CGRect(origin: origin, size: size)
    }

    func copyPID(for element: AXUIElement) -> pid_t? {
        var pid: pid_t = 0
        return AXUIElementGetPid(element, &pid) == .success ? pid : nil
    }

    func normalizedScrollOwnerFrame(_ frame: CGRect?) -> CGRect? {
        guard let frame,
              frame.width > 1,
              frame.height > 1 else {
            return nil
        }
        return CGRect(
            x: frame.origin.x.rounded(),
            y: frame.origin.y.rounded(),
            width: frame.width.rounded(),
            height: frame.height.rounded()
        )
    }

    func isScrollOwnerCandidate(
        role: String?,
        hasHorizontalScrollBar: Bool,
        hasVerticalScrollBar: Bool
    ) -> Bool {
        if hasHorizontalScrollBar || hasVerticalScrollBar {
            return true
        }

        let ownerRoles: Set<String> = [
            "AXBrowser",
            "AXCollection",
            "AXList",
            "AXOutline",
            "AXScrollArea",
            "AXTable",
            "AXTextArea",
            "AXWebArea"
        ]
        guard let role else {
            return false
        }
        return ownerRoles.contains(role)
    }

    func shouldPreferScrollOwnerCandidate(
        _ candidate: ScrollOwnerCandidate,
        over existing: ScrollOwnerCandidate?
    ) -> Bool {
        guard let existing else {
            return true
        }

        let candidateHasExplicitScrollbars = candidate.hasHorizontalScrollBar || candidate.hasVerticalScrollBar
        let existingHasExplicitScrollbars = existing.hasHorizontalScrollBar || existing.hasVerticalScrollBar
        if candidateHasExplicitScrollbars != existingHasExplicitScrollbars {
            return candidateHasExplicitScrollbars
        }

        let candidatePriority = scrollOwnerRolePriority(candidate.role)
        let existingPriority = scrollOwnerRolePriority(existing.role)
        if candidatePriority > existingPriority {
            if let candidateFrame = candidate.frame,
               let existingFrame = existing.frame,
               substantiallyContains(candidateFrame, innerFrame: existingFrame) {
                return true
            }
            return existing.frame == nil && candidate.frame != nil
        }

        if candidatePriority == existingPriority {
            if existing.frame == nil, candidate.frame != nil {
                return true
            }
            if candidateHasExplicitScrollbars,
               let candidateFrame = candidate.frame,
               let existingFrame = existing.frame,
               candidateFrame.equalTo(existingFrame) == false,
               substantiallyContains(existingFrame, innerFrame: candidateFrame) == false,
               candidate.hopCount < existing.hopCount {
                return true
            }
        }

        return false
    }

    func scrollOwnerRolePriority(_ role: String?) -> Int {
        switch role {
        case "AXScrollArea":
            return 5
        case "AXBrowser", "AXCollection", "AXList", "AXOutline", "AXTable":
            return 4
        case "AXWebArea":
            return 3
        case "AXTextArea":
            return 2
        default:
            return 1
        }
    }

    func substantiallyContains(_ outerFrame: CGRect, innerFrame: CGRect) -> Bool {
        guard outerFrame.width > 1,
              outerFrame.height > 1,
              innerFrame.width > 1,
              innerFrame.height > 1 else {
            return false
        }

        let outerInset = max(4, min(outerFrame.width, outerFrame.height) * 0.01)
        let expandedOuter = outerFrame.insetBy(dx: -outerInset, dy: -outerInset)
        guard expandedOuter.contains(innerFrame) else {
            return false
        }

        let outerArea = outerFrame.width * outerFrame.height
        let innerArea = innerFrame.width * innerFrame.height
        guard innerArea > 0 else {
            return false
        }

        return outerArea >= innerArea * 1.5
    }

    func scrollOwner(for info: AccessibilityTargetInfo) -> AutoscrollScrollOwner? {
        guard info.scrollOwnerRole != nil || info.scrollOwnerSubrole != nil || info.scrollOwnerFrame != nil else {
            return nil
        }
        return AutoscrollScrollOwner(
            role: info.scrollOwnerRole,
            subrole: info.scrollOwnerSubrole,
            frame: info.scrollOwnerFrame
        )
    }

    func windowID(at point: CGPoint) -> CGWindowID? {
        if let windowIDResolver {
            return windowIDResolver(point)
        }

        guard let windowInfoList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        var fallbackWindowID: CGWindowID?
        for windowInfo in windowInfoList {
            guard let ownerPIDValue = windowInfo[kCGWindowOwnerPID as String] as? NSNumber,
                  ownerPIDValue.int32Value != getpid(),
                  let numberValue = windowInfo[kCGWindowNumber as String] as? NSNumber,
                  let boundsValue = windowInfo[kCGWindowBounds as String],
                  let boundsDictionary = boundsValue as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDictionary),
                  bounds.width > 1,
                  bounds.height > 1,
                  bounds.contains(point) else {
                continue
            }

            let alpha = (windowInfo[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1
            guard alpha > 0 else {
                continue
            }

            let layer = (windowInfo[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0
            if layer == 0 {
                return CGWindowID(numberValue.uint32Value)
            }
            if fallbackWindowID == nil {
                fallbackWindowID = CGWindowID(numberValue.uint32Value)
            }
        }

        return fallbackWindowID
    }

    struct OwnerMatchState {
        var isMatched: Bool
        var statusText: String
    }

    func ownerMatchState(for currentPoint: CGPoint, session: AutoscrollSession) -> OwnerMatchState {
        if let targetWindowID = session.targetWindowID {
            guard let currentWindowID = windowID(at: currentPoint) else {
                return OwnerMatchState(isMatched: false, statusText: "paused outside latched window")
            }
            guard currentWindowID == targetWindowID else {
                return OwnerMatchState(isMatched: false, statusText: "paused on window mismatch \(currentWindowID)->\(targetWindowID)")
            }
        }

        guard let latchedScrollOwner = session.latchedScrollOwner else {
            return OwnerMatchState(isMatched: true, statusText: "latched owner unavailable")
        }

        if let ownerFrame = latchedScrollOwner.frame {
            if ownerFrame.contains(currentPoint) {
                return OwnerMatchState(isMatched: true, statusText: "within latched owner frame")
            }
            return OwnerMatchState(isMatched: false, statusText: "paused outside latched owner")
        }

        guard let currentInfo = accessibilityTargetInfo(at: currentPoint),
              let currentOwner = scrollOwner(for: currentInfo) else {
            return OwnerMatchState(isMatched: false, statusText: "paused while owner is unresolved")
        }

        if currentOwner == latchedScrollOwner {
            return OwnerMatchState(isMatched: true, statusText: "within latched owner")
        }

        return OwnerMatchState(isMatched: false, statusText: "paused on owner mismatch")
    }

    func isActionable(role: String?, subrole: String?) -> Bool {
        let actionableRoles: Set<String> = [
            "AXButton",
            "AXCheckBox",
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
        let actionableSubroles: Set<String> = [
            "AXCloseButton",
            "AXDeleteButton",
            "AXFullScreenButton",
            "AXMinimizeButton",
            "AXOverflowButton",
            "AXTabButton",
            "AXZoomButton"
        ]
        return (role.map(actionableRoles.contains) ?? false) || (subrole.map(actionableSubroles.contains) ?? false)
    }

    func hasActionableAction(_ actionNames: [String]) -> Bool {
        let actionableActions = Set(["AXOpen", "AXPress", "AXConfirm", "AXPick"])
        return actionNames.contains(where: actionableActions.contains)
    }

    func isActionableAncestor(
        role: String?,
        subrole: String?,
        actionNames _: [String]
    ) -> Bool {
        isActionable(role: role, subrole: subrole)
    }

    func isLinkedAncestor(role: String?, urlString: String?) -> Bool {
        if role == "AXLink" {
            return true
        }

        guard normalizedHTTPURLString(urlString) != nil else {
            return false
        }

        let ignoredURLLinkRoles: Set<String> = [
            "AXApplication",
            "AXBrowser",
            "AXScrollArea",
            "AXWebArea",
            "AXWindow"
        ]
        guard let role else {
            return false
        }

        return !ignoredURLLinkRoles.contains(role)
    }


    func actionabilityReasons(
        role: String?,
        subrole: String?,
        actionNames: [String],
        urlString: String?
    ) -> [String] {
        var reasons = [String]()

        if isActionable(role: role, subrole: subrole) {
            reasons.append("role")
        }

        if hasActionableAction(actionNames) {
            reasons.append("press")
        }

        if normalizedHTTPURLString(urlString) != nil {
            reasons.append("url")
        }

        return Array(Set(reasons)).sorted()
    }

    func normalizedHTTPURLString(_ urlString: String?) -> String? {
        guard let trimmedURLString = urlString?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmedURLString.isEmpty,
              let url = URL(string: trimmedURLString),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return nil
        }
        return url.absoluteString
    }

    func deliverScrollEvent(
        _ scrollEvent: CGEvent,
        session: AutoscrollSession,
        horizontalAmount: Int32,
        verticalAmount: Int32
    ) {
        if let targetPID = session.targetPID,
           !isLatchedTargetAvailable(targetPID) {
            updateStopReasonStatus("stopped by target loss pid=\(targetPID)")
            stopAutoScroll()
            return
        }

        let ownerMatchState = ownerMatchState(for: scrollEvent.location, session: session)
        guard ownerMatchState.isMatched else {
            if isStatusMenuOpen {
                updateScrollDeliveryStatus(ownerMatchState.statusText)
            }
            return
        }

        scrollEvent.post(tap: .cgSessionEventTap)
        if isStatusMenuOpen {
            let routeDescription = session.targetPID.map {
                "session tap live-pointer route (latched pid=\($0))"
            } ?? "session tap live-pointer route (ownerless fallback)"
            updateScrollDeliveryStatus(
                "\(routeDescription) (\(horizontalAmount), \(verticalAmount))"
            )
        }
    }

    func isLatchedTargetAvailable(_ targetPID: pid_t) -> Bool {
        NSRunningApplication(processIdentifier: targetPID) != nil
    }

    @discardableResult
    func checkPermissions(promptForMissingPermissions: Bool = true) -> RuntimePermissionStatus {
        let accessibilityTrusted = AXIsProcessTrusted()
        let canListenEvents = CGPreflightListenEventAccess()
        let canPostEvents = CGPreflightPostEventAccess()
        let status = RuntimePermissionStatus(
            accessibilityTrusted: accessibilityTrusted,
            canListenEvents: canListenEvents,
            canPostEvents: canPostEvents
        )
        runtimePermissionStatus = status

        if promptForMissingPermissions && !accessibilityTrusted {
            let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
            _ = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
        }
        if promptForMissingPermissions && !canListenEvents {
            _ = CGRequestListenEventAccess()
        }
        if promptForMissingPermissions && !canPostEvents {
            _ = CGRequestPostEventAccess()
        }

        updateDiagnosticsMenu()

        guard !accessibilityTrusted || !canListenEvents || !canPostEvents else {
            return status
        }

        guard promptForMissingPermissions else {
            return status
        }

        let alert = NSAlert()
        alert.messageText = "Permissions Required"
        alert.informativeText = "Scrollapp needs Accessibility, Input Monitoring, and event posting access to latch middle-click autoscroll to the original target.\n\nPlease grant the missing permissions in Privacy & Security, then restart the app if needed."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Accessibility")
        alert.addButton(withTitle: "Open Input Monitoring")
        alert.addButton(withTitle: "Skip")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        } else if response == .alertSecondButtonReturn,
                  let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
        return status
    }

    @objc func refreshPermissionsMenuSelected() {
        refreshRuntimeDiagnostics(promptForMissingPermissions: true, retryEventTap: true)
    }

    @objc func toggleDirectionInversion() {
        isDirectionInverted.toggle()
        UserDefaults.standard.set(isDirectionInverted, forKey: "invertScrollDirection")
        if let menu = statusItem.menu,
           let invertItem = menu.items.first(where: { $0.action == #selector(toggleDirectionInversion) }) {
            invertItem.state = isDirectionInverted ? .on : .off
        }
    }

    @objc func toggleLaunchAtLogin() {
        launchAtLogin.toggle()
        UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
        updateLoginItemState()
        if let launchItem = statusItem.menu?.items.first(where: { $0.title == "Launch at Login" }) {
            launchItem.state = launchAtLogin ? .on : .off
        }
    }

    func updateLoginItemState() {
        guard !isAutomatedTestMode else {
            return
        }

        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            do {
                if launchAtLogin {
                    if service.status != .enabled {
                        try service.register()
                    }
                } else if service.status == .enabled {
                    try service.unregister()
                }
            } catch {
                print("Failed to update login item: \(error.localizedDescription)")
            }
        } else if let bundleIdentifier = Bundle.main.bundleIdentifier {
            let success = SMLoginItemSetEnabled(bundleIdentifier as CFString, launchAtLogin)
            if !success {
                print("Failed to update login item using legacy API")
            }
        }
    }
}
