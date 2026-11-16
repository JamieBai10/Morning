import AppKit
import SwiftUI

struct ExpandedFolderView: View {
    @Bindable var store: MorningStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .topLeading) {
            cardShell

            tabButtons

            content
                .frame(
                    width: ExpandedCardV3.contentSlot.width,
                    height: contentSlotHeight,
                    alignment: .topLeading
                )
                .offset(x: ExpandedCardV3.contentSlot.minX, y: contentSlotY)
        }
        .frame(width: MFMetric.expandedWidth, height: MFMetric.expandedHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            dismissTransientState()
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            if store.activeTab == .yesterday {
                Task { await store.refreshYesterdaySummaryIfNeeded() }
            }
        }
    }

    private var cardShell: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: ExpandedCardV3.backplateRadius, style: .continuous)
                .fill(ExpandedCardV3.backplateFill)
                .frame(width: ExpandedCardV3.backplate.width, height: ExpandedCardV3.backplate.height)
                .offset(x: ExpandedCardV3.backplate.minX, y: ExpandedCardV3.backplate.minY)
                .mfShadow(0.06, y: 18, radius: 30)

            UnevenRoundedRectangle(
                topLeadingRadius: ExpandedCardV3.activeTabRadius,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: ExpandedCardV3.activeTabRadius,
                style: .continuous
            )
                .fill(MFColor.raisedSurface)
                .frame(width: activeTabFrame.width, height: activeTabFrame.height)
                .offset(x: activeTabFrame.minX, y: activeTabFrame.minY)

            bodySurface

            tabText(.today, frame: ExpandedCardV3.todayText)
            tabText(.yesterday, frame: ExpandedCardV3.yesterdayText)
            tabText(.mood, frame: ExpandedCardV3.moodText)

            Capsule()
                .fill(MFColor.black)
                .frame(width: underlineFrame.width, height: 5)
                .offset(x: underlineFrame.minX, y: underlineFrame.minY)
        }
        .frame(width: MFMetric.expandedWidth, height: MFMetric.expandedHeight, alignment: .topLeading)
    }

    private var bodySurface: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: bodyRadii.topLeading,
            bottomLeadingRadius: bodyRadii.bottomLeading,
            bottomTrailingRadius: bodyRadii.bottomTrailing,
            topTrailingRadius: bodyRadii.topTrailing,
            style: .continuous
        )
        .fill(MFColor.raisedSurface)
        .frame(width: ExpandedCardV3.body.width, height: ExpandedCardV3.body.height, alignment: .topLeading)
        .offset(x: ExpandedCardV3.body.minX, y: ExpandedCardV3.body.minY)
    }

    private var bodyRadii: (topLeading: CGFloat, bottomLeading: CGFloat, bottomTrailing: CGFloat, topTrailing: CGFloat) {
        switch store.activeTab {
        case .today:
            (0, ExpandedCardV3.bodyRadius, ExpandedCardV3.bodyRadius, ExpandedCardV3.bodyRadius)
        case .yesterday:
            (ExpandedCardV3.bodyRadius, ExpandedCardV3.bodyRadius, ExpandedCardV3.bodyRadius, ExpandedCardV3.bodyRadius)
        case .mood:
            (ExpandedCardV3.bodyRadius, ExpandedCardV3.bodyRadius, ExpandedCardV3.bodyRadius, 0)
        }
    }

    private func tabText(_ tab: MorningTab, frame: CGRect) -> some View {
        Text(tab.rawValue)
            .font(.mfDisplay(tab == store.activeTab ? 24 : 21))
            .foregroundStyle(tab == store.activeTab ? MFColor.black : Color(red: 0.486, green: 0.482, blue: 0.471))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(width: frame.width, height: frame.height, alignment: .center)
            .offset(x: frame.minX, y: frame.minY)
    }

    private var tabButtons: some View {
        ZStack(alignment: .topLeading) {
            tabButton(.today, frame: ExpandedCardV3.todayActiveTab)
            tabButton(.yesterday, frame: ExpandedCardV3.yesterdayActiveTab)
            tabButton(.mood, frame: ExpandedCardV3.moodActiveTab)
        }
        .frame(width: MFMetric.expandedWidth, height: MFMetric.expandedHeight, alignment: .topLeading)
    }

    private func tabButton(_ tab: MorningTab, frame: CGRect) -> some View {
        Button {
            withAnimation(reduceMotion ? .easeOut(duration: 0.14) : MFMotion.state) {
                store.selectTab(tab)
            }
        } label: {
            Rectangle()
                .fill(.clear)
                .frame(width: frame.width, height: frame.height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .offset(x: frame.minX, y: frame.minY)
    }

    private var activeTabFrame: CGRect {
        switch store.activeTab {
        case .today:
            ExpandedCardV3.todayActiveTab
        case .yesterday:
            ExpandedCardV3.yesterdayActiveTab
        case .mood:
            ExpandedCardV3.moodActiveTab
        }
    }

    private var underlineFrame: CGRect {
        switch store.activeTab {
        case .today:
            CGRect(x: 73, y: 107, width: 66, height: 5)
        case .yesterday:
            CGRect(x: 208, y: 107, width: 108, height: 5)
        case .mood:
            CGRect(x: 388, y: 107, width: 60, height: 5)
        }
    }

    private var contentSlotY: CGFloat {
        store.activeTab == .mood ? ExpandedCardV3.moodContentY : ExpandedCardV3.contentSlot.minY
    }

    private var contentSlotHeight: CGFloat {
        store.activeTab == .mood ? ExpandedCardV3.moodContentHeight : ExpandedCardV3.contentSlot.height
    }

    @ViewBuilder
    private var content: some View {
        switch store.activeTab {
        case .today:
            TodayView(store: store)
                .transition(.opacity.combined(with: .offset(y: reduceMotion ? 0 : 6)))
        case .yesterday:
            YesterdayView(stats: store.yesterdayStats, status: store.yesterdaySummaryStatus)
                .transition(.opacity.combined(with: .offset(y: reduceMotion ? 0 : 6)))
        case .mood:
            MoodView(store: store)
                .transition(.opacity.combined(with: .offset(y: reduceMotion ? 0 : 6)))
        }
    }

    private func dismissTransientState() {
        NSApp.keyWindow?.makeFirstResponder(nil)
        if store.fortuneRevealed {
            withAnimation(reduceMotion ? .easeOut(duration: 0.14) : MFMotion.state) {
                store.fortuneRevealed = false
            }
        }
    }
}

private enum ExpandedCardV3 {
    // Source: Figma page "Morning Folder Components V3".
    static let backplate = CGRect(x: 22, y: 42, width: 479, height: 360)
    static let backplateRadius: CGFloat = 38
    static let backplateFill = Color(red: 0.961, green: 0.957, blue: 0.937)

    static let body = CGRect(x: 36, y: 112, width: 452, height: 272)
    static let bodyRadius: CGFloat = 28

    static let activeTabRadius: CGFloat = 28
    static let todayActiveTab = CGRect(x: 36, y: 58, width: 140, height: 73)
    static let yesterdayActiveTab = CGRect(x: 174, y: 58, width: 175, height: 73)
    static let moodActiveTab = CGRect(x: 348, y: 57, width: 140, height: 73)

    static let todayText = CGRect(x: 69, y: 69, width: 74, height: 38)
    static let yesterdayText = CGRect(x: 203, y: 72, width: 118, height: 34)
    static let moodText = CGRect(x: 386, y: 71, width: 62, height: 34)

    static let contentSlot = CGRect(x: 76, y: 144, width: 372, height: 240)
    static let moodContentY: CGFloat = 141
    static let moodContentHeight: CGFloat = 224
}
