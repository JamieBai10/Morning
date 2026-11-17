import Foundation

enum FeishuAuthorizationStatus: Equatable {
    case ready, needsRefresh, missingCLI, missingAuthorization, unknown

    static func decode(_ data: Data) -> Self {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let identities = object["identities"] as? [String: Any],
              let user = identities["user"] as? [String: Any] else { return .unknown }
        let scopes = (user["scope"] as? String ?? "").split(separator: " ")
        guard scopes.contains("calendar:calendar.event:read") else { return .missingAuthorization }
        switch user["status"] as? String {
        case "ready": return .ready
        // The CLI refreshes this credential when making an API request.
        case "needs_refresh": return .needsRefresh
        default: return .missingAuthorization
        }
    }
}
