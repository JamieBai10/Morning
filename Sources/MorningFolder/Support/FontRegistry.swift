import CoreText
import Foundation

enum FontRegistry {
    static func registerBundledFonts() {
        for fontName in [
            "Baloo2-VariableFont_wght",
            "Baloo2-ExtraBold",
            "AlibabaPuHuiTi-3-65-Medium",
            "jyhphy-2"
        ] {
            guard let url = MorningResources.bundle.url(forResource: fontName, withExtension: fontExtension(for: fontName)) else {
                continue
            }

            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    private static func fontExtension(for fontName: String) -> String {
        switch fontName {
        case "Baloo2-VariableFont_wght", "Baloo2-ExtraBold":
            "ttf"
        case "jyhphy-2":
            "ttf"
        default:
            "otf"
        }
    }
}
