import AppKit
import Foundation

final class FixtureAppDelegate: NSObject, NSApplicationDelegate {
    private let stateFileURL: URL
    private var window: NSWindow?
    private var scrollView: NSScrollView?
    private var documentView: NSView?
    private var stateTimer: Timer?
    private var targetPoint: CGPoint = .zero
    private var physicalTargetPoint: CGPoint = .zero
    private let initialVerticalOffset: CGFloat = 420

    init(stateFileURL: URL) {
        self.stateFileURL = stateFileURL
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        guard let screen = screenContainingCursor() else {
            writeState(ready: false, message: "no screen found for cursor")
            NSApp.terminate(nil)
            return
        }

        targetPoint = NSEvent.mouseLocation
        let windowSize = NSSize(width: 520, height: 520)
        var origin = CGPoint(
            x: targetPoint.x - windowSize.width / 2,
            y: targetPoint.y - windowSize.height * 0.38
        )
        origin.x = max(screen.visibleFrame.minX, min(origin.x, screen.visibleFrame.maxX - windowSize.width))
        origin.y = max(screen.visibleFrame.minY, min(origin.y, screen.visibleFrame.maxY - windowSize.height))

        let window = NSWindow(
            contentRect: NSRect(origin: origin, size: windowSize),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Scrollapp Verification Fixture"
        window.isOpaque = true
        window.backgroundColor = NSColor.windowBackgroundColor
        window.level = .floating

        let rootView = NSView(frame: NSRect(origin: .zero, size: windowSize))
        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let scrollFrame = NSRect(x: 20, y: 20, width: windowSize.width - 40, height: windowSize.height - 40)
        let scrollView = NSScrollView(frame: scrollFrame)
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.borderType = .bezelBorder

        let documentView = NSView(frame: NSRect(x: 0, y: 0, width: scrollFrame.width - 18, height: 3600))
        documentView.wantsLayer = true
        documentView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        for index in 0..<36 {
            let stripe = NSView(frame: NSRect(x: 0, y: CGFloat(index) * 100, width: documentView.frame.width, height: 100))
            stripe.wantsLayer = true
            stripe.layer?.backgroundColor = (index % 2 == 0
                ? NSColor.systemBlue.withAlphaComponent(0.12)
                : NSColor.systemGreen.withAlphaComponent(0.12)).cgColor

            let label = NSTextField(labelWithString: "Fixture row \(index + 1)")
            label.frame = NSRect(x: 24, y: 34, width: 240, height: 32)
            label.font = NSFont.systemFont(ofSize: 28, weight: .medium)
            stripe.addSubview(label)
            documentView.addSubview(stripe)
        }

        scrollView.documentView = documentView
        rootView.addSubview(scrollView)
        window.contentView = rootView
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
        self.scrollView = scrollView
        self.documentView = documentView
        let targetInScrollView = CGPoint(x: scrollView.bounds.midX, y: scrollView.bounds.midY)
        let targetInRootView = scrollView.convert(targetInScrollView, to: rootView)
        let targetInWindow = rootView.convert(targetInRootView, to: nil)
        physicalTargetPoint = window.convertPoint(toScreen: targetInWindow)
        targetPoint = quartzGlobalPoint(fromAppKitScreenPoint: physicalTargetPoint, screen: window.screen)

        setVerticalOffset(initialVerticalOffset)
        writeState(ready: true, message: "fixture ready")

        stateTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.writeState(ready: true, message: "fixture ready")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        stateTimer?.invalidate()
        stateTimer = nil
    }

    private func screenContainingCursor() -> NSScreen? {
        let cursor = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(cursor) }) ?? NSScreen.main
    }

    private func setVerticalOffset(_ offset: CGFloat) {
        guard let scrollView, let documentView else {
            return
        }
        let maxOffset = max(0, documentView.bounds.height - scrollView.contentView.bounds.height)
        let constrained = max(0, min(offset, maxOffset))
        scrollView.contentView.scroll(to: CGPoint(x: 0, y: constrained))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private func quartzGlobalPoint(fromAppKitScreenPoint point: CGPoint, screen: NSScreen?) -> CGPoint {
        guard let screen else {
            return point
        }

        return CGPoint(
            x: point.x,
            y: screen.frame.maxY - point.y
        )
    }

    private func quartzGlobalRect(fromAppKitScreenRect rect: CGRect, screen: NSScreen?) -> CGRect {
        guard let screen else {
            return rect
        }

        return CGRect(
            x: rect.origin.x,
            y: screen.frame.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    private func writeState(ready: Bool, message: String) {
        let scrollOffset = scrollView?.contentView.bounds.origin.y ?? 0
        let frame = quartzGlobalRect(fromAppKitScreenRect: window?.frame ?? .zero, screen: window?.screen)
        let payload: [String: Any] = [
            "ready": ready,
            "message": message,
            "pid": ProcessInfo.processInfo.processIdentifier,
            "targetX": targetPoint.x,
            "targetY": targetPoint.y,
            "physicalTargetX": physicalTargetPoint.x,
            "physicalTargetY": physicalTargetPoint.y,
            "initialVerticalOffset": initialVerticalOffset,
            "currentVerticalOffset": scrollOffset,
            "windowFrame": [
                "x": frame.origin.x,
                "y": frame.origin.y,
                "width": frame.width,
                "height": frame.height
            ]
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: stateFileURL, options: .atomic)
        } catch {
            fputs("Failed to write fixture state: \(error.localizedDescription)\n", stderr)
        }
    }
}

let arguments = CommandLine.arguments.dropFirst()
guard let statePath = arguments.first else {
    fputs("Usage: swift scripts/external_scroll_fixture.swift <state-file>\n", stderr)
    exit(64)
}

let delegate = FixtureAppDelegate(stateFileURL: URL(fileURLWithPath: statePath))
let application = NSApplication.shared
application.delegate = delegate
application.run()
