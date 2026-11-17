import AppKit
import Observation
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let preferences = MorningPreferences()
    private lazy var store = MorningStore(preferences: preferences)
    private var panel: KeyableMorningPanel?
    private var didPlaceInitialPanel = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        FontRegistry.registerBundledFonts()
        NSApp.setActivationPolicy(.regular)
        createPanel()
        observeExpansionState()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        // The main interface is our AppKit panel. SwiftUI's only scene is
        // Settings, so allowing an untitled window opens Settings at launch.
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMorning()
        return false
    }

    @MainActor
    private func createPanel() {
        let initialSize = MFMetric.widgetSize(isExpanded: store.isExpanded)
        let panel = KeyableMorningPanel(
            contentRect: CGRect(origin: .zero, size: initialSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        panel.title = "Morning"
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        panel.level = .floating
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary
        ]
        let hostingView = TransparentMorningHostingView(rootView: ContentView(store: store))
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hostingView

        self.panel = panel
        resizePanel(animated: false)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor
    private func resizePanel(animated: Bool) {
        guard let panel else { return }

        let targetSize = MFMetric.widgetSize(isExpanded: store.isExpanded)
        let oldFrame = panel.frame
        let center = didPlaceInitialPanel
            ? CGPoint(x: oldFrame.midX, y: oldFrame.midY)
            : initialPanelCenter(for: targetSize)

        var newFrame = CGRect(origin: .zero, size: targetSize)
        newFrame.origin = CGPoint(x: center.x - targetSize.width / 2, y: center.y - targetSize.height / 2)

        panel.minSize = targetSize
        panel.maxSize = targetSize
        panel.setFrame(newFrame, display: true, animate: animated && didPlaceInitialPanel)
        panel.makeKeyAndOrderFront(nil)
        if store.isExpanded {
            NSApp.activate(ignoringOtherApps: true)
        }
        didPlaceInitialPanel = true
    }

    @MainActor
    private func initialPanelCenter(for targetSize: CGSize) -> CGPoint {
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        guard screenFrame != .zero else {
            return CGPoint(x: targetSize.width / 2, y: targetSize.height / 2)
        }

        let x = screenFrame.maxX - targetSize.width / 2 - 72
        let y = screenFrame.maxY - targetSize.height / 2 - 96
        return CGPoint(x: x, y: y)
    }

    private func observeExpansionState() {
        withObservationTracking {
            _ = store.isExpanded
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.resizePanel(animated: true)
                self?.observeExpansionState()
            }
        }
    }

    func showMorning() {
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

final class TransparentMorningHostingView<Content: View>: NSHostingView<Content> {
    override var isOpaque: Bool { false }
}

final class KeyableMorningPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@main
struct MorningFolderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(preferences: appDelegate.preferences)
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(after: .appInfo) {
                Button("Show Morning") {
                    appDelegate.showMorning()
                }
                .keyboardShortcut("0")
            }
            CommandGroup(replacing: .appTermination) {
                Button("Quit Morning") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
    }
}
