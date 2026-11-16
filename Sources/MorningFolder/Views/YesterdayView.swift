import SwiftUI

struct YesterdayView: View {
    let stats: [YesterdayStat]
    let status: String?

    var body: some View {
        ZStack(alignment: .topLeading) {
            Text(MorningDateFormatter.displayLabel(for: MorningDateFormatter.yesterday()))
                .font(.mfDisplay(13))
                .foregroundStyle(MFColor.black.opacity(0.38))
                .lineLimit(1)
                .frame(width: 190, height: 20, alignment: .leading)
                .offset(x: 0, y: 0)

            if let status, status.contains("失败") || status.contains("未找到") || status.contains("无法") || status.contains("未获得") {
                Text(status)
                    .font(.mfChinese(9))
                    .foregroundStyle(MFColor.quiet)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: 190, height: 18, alignment: .trailing)
                    .offset(x: 182, y: 34)
                    .help(status)
            }

            Text("昨日回声")
                .font(.mfSectionTitle(22))
                .foregroundStyle(MFColor.black)
                .frame(width: 170, height: 33, alignment: .leading)
                .offset(x: 0, y: 28)

            ScrollView(.vertical, showsIndicators: stats.count > 4) {
                VStack(spacing: 0) {
                    ForEach(stats) { stat in
                        StatRow(stat: stat)

                        if stat.id != stats.last?.id {
                            Rectangle()
                                .fill(MFColor.separator)
                                .frame(height: 1)
                                .padding(.leading, 4)
                        }
                    }
                }
                .padding(.trailing, 12)
                .padding(.bottom, 8)
            }
            .frame(width: 372, height: 174)
            .offset(x: 0, y: 70)
        }
        .frame(width: 372, height: 240, alignment: .topLeading)
    }
}

private struct StatRow: View {
    let stat: YesterdayStat

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Circle()
                .fill(MFColor.graphite)
                .frame(width: 8, height: 8)
                .frame(width: 30, height: 42, alignment: .leading)

            sentenceText
                .foregroundStyle(MFColor.black)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
                .frame(width: 330, height: 30, alignment: .leading)
                .help("\(stat.prefix)\(stat.displayValue)\(stat.suffix)")
        }
        .frame(width: 372, height: 42, alignment: .leading)
    }

    private var sentenceText: Text {
        Text(stat.prefix)
            .font(.mfChinese(15.5, weight: .medium))
        + Text(stat.displayValue)
            .font(.mfEnglish(20, weight: .heavy))
        + Text(stat.suffix)
            .font(.mfChinese(15.5, weight: .medium))
    }
}
