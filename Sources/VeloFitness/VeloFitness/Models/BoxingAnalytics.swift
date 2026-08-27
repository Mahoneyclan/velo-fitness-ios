import Foundation

enum BoxingAnalytics {
    private static let rollingWindowDays = 28

    /// Scatter (raw) + rolling-average series for a given metric, matching
    /// RideAnalytics' shape so BoxingTrendChart can reuse the same TrendPoint type.
    private static func trend(_ sessions: [BoxingSession], _ keyPath: KeyPath<BoxingSession, Double?>) -> [TrendPoint] {
        let sorted = sessions.sorted { $0.date < $1.date }
        var points: [TrendPoint] = []

        for s in sorted {
            guard let v = s[keyPath: keyPath] else { continue }
            points.append(TrendPoint(date: s.date, value: v, series: "raw"))
        }

        let cutoffSeconds = Double(rollingWindowDays) * 86400
        for s in sorted {
            guard s[keyPath: keyPath] != nil else { continue }
            let windowStart = s.date.addingTimeInterval(-cutoffSeconds)
            let windowValues = sorted
                .filter { $0.date >= windowStart && $0.date <= s.date }
                .compactMap { $0[keyPath: keyPath] }
            guard !windowValues.isEmpty else { continue }
            let avg = windowValues.reduce(0, +) / Double(windowValues.count)
            points.append(TrendPoint(date: s.date, value: avg, series: "28d avg"))
        }

        return points
    }

    static func punchRateTrend(_ sessions: [BoxingSession]) -> [TrendPoint] {
        trend(sessions, \.punchRateAvg)
    }

    static func punchForceTrend(_ sessions: [BoxingSession]) -> [TrendPoint] {
        trend(sessions, \.punchForceMax)
    }

    static func hrTrend(_ sessions: [BoxingSession]) -> [TrendPoint] {
        trend(sessions, \.avgHR)
    }

    struct PunchMixPoint: Identifiable {
        let id = UUID()
        let date: Date
        let type: String   // "Jab" | "Hook" | "Cross"
        let count: Int
        let percent: Double  // of that session's jab+hook+cross total — sums to 100 per session
    }

    static func punchMix(_ sessions: [BoxingSession]) -> [PunchMixPoint] {
        sessions.sorted { $0.date < $1.date }.flatMap { s -> [PunchMixPoint] in
            let jab = s.totalJab ?? 0, hook = s.totalHook ?? 0, cross = s.totalCross ?? 0
            let total = jab + hook + cross
            guard total > 0 else { return [] }
            func pct(_ n: Int) -> Double { Double(n) / Double(total) * 100 }
            return [
                PunchMixPoint(date: s.date, type: "Jab",   count: jab,   percent: pct(jab)),
                PunchMixPoint(date: s.date, type: "Hook",  count: hook,  percent: pct(hook)),
                PunchMixPoint(date: s.date, type: "Cross", count: cross, percent: pct(cross)),
            ]
        }
    }
}
