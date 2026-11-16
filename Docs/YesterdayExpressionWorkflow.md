# Yesterday wording workflow

All Yesterday records are rendered using the local deterministic wording contract in `MorningNarration/YesterdayExpression.swift`. Existing cached results use a version key and are regenerated on a workflow change. Do not show unvalidated AI-generated wording; the current final display does not use SiliconFlow summaries.

- Meetings, interviews, events, study, exercise, pet walking, video, design, and writing: title followed by duration in hours. A 30-minute event displays 0.5 hours.
- All timed calendar events, including unclassified titles: title followed by duration in hours.
- All-day calendar events without a timed interval: title alone, never invent duration.
- Completed Today tasks: 你完成了 + task title, without a count.
- Captures and reminders retain their existing local wording until specifically redesigned.
- Source records from Apple Calendar and Feishu are deduplicated before presentation. Matching calendar titles with timed entries are grouped; do not infer completion from calendar records.
- There is no maximum row count. Turning a source on or off or changing a source snapshot invalidates the cached summary.
