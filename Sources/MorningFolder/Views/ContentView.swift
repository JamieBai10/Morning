import AppKit
import SwiftUI

struct ContentView: View {
    @Bindable var store: MorningStore
    @Bindable var preferences: MorningPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPeeking = false

    var body: some View {
        let widgetSize = MFMetric.widgetSize(isExpanded: store.isExpanded)
        let scaledSize = MFMetric.widgetSize(isExpanded: store.isExpanded, scale: preferences.widgetScale)

        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    guard store.isExpanded else { return }
                    NSApp.keyWindow?.makeFirstResponder(nil)
                    if store.fortuneRevealed {
                        withAnimation(MFMotion.state) {
                            store.fortuneRevealed = false
                        }
                    }
                }

            if store.isExpanded {
                ExpandedFolderView(store: store)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: reduceMotion ? 1 : 0.92)).combined(with: .offset(y: reduceMotion ? 0 : -8)),
                        removal: .opacity.combined(with: .scale(scale: reduceMotion ? 1 : 0.96)).combined(with: .offset(y: reduceMotion ? 0 : 12))
                    ))
            } else {
                CollapsedFolderView(isPeeking: isPeeking, onOpen: openFolder)
                    .transition(.opacity.combined(with: .scale(scale: reduceMotion ? 1 : 0.98)))
            }
        }
        .frame(
            width: widgetSize.width,
            height: widgetSize.height
        )
        .scaleEffect(preferences.widgetScale)
        .frame(width: scaledSize.width, height: scaledSize.height)
        .background(Color.clear)
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            store.refreshTaskDayIfNeeded()
        }
        .background(EscapeKeyMonitor(onEscape: handleEscape))
        .animation(reduceMotion ? .easeOut(duration: 0.14) : MFMotion.soft, value: store.isExpanded)
    }

    private func handleEscape() {
        let handled = withAnimation(MFMotion.state) {
            store.handleEscapeWithinWidget()
        }

        if !handled {
            NSApp.terminate(nil)
        }
    }

    private func openFolder() {
        guard !store.isExpanded else { return }

        if reduceMotion {
            store.isExpanded = true
            return
        }

        withAnimation(.timingCurve(0.16, 0.84, 0.24, 1, duration: 0.07)) {
            isPeeking = true
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(115))
            withAnimation(.timingCurve(0.42, 0, 0.74, 0.42, duration: 0.05)) {
                isPeeking = false
            }
            try? await Task.sleep(for: .milliseconds(45))
            withAnimation(MFMotion.soft) {
                store.isExpanded = true
            }
        }
    }
}
