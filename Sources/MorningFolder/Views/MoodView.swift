import AppKit
import SwiftUI

struct MoodView: View {
    @Bindable var store: MorningStore
    @State private var copiedHex: String?
    @State private var captureDraft = ""
    @State private var captureFeedback: String?
    @State private var isCaptureFeedbackVisible = false
    @FocusState private var captureFocused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                miniCalendarStrip
                    .offset(x: 0, y: -5)

                paletteTile
                    .offset(x: 0, y: 82)

                fortuneTile
                    .offset(x: 232, y: 82)

                captureBar
                    .offset(x: 0, y: 190)
            }
            .blur(radius: store.fortuneRevealed ? 5 : 0)

            if store.fortuneRevealed {
                fortunePanel
                    .frame(width: 250, height: 236, alignment: .topLeading)
                    .offset(x: 61, y: -13)
                    .transition(.opacity.combined(with: .scale(scale: 0.985)).combined(with: .offset(y: 8)))
                    .zIndex(2)
            }
        }
        .frame(width: 372, height: 224, alignment: .topLeading)
        .animation(MFMotion.soft, value: store.fortuneRevealed)
        .onAppear {
            store.refreshFortuneIfNeeded()
            Task {
                await store.refreshLuckyColorsIfNeeded()
            }
        }
        .onReceive(Timer.publish(every: 300, on: .main, in: .common).autoconnect()) { _ in
            store.refreshFortuneIfNeeded()
            Task {
                await store.refreshLuckyColorsIfNeeded()
            }
        }
    }

    private var miniCalendarStrip: some View {
        ZStack(alignment: .topLeading) {
            tileSurface(width: 372, height: 70, shadowOpacity: 0.05, shadowY: 14, shadowRadius: 22, showsInnerTopLight: true)
                .frame(width: 372, height: 70)

            HStack {
                caption("THIS WEEK")
                Spacer()
                caption(currentMonthLabel)
                    .opacity(0.68)
            }
            .frame(width: 336, height: 12)
            .offset(x: 16, y: 8)

            ForEach(Array(weekItems.enumerated()), id: \.element.id) { index, item in
                calendarColumn(item: item)
                    .offset(x: miniCalendarX(for: index), y: 21)
            }
        }
        .frame(width: 372, height: 78, alignment: .topLeading)
        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 4)
    }

    private func calendarColumn(item: CalendarItem) -> some View {
        VStack(spacing: 2) {
            Text(item.weekday)
                .font(.mfEnglish(8.5, weight: .semibold))
                .tracking(0.2)
                .foregroundStyle(Color(red: 0.294, green: 0.294, blue: 0.278).opacity(0.62))
                .frame(width: 24, height: 14)

            ZStack {
                if item.isToday {
                    Circle()
                        .fill(MFColor.black)
                        .frame(width: 26, height: 26)
                }

                Text(item.day)
                    .font(.mfEnglish(item.isToday ? 13 : 11.4, weight: .semibold))
                    .foregroundStyle(item.isToday ? Color.white : Color(red: 0.082, green: 0.082, blue: 0.082).opacity(0.52))
                    .monospacedDigit()
            }
            .frame(width: 26, height: 26)
        }
        .frame(width: 26, height: 48, alignment: .top)
    }

    private var paletteTile: some View {
        ZStack(alignment: .topLeading) {
            tileSurface(width: 216, height: 84, shadowOpacity: 0.05, shadowY: 10, shadowRadius: 20)
                .frame(width: 216, height: 84)

            caption("TODAY’S COLORS", tracking: 0.85)
                .offset(x: 17, y: 8)

            ForEach(Array(store.luckyColors.prefix(3).enumerated()), id: \.element.id) { index, color in
                Button {
                    copyHex(color.hex)
                } label: {
                    ZStack(alignment: .topLeading) {
                        Circle()
                            .fill(color.color)
                            .frame(width: 30, height: 30)
                            .offset(x: 0, y: 0)

                        Text(copiedHex == color.hex ? "COPIED" : color.hex)
                            .font(.mfEnglish(9.1, weight: .semibold))
                            .foregroundStyle(MFColor.graphite.opacity(copiedHex == color.hex ? 0.72 : 0.96))
                            .monospaced()
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .offset(x: 0, y: 33)
                    }
                    .frame(width: 52, height: 47, alignment: .topLeading)
                }
                .buttonStyle(.plain)
                .offset(x: paletteX(for: index), y: 27)
            }

            if store.luckyColors.isEmpty {
                Text("今日幸运色待更新")
                    .font(.mfSectionTitle(11))
                    .foregroundStyle(MFColor.graphite.opacity(0.52))
                    .frame(width: 182, height: 36, alignment: .center)
                    .offset(x: 17, y: 34)
            }
        }
        .frame(width: 216, height: 84, alignment: .topLeading)
        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 4)
    }

    private var fortuneTile: some View {
        Button {
            withAnimation(MFMotion.soft) {
                store.fortuneRevealed.toggle()
            }
        } label: {
            ZStack(alignment: .topLeading) {
                tileSurface(width: 140, height: 84, shadowOpacity: 0.04, shadowY: 8, shadowRadius: 16)
                    .frame(width: 140, height: 84)

                FortuneCookieAsset(name: "fortune-cookie-closed")
                    .frame(width: 46, height: 46)
                    .offset(x: 47, y: 6)

                Text("FORTUNE COOKIE")
                    .font(.mfEnglish(7.6, weight: .semibold))
                    .foregroundStyle(Color(red: 0.294, green: 0.294, blue: 0.278).opacity(0.62))
                    .lineLimit(1)
                    .frame(width: 104, height: 13, alignment: .center)
                    .offset(x: 18, y: 58)
            }
            .frame(width: 140, height: 84, alignment: .topLeading)
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 4)
    }

    private var captureBar: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(MFColor.softTile)
                .frame(width: 372, height: 34)
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(Color.white.opacity(0.72), lineWidth: 0.8)
                        .blur(radius: 0.4)
                        .offset(y: -0.6)
                }
                .overlay(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                        .blur(radius: 2)
                        .offset(y: 1)
                }

            EditableTextField(
                value: "",
                placeholder: isCaptureFeedbackVisible ? "" : "记录此刻灵感...",
                fontName: "KTXP_ComRound-Medium",
                fontSize: 12,
                textColor: NSColor(calibratedRed: 0.26, green: 0.26, blue: 0.245, alpha: 1),
                placeholderColor: NSColor(calibratedRed: 0.43, green: 0.42, blue: 0.39, alpha: 0.86),
                commitsOnBlur: false,
                onChange: {
                    captureDraft = $0
                    if !$0.isEmpty {
                        isCaptureFeedbackVisible = false
                    }
                },
                onCommit: { _ in saveCaptureDraft() }
            )
            .frame(width: 250, height: 18)
            .offset(x: 18, y: 8)
            .opacity(isCaptureFeedbackVisible ? 0 : 1)

            if let captureFeedback {
                Text(captureFeedback)
                    .font(.mfSectionTitle(12))
                    .foregroundStyle(Color(red: 0.294, green: 0.294, blue: 0.278).opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .frame(width: 250, height: 18, alignment: .leading)
                    .offset(x: 18, y: 8)
                    .opacity(isCaptureFeedbackVisible ? 1 : 0)
                    .transition(.opacity.combined(with: .offset(y: -2)))
            }

            Button("SAVE") {
                saveCaptureDraft()
            }
            .font(.mfEnglish(8, weight: .semibold))
            .tracking(0.15)
            .foregroundStyle(MFColor.canvas)
            .frame(width: 58, height: 22)
            .background(MFColor.black, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 7, x: 0, y: 3)
            .buttonStyle(.plain)
            .disabled(captureDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(captureDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.72 : 1)
            .offset(x: 307, y: 6)
        }
        .frame(width: 372, height: 34, alignment: .topLeading)
        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 4)
    }

    private var fortunePanel: some View {
        Button {
            withAnimation(MFMotion.state) {
                store.fortuneRevealed = false
            }
        } label: {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(MFColor.softTile)
                    .frame(width: 250, height: 236)

                FortuneCookieAsset(name: "fortune-cookie-cracked")
                    .opacity(0.6)
                    .frame(width: 142, height: 95)
                    .offset(x: 54, y: 28)

                Text("YOOOOU ARE LUCKY!!!")
                    .font(.mfEnglish(17, weight: .bold))
                    .tracking(0.1)
                    .foregroundStyle(Color(red: 0.067, green: 0.067, blue: 0.067).opacity(0.88))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .frame(width: 174, height: 27, alignment: .center)
                    .offset(x: 38, y: 122)

                Text(store.fortune.englishTwoLine)
                    .font(.mfEnglish(14.2, weight: .medium))
                    .foregroundStyle(Color(red: 0.102, green: 0.102, blue: 0.102).opacity(0.88))
                    .multilineTextAlignment(.center)
                    .lineSpacing(1)
                    .lineLimit(2)
                    .minimumScaleFactor(0.74)
                    .frame(width: 204, height: 38, alignment: .top)
                    .offset(x: 23, y: 167)
            }
            .frame(width: 250, height: 236, alignment: .topLeading)
            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 4)
            .shadow(color: .black.opacity(0.15), radius: 30, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func tileSurface(
        width: CGFloat,
        height: CGFloat,
        shadowOpacity: Double,
        shadowY: CGFloat,
        shadowRadius: CGFloat,
        showsInnerTopLight: Bool = false
    ) -> some View {
        RoundedRectangle(cornerRadius: MFMetric.tileRadius, style: .continuous)
            .fill(MFColor.softTile)
            .frame(width: width, height: height)
            .shadow(color: .black.opacity(shadowOpacity), radius: shadowRadius, x: 0, y: shadowY)
            .overlay(alignment: .top) {
                if showsInnerTopLight {
                    RoundedRectangle(cornerRadius: MFMetric.tileRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.72), lineWidth: 0.8)
                        .blur(radius: 0.4)
                        .offset(y: 0.4)
                }
            }
    }

    private func caption(_ text: String, tracking: CGFloat = 1.3) -> some View {
        Text(text)
            .font(.mfEnglish(6.2, weight: .semibold))
            .foregroundStyle(Color(red: 0.067, green: 0.067, blue: 0.067).opacity(0.46))
            .tracking(tracking)
    }

    private func miniCalendarX(for index: Int) -> CGFloat {
        [38, 84, 130, 176, 222, 268, 307][safe: index] ?? 38
    }

    private func paletteX(for index: Int) -> CGFloat {
        [26, 86, 146][safe: index] ?? 26
    }

    private func copyHex(_ hex: String) {
        let normalized = hex.hasPrefix("#") ? hex : "#\(hex)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(normalized, forType: .string)

        withAnimation(MFMotion.fast) {
            copiedHex = hex
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            guard copiedHex == hex else { return }
            withAnimation(MFMotion.fast) {
                copiedHex = nil
            }
        }
    }

    private func saveCaptureDraft() {
        let next = captureDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !next.isEmpty else { return }

        store.captureText = next
        if store.saveCapture() {
            captureDraft = ""
            captureFocused = false
            NSApp.keyWindow?.makeFirstResponder(nil)
            showCaptureFeedback(
                store.lastCaptureSaveError == nil
                    ? "已保存到\(store.captureDestinationTitle)"
                    : "已本地保存，外部写入失败"
            )
        } else {
            showCaptureFeedback("保存失败，请重试")
        }
    }

    private func showCaptureFeedback(_ message: String) {
        captureFeedback = message
        withAnimation(MFMotion.fast) {
            isCaptureFeedbackVisible = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
            withAnimation(.easeOut(duration: 0.34)) {
                isCaptureFeedbackVisible = false
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.75) {
            if !isCaptureFeedbackVisible {
                captureFeedback = nil
            }
        }
    }

    private var weekItems: [CalendarItem] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = 2
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let distanceFromMonday = (weekday - calendar.firstWeekday + 7) % 7
        let start = calendar.date(byAdding: .day, value: -distanceFromMonday, to: today) ?? today
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "E"

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let weekday = String(formatter.string(from: date).prefix(1)).uppercased()
            let day = String(calendar.component(.day, from: date))
            return CalendarItem(id: offset, weekday: weekday, day: day, isToday: calendar.isDate(date, inSameDayAs: today))
        }
    }

    private var currentMonthLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM"
        return formatter.string(from: Date()).uppercased()
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private struct CalendarItem: Identifiable {
    let id: Int
    let weekday: String
    let day: String
    let isToday: Bool
}

private struct FortuneCookieAsset: View {
    let name: String

    var body: some View {
        if let image = loadImage() {
            Image(nsImage: image)
                .interpolation(.high)
                .resizable()
                .scaledToFit()
                .accessibilityHidden(true)
        } else {
            Color.clear
        }
    }

    private func loadImage() -> NSImage? {
        for suffix in ["@3x", "@2x", "@1x", ""] {
            if let url = MorningResources.bundle.url(forResource: "\(name)\(suffix)", withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                return image
            }
        }

        return nil
    }
}
