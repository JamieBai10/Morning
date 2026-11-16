import SwiftUI

enum MFColor {
    static let canvas = Color(red: 0.945, green: 0.941, blue: 0.910)
    static let surface = Color(red: 0.953, green: 0.949, blue: 0.929)
    static let raisedSurface = Color.white
    static let softTile = Color(red: 0.965, green: 0.961, blue: 0.945)
    static let captureSurface = Color(red: 0.937, green: 0.929, blue: 0.906)
    static let black = Color(red: 0.055, green: 0.055, blue: 0.052)
    static let graphite = Color(red: 0.294, green: 0.294, blue: 0.278)
    static let quiet = Color(red: 0.486, green: 0.482, blue: 0.471)
    static let separator = Color.black.opacity(0.07)
}

enum MFMetric {
    static let expandedWidth: CGFloat = 524
    static let expandedHeight: CGFloat = 420
    static let collapsedWidth: CGFloat = 246
    static let collapsedHeight: CGFloat = 218

    static func widgetSize(isExpanded: Bool) -> CGSize {
        isExpanded
            ? CGSize(width: expandedWidth, height: expandedHeight)
            : CGSize(width: collapsedWidth, height: collapsedHeight)
    }

    static let cardRadius: CGFloat = 28
    static let tabRadius: CGFloat = 28
    static let tileRadius: CGFloat = 16
    static let smallRadius: CGFloat = 16
}

enum MFMotion {
    static let snap = Animation.spring(response: 0.22, dampingFraction: 0.90)
    static let soft = Animation.spring(response: 0.34, dampingFraction: 0.86)
    static let lazy = Animation.spring(response: 0.48, dampingFraction: 0.88)
    static let state = Animation.easeInOut(duration: 0.17)
    static let fast = Animation.easeOut(duration: 0.14)
}

extension Font {
    static func mfEnglish(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .custom(balooName(for: weight), size: size)
    }

    static func mfChinese(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .custom("AlibabaPuHuiTi_3_65_Medium", size: size)
    }

    static func mfDisplay(_ size: CGFloat) -> Font {
        .custom("Baloo2-ExtraBold", size: size)
    }

    static func mfSectionTitle(_ size: CGFloat) -> Font {
        .custom("KTXP_ComRound-Medium", size: size)
    }

    private static func balooName(for weight: Font.Weight) -> String {
        switch weight {
        case .regular:
            "Baloo2-Regular"
        case .medium, .semibold, .bold, .heavy, .black:
            "Baloo2-ExtraBold"
        default:
            "Baloo2-Regular"
        }
    }
}

extension View {
    func mfShadow(_ opacity: Double = 0.12, y: CGFloat = 18, radius: CGFloat = 28) -> some View {
        shadow(color: .black.opacity(opacity), radius: radius, x: 0, y: y)
    }
}

extension Color {
    init?(hexString: String) {
        let normalized = hexString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        guard normalized.count == 6, let value = Int(normalized, radix: 16) else {
            return nil
        }

        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
