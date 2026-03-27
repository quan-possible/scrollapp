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
    private let toggledSessionDescription = "toggled"
    private let verificationCommandNotification = Notification.Name("com.fromis9.scrollapp.verification.command")

    var statusItem: NSStatusItem!
    var diagnosticsMenuItems = [RuntimeDiagnosticItem: NSMenuItem]()
    var diagnosticsState = [RuntimeDiagnosticItem: String]()
    var scrollTimer: Timer?
    var eventTap: CFMachPort?
    var eventTapSource: CFRunLoopSource?
    var indicatorPanel: NSPanel?
    var activeSession: AutoscrollSession?
    var pendingActivationSession: AutoscrollSession?
    var lastScrollStepTime: TimeInterval?
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
    var accessibilityTargetInfoResolver: ((CGPoint) -> AccessibilityTargetInfo?)?
    var verificationObserver: NSObjectProtocol?

    struct AccessibilityTargetInfo {
        var roles = [String]()
        var subroles = [String]()
        var actionNames = [String]()
        var actionableAncestorDepth: Int?
        var linkedAncestorDepth: Int?
        var actionabilityReasons = [String]()
        var canScrollHorizontally = false
        var canScrollVertically = false
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

    var isVerificationMode: Bool {
        let environment = ProcessInfo.processInfo.environment
        let arguments = ProcessInfo.processInfo.arguments
        return isEnabledTestEnvironmentValue(environment["SCROLLAPP_VERIFICATION_MODE"])
            || arguments.contains("--scrollapp-verification-mode")
    }

    var verificationSessionIdentifier: String? {
        let environment = ProcessInfo.processInfo.environment
        let value = verificationArgumentValue(named: "--scrollapp-verification-session")
            ?? environment["SCROLLAPP_VERIFICATION_SESSION"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value, !value.isEmpty else {
            return nil
        }
        return value
    }

    var verificationStatusFileURL: URL? {
        let environment = ProcessInfo.processInfo.environment
        let value = verificationArgumentValue(named: "--scrollapp-verification-status-file")
            ?? environment["SCROLLAPP_VERIFICATION_STATUS_FILE"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value, !value.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: value)
    }

    func isEnabledTestEnvironmentValue(_ value: String?) -> Bool {
        guard let rawValue = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawValue.isEmpty else {
            return false
        }

        let normalized = rawValue.lowercased()
        return normalized != "0" && normalized != "false" && normalized != "no"
    }

    func verificationArgumentValue(named flag: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(arguments.index(after: index)) else {
            return nil
        }
        return arguments[arguments.index(after: index)]
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        isDirectionInverted = UserDefaults.standard.bool(forKey: "invertScrollDirection")
        launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
        scrollSensitivity = UserDefaults.standard.double(forKey: "scrollSensitivity")
        if scrollSensitivity == 0 {
            scrollSensitivity = 1.0
        }

        setupMenuBar()

        if isVerificationMode {
            checkPermissions(promptForMissingPermissions: false)
            setupVerificationCommandObserver()
            writeVerificationStatus(
                sequence: nil,
                command: "ready",
                ok: true,
                message: "verification command observer ready"
            )
            return
        }

        guard !isAutomatedTestMode else {
            return
        }

        updateLoginItemState()
        refreshRuntimeDiagnostics(promptForMissingPermissions: true, retryEventTap: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        tearDownVerificationCommandObserver()
        stopAutoScroll()
        tearDownEventTap()
    }

    func setupVerificationCommandObserver() {
        guard verificationObserver == nil,
              let verificationSessionIdentifier else {
            return
        }

        verificationObserver = DistributedNotificationCenter.default().addObserver(
            forName: verificationCommandNotification,
            object: verificationSessionIdentifier,
            queue: .main
        ) { [weak self] notification in
            self?.handleVerificationCommand(notification)
        }
    }

    func tearDownVerificationCommandObserver() {
        guard let verificationObserver else {
            return
        }
        DistributedNotificationCenter.default().removeObserver(verificationObserver)
        self.verificationObserver = nil
    }

    func handleVerificationCommand(_ notification: Notification) {
        guard let userInfo = notification.userInfo else {
            writeVerificationStatus(
                sequence: nil,
                command: "unknown",
                ok: false,
                message: "missing verification command payload"
            )
            return
        }

        let sequence = userInfo["sequence"] as? Int
        let command = (userInfo["command"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"

        switch command {
        case "activate_toggle":
            guard let physicalPoint = verificationPoint(xKey: "physicalX", yKey: "physicalY", userInfo: userInfo),
                  let deliveryPoint = verificationPoint(xKey: "deliveryX", yKey: "deliveryY", userInfo: userInfo) else {
                writeVerificationStatus(sequence: sequence, command: command, ok: false, message: "missing activation point")
                return
            }
            let started = activateVerificationToggle(physicalPoint: physicalPoint, deliveryPoint: deliveryPoint)
            writeVerificationStatus(
                sequence: sequence,
                command: command,
                ok: started,
                message: started ? "activated toggled autoscroll session" : "failed to activate autoscroll session"
            )
        case "set_pointer":
            guard let physicalPoint = verificationPoint(xKey: "physicalX", yKey: "physicalY", userInfo: userInfo),
                  let deliveryPoint = verificationPoint(xKey: "deliveryX", yKey: "deliveryY", userInfo: userInfo) else {
                writeVerificationStatus(sequence: sequence, command: command, ok: false, message: "missing pointer sample")
                return
            }
            lastPhysicalPointerLocation = physicalPoint
            lastDeliveryPointerLocation = deliveryPoint
            writeVerificationStatus(sequence: sequence, command: command, ok: true, message: "pointer sample updated")
        case "perform_scroll":
            let count = max(1, userInfo["count"] as? Int ?? 1)
            for _ in 0..<count {
                performScroll()
            }
            writeVerificationStatus(sequence: sequence, command: command, ok: true, message: "performed \(count) scroll step(s)")
        case "stop":
            stopAutoScroll()
            writeVerificationStatus(sequence: sequence, command: command, ok: true, message: "stopped autoscroll session")
        case "snapshot":
            writeVerificationStatus(sequence: sequence, command: command, ok: true, message: "snapshot")
        default:
            writeVerificationStatus(sequence: sequence, command: command, ok: false, message: "unknown verification command")
        }
    }

    func verificationPoint(xKey: String, yKey: String, userInfo: [AnyHashable: Any]) -> CGPoint? {
        guard let x = verificationDoubleValue(userInfo[xKey]),
              let y = verificationDoubleValue(userInfo[yKey]) else {
            return nil
        }
        return CGPoint(x: x, y: y)
    }

    func verificationDoubleValue(_ value: Any?) -> CGFloat? {
        switch value {
        case let number as NSNumber:
            return CGFloat(number.doubleValue)
        case let string as String:
            guard let parsed = Double(string.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                return nil
            }
            return CGFloat(parsed)
        default:
            return nil
        }
    }

    func activateVerificationToggle(physicalPoint: CGPoint, deliveryPoint: CGPoint) -> Bool {
        lastPhysicalPointerLocation = physicalPoint
        lastDeliveryPointerLocation = deliveryPoint

        guard let startedSession = classifyActivation(at: deliveryPoint) else {
            return false
        }

        startAutoScroll(with: sessionForActivation(anchorPoint: physicalPoint, classifiedSession: startedSession))
        activationButtonIsDown = false

        guard activeSession != nil else {
            return false
        }

        updateSessionStateStatus(sessionStateDescription(buttonDown: false))
        return true
    }

    func writeVerificationStatus(
        sequence: Int?,
        command: String,
        ok: Bool,
        message: String
    ) {
        guard let verificationStatusFileURL else {
            return
        }

        let sessionMode = activeSession == nil ? "nil" : toggledSessionDescription
        let payload: [String: Any] = [
            "ready": true,
            "pid": getpid(),
            "sequence": sequence ?? NSNull(),
            "command": command,
            "ok": ok,
            "message": message,
            "isAutoScrolling": isAutoScrolling,
            "sessionMode": sessionMode,
            "sessionState": diagnosticsState[.sessionState] ?? RuntimeDiagnosticItem.sessionState.placeholderTitle,
            "scrollEmission": diagnosticsState[.scrollEmission] ?? RuntimeDiagnosticItem.scrollEmission.placeholderTitle,
            "scrollDelivery": diagnosticsState[.scrollDelivery] ?? RuntimeDiagnosticItem.scrollDelivery.placeholderTitle,
            "stopReason": diagnosticsState[.stopReason] ?? RuntimeDiagnosticItem.stopReason.placeholderTitle,
            "activationDecision": diagnosticsState[.activationDecision] ?? RuntimeDiagnosticItem.activationDecision.placeholderTitle,
            "axHitTest": diagnosticsState[.axHitTest] ?? RuntimeDiagnosticItem.axHitTest.placeholderTitle,
            "permissions": [
                "accessibility": runtimePermissionStatus.accessibilityTrusted,
                "listenEvents": runtimePermissionStatus.canListenEvents,
                "postEvents": runtimePermissionStatus.canPostEvents
            ]
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: verificationStatusFileURL, options: .atomic)
        } catch {
            NSLog("Failed to write verification status: %@", error.localizedDescription)
        }
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
            return Unmanaged.passUnretained(event)
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

            updateActivationMatchStatus("stop by other button \(buttonNumber)")
            updateActivationDecisionStatus("stop active autoscroll")
            return handleStopClick(event, buttonNumber: buttonNumber)
        }

        if buttonNumber != activationButtonNumber {
            updateActivationMatchStatus("no (button \(buttonNumber) != \(activationButtonNumber))")
            updateActivationDecisionStatus("pass through (button mismatch)")
            return Unmanaged.passUnretained(event)
        }

        activationButtonIsDown = true
        updateActivationMatchStatus("yes")

        guard let session = classifyActivation(at: deliveryPoint) else {
            activationButtonIsDown = false
            return Unmanaged.passUnretained(event)
        }

        swallowedButtons.insert(buttonNumber)
        pendingActivationSession = sessionForActivation(anchorPoint: activationPoint, classifiedSession: session)
        updateActivationDecisionStatus("armed toggle on release")
        return nil
    }

    func handleOtherMouseUp(_ event: CGEvent, buttonNumber: Int) -> Unmanaged<CGEvent>? {
        lastPhysicalPointerLocation = event.unflippedLocation
        lastDeliveryPointerLocation = event.location
        if buttonNumber == activationButtonNumber {
            activationButtonIsDown = false
        }

        if swallowedButtons.contains(buttonNumber) {
            swallowedButtons.remove(buttonNumber)

            if let session = pendingActivationSession, buttonNumber == activationButtonNumber {
                pendingActivationSession = nil
                startAutoScroll(with: session)
                return nil
            }

            if activeSession != nil, buttonNumber == activationButtonNumber {
                updateSessionStateStatus(sessionStateDescription(buttonDown: false))
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
        if buttonNumber == 0 {
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

    func classifyActivation(at eventPoint: CGPoint) -> AutoscrollSession? {
        guard let info = accessibilityTargetInfo(at: eventPoint) else {
            updateAXHitTestStatus("failed @ \(Int(eventPoint.x.rounded())),\(Int(eventPoint.y.rounded()))")
            updateActivationDecisionStatus("pass through (no AX target)")
            return nil
        }

        let snapshot = targetSnapshot(for: info)
        updateAXHitTestStatus(
            "\(summarizeRoles(info.roles)) [H:\(info.canScrollHorizontally ? "Y" : "N") V:\(info.canScrollVertically ? "Y" : "N")\(!info.actionabilityReasons.isEmpty ? " actionable" : "")\(summarizeActionability(info.actionabilityReasons))]"
        )

        let resolution = AutoscrollTargetClassifier.classify(snapshot)
        if !resolution.shouldStart {
            updateActivationDecisionStatus("pass through (classifier)")
            return nil
        }

        let fallbackAxes = resolution.fallbackAxes
        let canScrollHorizontally = info.canScrollHorizontally || fallbackAxes.horizontal
        let canScrollVertically = info.canScrollVertically || fallbackAxes.vertical

        guard canScrollHorizontally || canScrollVertically else {
            updateActivationDecisionStatus("pass through (no scroll axes)")
            return nil
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

        return AutoscrollSession(
            anchorPoint: eventPoint,
            targetWindowID: windowID(at: eventPoint),
            canScrollHorizontally: canScrollHorizontally,
            canScrollVertically: canScrollVertically,
            activationButtonNumber: activationButtonNumber
        )
    }

    func sessionForActivation(anchorPoint: CGPoint, classifiedSession: AutoscrollSession) -> AutoscrollSession {
        AutoscrollSession(
            anchorPoint: anchorPoint,
            targetWindowID: classifiedSession.targetWindowID,
            canScrollHorizontally: classifiedSession.canScrollHorizontally,
            canScrollVertically: classifiedSession.canScrollVertically,
            activationButtonNumber: classifiedSession.activationButtonNumber,
            velocity: classifiedSession.velocity,
            emissionCarry: classifiedSession.emissionCarry
        )
    }

    func sessionStateDescription(buttonDown: Bool, dx: CGFloat = 0, dy: CGFloat = 0) -> String {
        String(
            format: "mode=%@ buttonDown=%@ dx=%.0f dy=%.0f",
            toggledSessionDescription as NSString,
            buttonDown ? "Y" : "N",
            dx,
            dy
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
        let windowDescription = session.targetWindowID.map { "window=\($0)" } ?? "window=none"
        updateScrollDeliveryStatus("armed session tap live-pointer delivery (\(windowDescription))")
        updateSessionStateStatus(sessionStateDescription(buttonDown: activationButtonIsDown))
        updateStopReasonStatus("None")
        updateIndicator(for: session)
        lastScrollStepTime = ProcessInfo.processInfo.systemUptime

        scrollTimer = Timer.scheduledTimer(withTimeInterval: AutoscrollBehavior.preferredTickInterval, repeats: true) { [weak self] _ in
            self?.performScroll()
        }
        RunLoop.current.add(scrollTimer!, forMode: .common)
    }

    func performScroll() {
        guard var session = activeSession else { return }

        let now = ProcessInfo.processInfo.systemUptime
        let elapsedTime = AutoscrollBehavior.normalizedElapsedTime(
            lastScrollStepTime.map { now - $0 }
        )
        lastScrollStepTime = now

        let currentPoint = lastPhysicalPointerLocation ?? session.anchorPoint
        let currentDeliveryPoint = lastDeliveryPointerLocation ?? session.anchorPoint
        let ownerDeliveryAllowed = ownerMatchState(for: currentDeliveryPoint, session: session)
        let shouldReportDetailedDiagnostics = isStatusMenuOpen || isVerificationMode
        let targetVelocity = AutoscrollBehavior.velocity(
            anchorPoint: session.anchorPoint,
            currentPoint: currentPoint,
            sensitivity: scrollSensitivity,
            invertVertical: isDirectionInverted,
            axes: AutoscrollAxes(
                horizontal: session.canScrollHorizontally,
                vertical: session.canScrollVertically
            )
        )

        session.velocity = AutoscrollBehavior.smoothedVelocity(
            previous: session.velocity,
            target: targetVelocity,
            elapsedTime: elapsedTime
        )
        if shouldReportDetailedDiagnostics {
            updateSessionStateStatus(
                sessionStateDescription(
                    buttonDown: activationButtonIsDown,
                    dx: currentPoint.x - session.anchorPoint.x,
                    dy: currentPoint.y - session.anchorPoint.y
                )
            )
            updateScrollEmissionStatus(
                String(
                    format: "mode=%@ vx=%.1f vy=%.1f",
                    toggledSessionDescription as NSString,
                    session.velocity.horizontal,
                    session.velocity.vertical
                )
            )
        }

        activeSession = session
        updateIndicator(for: session)

        if !ownerDeliveryAllowed.isMatched {
            if shouldReportDetailedDiagnostics {
                updateScrollDeliveryStatus(ownerDeliveryAllowed.statusText)
            }
            return
        }

        guard AutoscrollBehavior.shouldEmitScroll(session.velocity) else {
            if shouldReportDetailedDiagnostics {
                updateScrollDeliveryStatus("idle (inside dead zone)")
            }
            return
        }

        let emissionStep = AutoscrollBehavior.emissionStep(
            velocity: AutoscrollVelocity(
                horizontal: session.canScrollHorizontally ? session.velocity.horizontal : 0,
                vertical: session.canScrollVertically ? session.velocity.vertical : 0
            ),
            elapsedTime: elapsedTime,
            carry: session.emissionCarry
        )
        session.emissionCarry = emissionStep.carry
        activeSession = session

        let horizontalAmount = Int32(emissionStep.delta.horizontal)
        let verticalAmount = Int32(emissionStep.delta.vertical)
        guard horizontalAmount != 0 || verticalAmount != 0 else {
            if shouldReportDetailedDiagnostics {
                updateScrollDeliveryStatus("idle (subpixel carry)")
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
        pendingActivationSession = nil
        lastScrollStepTime = nil
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
        if let accessibilityTargetInfoResolver {
            return accessibilityTargetInfoResolver(eventPoint)
        }

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

        while let element = current, hopCount < ancestryDepthLimit {
            let role = copyAXString(element, attribute: kAXRoleAttribute)
            let subrole = copyAXString(element, attribute: kAXSubroleAttribute)
            let urlString = hopCount <= urlDepthLimit ? copyAXValueString(element, attribute: "AXURL") : nil

            if let role {
                info.roles.append(role)
            }
            if let subrole {
                info.subroles.append(subrole)
            }

            let actionNames = copyAXStringArray(element, attribute: "AXActions")
            if hopCount == 0, !actionNames.isEmpty {
                info.actionNames = actionNames
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
            return OwnerMatchState(isMatched: true, statusText: "within latched window")
        }

        return OwnerMatchState(isMatched: true, statusText: "latched window unavailable")
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
        actionNames: [String]
    ) -> Bool {
        isActionable(role: role, subrole: subrole) || hasActionableAction(actionNames)
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
        let shouldReportDetailedDiagnostics = isStatusMenuOpen || isVerificationMode
        let ownerMatchState = ownerMatchState(for: scrollEvent.location, session: session)
        guard ownerMatchState.isMatched else {
            if shouldReportDetailedDiagnostics {
                updateScrollDeliveryStatus(ownerMatchState.statusText)
            }
            return
        }

        scrollEvent.post(tap: .cgSessionEventTap)
        if shouldReportDetailedDiagnostics {
            updateScrollDeliveryStatus(
                "session tap live-pointer route (\(horizontalAmount), \(verticalAmount))"
            )
        }
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
        let desiredState = !launchAtLogin
        if applyLaunchAtLoginState(desiredState) == false {
            NSSound.beep()
        }
    }

    func updateLoginItemState() {
        let resolvedState = resolvedLaunchAtLoginState()
        launchAtLogin = resolvedState
        UserDefaults.standard.set(resolvedState, forKey: "launchAtLogin")
        if let launchItem = statusItem.menu?.items.first(where: { $0.title == "Launch at Login" }) {
            launchItem.state = resolvedState ? .on : .off
        }
    }

    @discardableResult
    func applyLaunchAtLoginState(_ desiredState: Bool) -> Bool {
        guard !isAutomatedTestMode else {
            launchAtLogin = desiredState
            UserDefaults.standard.set(desiredState, forKey: "launchAtLogin")
            if let launchItem = statusItem.menu?.items.first(where: { $0.title == "Launch at Login" }) {
                launchItem.state = desiredState ? .on : .off
            }
            return true
        }

        var operationSucceeded = false
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            do {
                if desiredState {
                    if service.status != .enabled {
                        try service.register()
                    }
                } else if service.status == .enabled {
                    try service.unregister()
                }
                operationSucceeded = true
            } catch {
                print("Failed to update login item: \(error.localizedDescription)")
            }
        } else if let bundleIdentifier = Bundle.main.bundleIdentifier {
            operationSucceeded = SMLoginItemSetEnabled(bundleIdentifier as CFString, desiredState)
            if !operationSucceeded {
                print("Failed to update login item using legacy API")
            }
        }

        updateLoginItemState()
        return operationSucceeded && launchAtLogin == desiredState
    }

    func resolvedLaunchAtLoginState() -> Bool {
        guard !isAutomatedTestMode else {
            return launchAtLogin
        }

        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }

        return launchAtLogin
    }
}
