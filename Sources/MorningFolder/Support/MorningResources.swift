import Foundation

enum MorningResources {
    static let bundle: Bundle = {
        let bundleName = "Morning_MorningFolder.bundle"

        if let resourceURL = Bundle.main.resourceURL,
           let packagedBundle = Bundle(url: resourceURL.appendingPathComponent(bundleName)) {
            return packagedBundle
        }

        return .module
    }()
}
