import Foundation

struct YesterdayAISummaryClient {
    static let live = YesterdayAISummaryClient()

    var environment: LocalEnvironment = .live
    var urlSession: URLSession = .shared

    func isConfigured() -> Bool {
        environment.value(for: "SILICONFLOW_API_KEY") != nil
    }

    func generateSummary(
        from snapshot: YesterdaySourceSnapshot,
        localSummary: YesterdayGeneratedSummary
    ) async throws -> [YesterdayStat]? {
        guard let apiKey = environment.value(for: "SILICONFLOW_API_KEY") else {
            return nil
        }

        let baseURL = environment.value(for: "SILICONFLOW_BASE_URL") ?? "https://api.siliconflow.cn/v1"
        let model = environment.value(for: "SILICONFLOW_MODEL") ?? "deepseek-ai/DeepSeek-V3.2"
        let requestURL = try chatCompletionsURL(baseURL: baseURL)

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            ChatCompletionRequest(
                model: model,
                messages: [
                    ChatMessage(role: "system", content: systemPrompt),
                    ChatMessage(role: "user", content: userPrompt(snapshot: snapshot, localSummary: localSummary))
                ],
                temperature: 0.2,
                maxTokens: 620,
                responseFormat: ResponseFormat(type: "json_object")
            )
        )

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw YesterdayAIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw YesterdayAIError.httpStatus(httpResponse.statusCode)
        }

        let completion = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = completion.choices.first?.message.content else {
            throw YesterdayAIError.missingContent
        }

        let parsed = try JSONDecoder().decode(AIStatsResponse.self, from: Data(content.utf8))
        let stats = parsed.items.compactMap { item -> YesterdayStat? in
            let prefix = removeEmoji(item.prefix).trimmingCharacters(in: .whitespacesAndNewlines)
            let suffix = removeEmoji(item.suffix).trimmingCharacters(in: .whitespacesAndNewlines)
            let valueText = item.valueText?.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !prefix.isEmpty, !suffix.isEmpty else { return nil }
            return YesterdayStat(prefix: prefix, value: item.value, valueText: valueText?.isEmpty == false ? valueText : nil, suffix: suffix)
        }

        return stats.isEmpty ? nil : Array(stats.prefix(6))
    }

    private var systemPrompt: String {
        """
        你是 Morning Folder 的昨日回声总结器。你只输出 JSON，不输出 Markdown。
        目标：把昨天的待办、灵感、日历和提醒事项数据转成 4 到 6 条有个人感的中文复盘句。
        每条必须是可拆分的自然句：prefix + value + suffix。数字只是证据，不是标题。
        优先维度：
        1. 真实产出：用户昨天完成的 Today 卡片任务，必须尽量引用具体任务标题里的项目/动作关键词。
        2. 自我记录：昨天写下的灵感、项目记录、待确认问题，必须尽量引用记录里的主题词。
        3. 日历活动：先判断日程是工作、生活、学习、会议还是活动，再用该类别的自然动词概括，不能用纯 emoji 或无语义标题。
        4. 执行闭环：提醒事项完成数、待办完成数、可计算的完成率。
        文案规则：
        - 语气必须像个人晨报，使用“你……”开头。
        - 不要写成表格指标，例如“完成重点任务 1 件”“记录灵感 1 条”是错误的。
        - 日常中文优先：不要写“你完成了出门办公1件”，应该写“你出门办公1次”或“你外出办公3小时”。
        - 全天日程（isAllDay=true）只证明日历有这个安排，不证明实际完成或参加；不能使用“参加了”“完成了”等确定发生的说法，也不能推算时长。用“你安排了1场会议”“你计划了1项视频修改”等自然句，每条的 1 代表一个日程。
        - 对于有明确时长的日历活动，先分类再选动词。用以下严格映射：
          * 大会、峰会、论坛、展会、发布会、讲座、演出、比赛、会议、面试：用“你参加了 + 活动名 + 时长”。
          * 早餐、午饭、晚饭、吃饭、用餐、聚餐、饭局：只有标题本身含这些用餐词时，才可用“你（和 + 标题中已有的人名）用餐了 + 时长”。仅当标题以“和／与／跟／同 + 人名”开头时才可保留对象；绝不能把“遛狗、跑步、学习、剪辑”等活动当成人名或用餐对象。例如标题“和小林，小陈晚饭”必须写“你和小林、小陈用餐了3小时”，标题“遛狗”必须写“你遛狗1小时”。
          * 学习、复习、读书、课程、练习：用“你学习了 + 学科/主题 + 时长”。
          * 视频、剪辑、拍摄、设计、写作、制作等创作工作：用“你进行了 + 工作动作 + 时长”。
          * 整理、报销、回复、准备等事务：用“你处理了 + 事项 + 时长/次数”。
          * 遛狗、遛猫、喂宠物等照料活动：直接用“你遛狗了 + 时长”或“你照料宠物 + 时长”。
          * 只有明确的项目深度工作才可以用“投入”“专注于”。
        - 严禁把用餐、聚会、运动、会议或大会写成“你在……上投入了……小时”；也不要写“你在和某人晚饭上投入了……小时”。
        - 同一主题只能出现一次。任务、日历、提醒事项里指向同一件事时，只保留信息量最高的一条。
        - 如果同一主题既有“完成 1 次”又有“投入 3 小时”，保留时长句，删除次数句。
        - 如果日历里有多个明确工作块，不要只输出 3 条；应尽量覆盖主要工作块，让用户看到自己确实做了很多事。
        - 要用总结性语言重新表达用户做了什么，例如：
          {"prefix":"你下午去海淀办公了","value":4,"suffix":"小时"}
          {"prefix":"你记录了","value":1,"suffix":"条关于个人账号内容的灵感"}
          {"prefix":"你向某公司催款","value":1,"suffix":"次"}
          {"prefix":"你进行了视频制作","value":6,"suffix":"小时"}
        - 如果时长不是整数小时，允许输出 valueText，例如 {"prefix":"你遛狗","value":0,"valueText":"0.5","suffix":"小时"}。
        - 如果引用任务/灵感原文，不要照搬整句；只提炼项目名、地点、对象名、主题词。
        总结范式：
        1. 地点/外出类：你 + 地点/外出行为 + 数字 + 小时/次。
        2. 创作/项目类：你进行了 + 项目动作 + 数字 + 小时；或你完成了 + 具体产出 + 数字 + 次。
        3. 灵感类：你记录了 + 数字 + 条关于 + 主题 + 的灵感。
        4. 行政/生活类：你向/为/把 + 对象 + 动作 + 数字 + 次。
        5. 禁止同一主题重复出现。
        禁止维度：
        - 不要输出“任务切换”“任务切换频次”“打开/切换 tab”“修改 UI 状态”这类界面操作或过程噪音。
        - 不要输出“上午安排了 3 个日程”“昨天参加了 4 个日历事件”这类低价值日程计数，除非没有任何更有价值的指标。
        - 不要输出“完成重点任务”“记录灵感”这种泛泛标签，除非没有任何具体标题或主题词可用。
        - 不要输出 emoji，不要泛泛总结，不要鸡汤，不要评价。
        数据规则：
        1. value 必须是整数。
        2. 不要编造数字，只能使用用户提供的数据。
        3. prefix + value + suffix 合起来要适合一行卡片 UI，尽量 18 个中文以内。
        4. 不要输出 URL、备注，或日历备注中的参会人；但若用餐/聚会对象直接写在日历标题中，可保留该对象以保证语义自然。
        5. 如果多个事件标题相同，应视作同一项目的多段投入。
        6. 输出格式必须是 {"items":[{"prefix":"你下午去海淀办公了","value":4,"suffix":"小时"}]}。
        """
    }

    private func userPrompt(
        snapshot: YesterdaySourceSnapshot,
        localSummary: YesterdayGeneratedSummary
    ) -> String {
        let eventPayload = snapshot.calendarEvents.map { event in
            EventPayload(
                title: event.title,
                startHour: event.durationMinutes == 0 ? nil : Calendar.current.component(.hour, from: event.startDate),
                durationMinutes: event.durationMinutes == 0 ? nil : event.durationMinutes,
                isAllDay: event.durationMinutes == 0 && event.endDate > event.startDate
            )
        }

        let reminderPayload = snapshot.completedReminders.map { reminder in
            ReminderPayload(title: reminder.title)
        }
        let taskPayload = snapshot.completedTasks.map { task in
            TaskPayload(title: task.title)
        }
        let capturePayload = snapshot.captures.map { capture in
            CapturePayload(text: capture.text)
        }

        let payload = PromptPayload(
            dateKey: snapshot.dateKey,
            allowedMetrics: localSummary.stats.map {
                MetricPayload(prefix: $0.prefix, value: $0.value, suffix: $0.suffix)
            },
            metricPolicy: MetricPolicyPayload(
                preferredDimensions: [
                    "真实产出：用自然句概括完成了什么",
                    "自我记录：总结记录了什么主题的灵感",
                    "项目投入：总结在哪个项目、地点或主题上投入了多久",
                    "执行闭环：总结处理了什么提醒事项或待办"
                ],
                bannedPatterns: [
                    "任务切换频次",
                    "打开或切换 tab",
                    "修改 UI 状态",
                    "上午/下午/晚上安排了几个日程",
                    "昨天参加了几个日历事件",
                    "无洞察的基础计数",
                    "你完成了出门办公1件",
                    "同一主题重复统计"
                ]
            ),
            completedTasks: taskPayload,
            captures: capturePayload,
            calendarEvents: eventPayload,
            completedReminders: reminderPayload
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = (try? encoder.encode(payload)) ?? Data()
        let json = String(data: data, encoding: .utf8) ?? "{}"

        return """
        请基于以下 JSON 生成 Yesterday 卡片统计。
        优先使用 allowedMetrics 中已有的真实数字。
        输出 4 到 6 条；如果日历中有多个明确工作块，优先覆盖这些工作块。必须像“你昨天做了什么”的个人晨报句，而不是统计报表。
        \(json)
        """
    }

    private func removeEmoji(_ text: String) -> String {
        let scalars = text.unicodeScalars.filter { scalar in
            !scalar.properties.isEmojiPresentation
                && !(scalar.properties.isEmoji && scalar.value > 0x238C)
        }
        return String(String.UnicodeScalarView(scalars))
    }

    private func compactPrefix(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let open = trimmed.firstIndex(of: "「"),
              let close = trimmed[trimmed.index(after: open)...].firstIndex(of: "」")
        else {
            return trimmed.count > 14 ? String(trimmed.prefix(14)) : trimmed
        }

        let lead = String(trimmed[..<trimmed.index(after: open)])
        let rawTopic = String(trimmed[trimmed.index(after: open)..<close])
        let topic = compactTopic(rawTopic)
        return "\(lead)\(topic)」"
    }

    private func compactTopic(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let removableFragments = [
            "研究一下", "了解一下", "看一下", "整理一下",
            "研究", "了解", "一下", "怎么", "如何", "为什么"
        ]

        for fragment in removableFragments {
            result = result.replacingOccurrences(of: fragment, with: "")
        }

        let compacted = result.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !compacted.isEmpty else { return "内容" }
        return compacted.count > 8 ? String(compacted.prefix(8)) : compacted
    }

    private func chatCompletionsURL(baseURL: String) throws -> URL {
        guard var components = URLComponents(string: baseURL) else {
            throw YesterdayAIError.invalidBaseURL
        }

        var path = components.path
        if path.hasSuffix("/") {
            path.removeLast()
        }
        if !path.hasSuffix("/chat/completions") {
            path += "/chat/completions"
        }
        components.path = path

        guard let url = components.url else {
            throw YesterdayAIError.invalidBaseURL
        }
        return url
    }
}

private struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
    let maxTokens: Int
    let responseFormat: ResponseFormat

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
        case responseFormat = "response_format"
    }
}

private struct ChatMessage: Encodable, Decodable {
    let role: String
    let content: String
}

private struct ResponseFormat: Encodable {
    let type: String
}

private struct ChatCompletionResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: ChatMessage
    }
}

private struct AIStatsResponse: Decodable {
    let items: [AIStatItem]
}

private struct AIStatItem: Decodable {
    let prefix: String
    let value: Int
    let valueText: String?
    let suffix: String

    enum CodingKeys: String, CodingKey {
        case prefix
        case value
        case valueText
        case valueTextSnake = "value_text"
        case suffix
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.prefix = try container.decode(String.self, forKey: .prefix)
        self.suffix = try container.decode(String.self, forKey: .suffix)

        if let intValue = try? container.decode(Int.self, forKey: .value) {
            self.value = intValue
            self.valueText = try container.decodeIfPresent(String.self, forKey: .valueText)
                ?? container.decodeIfPresent(String.self, forKey: .valueTextSnake)
        } else if let doubleValue = try? container.decode(Double.self, forKey: .value) {
            self.value = Int(doubleValue.rounded(.down))
            self.valueText = doubleValue.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(doubleValue))"
                : String(format: "%.1f", doubleValue)
        } else {
            let stringValue = try container.decode(String.self, forKey: .value)
            self.value = Int(Double(stringValue) ?? 0)
            self.valueText = stringValue
        }
    }
}

private struct PromptPayload: Encodable {
    let dateKey: String
    let allowedMetrics: [MetricPayload]
    let metricPolicy: MetricPolicyPayload
    let completedTasks: [TaskPayload]
    let captures: [CapturePayload]
    let calendarEvents: [EventPayload]
    let completedReminders: [ReminderPayload]
}

private struct MetricPolicyPayload: Encodable {
    let preferredDimensions: [String]
    let bannedPatterns: [String]
}

private struct MetricPayload: Encodable {
    let prefix: String
    let value: Int
    let suffix: String
}

private struct EventPayload: Encodable {
    let title: String
    let startHour: Int?
    let durationMinutes: Int?
    let isAllDay: Bool
}

private struct TaskPayload: Encodable {
    let title: String
}

private struct CapturePayload: Encodable {
    let text: String
}

private struct ReminderPayload: Encodable {
    let title: String
}

enum YesterdayAIError: LocalizedError {
    case invalidBaseURL
    case invalidResponse
    case httpStatus(Int)
    case missingContent

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            "SiliconFlow API 地址无效"
        case .invalidResponse:
            "SiliconFlow 响应无效"
        case let .httpStatus(statusCode):
            "SiliconFlow 请求失败：\(statusCode)"
        case .missingContent:
            "SiliconFlow 没有返回总结内容"
        }
    }
}
