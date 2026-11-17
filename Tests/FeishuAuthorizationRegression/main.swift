import Foundation

func check(_ status: String, scope: String = "calendar:calendar.event:read", expected: FeishuAuthorizationStatus) {
    let data = Data("{\"identities\":{\"user\":{\"status\":\"\(status)\",\"scope\":\"\(scope)\"}}}".utf8)
    precondition(FeishuAuthorizationStatus.decode(data) == expected, "Incorrect interpretation of \(status)")
}
check("ready", expected: .ready)
check("needs_refresh", expected: .needsRefresh)
check("needs_refresh", scope: "", expected: .missingAuthorization)
check("expired", expected: .missingAuthorization)
check("missing", expected: .missingAuthorization)
precondition(FeishuAuthorizationStatus.decode(Data("{}".utf8)) == .unknown)
precondition(FeishuAuthorizationStatus.decode(Data("invalid".utf8)) == .unknown)
print("Feishu authorization regression passed.")
