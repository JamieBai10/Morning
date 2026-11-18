import Foundation

@main
struct WidgetScaleRegression {
    @MainActor
    static func main() {
        let suite = "Morning.WidgetScaleRegression.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = MorningPreferences(defaults: defaults)
        precondition(preferences.widgetScale == 1, "Existing users must start at 100%")
        preferences.widgetScale = 0.75
        precondition(MorningPreferences(defaults: defaults).widgetScale == 0.75, "Scale must survive restart")
        preferences.widgetScale = 0.1
        precondition(preferences.widgetScale == 0.5, "Scale must not shrink below 50%")
        preferences.widgetScale = 2
        precondition(preferences.widgetScale == 1, "Scale must not exceed 100%")
        preferences.widgetScale = .nan
        precondition(preferences.widgetScale == 1, "Invalid scale must reset to default")
        for (saved, expected) in [(0.0, 0.5), (0.8, 0.8), (2.0, 1.0), (Double.infinity, 1.0)] {
            defaults.set(saved, forKey: "morning.widgetScale")
            precondition(MorningPreferences(defaults: defaults).widgetScale == expected, "Saved scale must be validated")
        }
        defaults.set("broken", forKey: "morning.widgetScale")
        precondition(MorningPreferences(defaults: defaults).widgetScale == 1, "Corrupt stored values must not make the app disappear")
        for expanded in [false, true] {
            let original = MFMetric.widgetSize(isExpanded: expanded)
            for scale in [0.5, 0.75, 1.0] {
                let size = MFMetric.widgetSize(isExpanded: expanded, scale: scale)
                precondition(size.width == original.width * scale)
                precondition(size.height == original.height * scale)
            }
        }
        print("Widget scale regression passed: defaults, persistence, validation and both widget sizes.")
    }
}
