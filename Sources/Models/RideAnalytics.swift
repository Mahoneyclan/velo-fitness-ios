import Foundation

// MARK: - Chart data types

struct WeekPoint: Identifiable {
    let id = UUID()
    let week: Date
    let distanceKm: Double
    let timeH: Double
}

struct MonthPoint: Identifiable {
    let id = UUID()
    let month: Date
    let distanceKm: Double
    let elevationM: Double
}

struct TrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let series: String   // "raw" | "28d avg"
}

struct LoadPoint: Identifiable {
    let id = UUID()
    let week: Date
    let weeklyLoad: Double
    let ctl: Double      // Chronic Training Load (fitness, 42-week EMA)
    let atl: Double      // Acute Training Load (fatigue, 7-week EMA)
    let tsb: Double      // Training Stress Balance (form = CTL - ATL)
}

struct HeatCell: Identifiable {
    let id = UUID()
    let year: String
    let week: Int
    let distanceKm: Double
}

struct YearLine: Identifiable {
    let id = UUID()
    let year: String
    let dayOfYear: Int
    let cumKm: Double
}

struct FitnessPeriod: Identifiable {
    let id = UUID()
    let label: String
    let rides: Int
    let totalKm: Double
    let avgDistKm: Double
    let avgSpeed: Double?
    let avgHR: Double?
    let efficiency: Double?
    let trend: Trend
    let climbingM: Double

    enum Trend: String { case up = "▲", down = "▼", flat = "—", none = "" }
}

struct PersonalBest: Identifiable {
    let id = UUID()
    let record: String
    let value: String
    let rideName: String
    let date: String
}

// MARK: - Computation

enum RideAnalytics {

    // MARK: Aggregation

    static func weeklyVolume(_ rides: [Ride]) -> [WeekPoint] {
        grouped(rides, by: \.weekStart)
            .map { WeekPoint(week: $0, distanceKm: $1.map(\.distanceKm).sum, timeH: $1.map(\.movingTimeH).sum) }
            .sorted { $0.week < $1.week }
    }

    static func monthlyVolume(_ rides: [Ride]) -> [MonthPoint] {
        grouped(rides, by: \.monthStart)
            .map { MonthPoint(month: $0, distanceKm: $1.map(\.distanceKm).sum, elevationM: $1.map(\.elevationM).sum) }
            .sorted { $0.month < $1.month }
    }

    // MARK: Trend charts (raw + 28-day rolling avg)

    static func speedTrend(_ rides: [Ride])   -> [TrendPoint] { trend(rides, value: \.cleanAvgSpeedKmh) }
    static func hrTrend(_ rides: [Ride])       -> [TrendPoint] { trend(rides, value: \.cleanAvgHR) }
    static func powerTrend(_ rides: [Ride])    -> [TrendPoint] { trend(rides, value: \.cleanAvgWatts) }
    static func cadenceTrend(_ rides: [Ride])  -> [TrendPoint] { trend(rides, value: \.cleanAvgCadence) }

    private static func trend(_ rides: [Ride], value kp: KeyPath<Ride, Double?>) -> [TrendPoint] {
        let raw = rides.compactMap { r -> TrendPoint? in
            guard let v = r[keyPath: kp] else { return nil }
            return TrendPoint(date: r.date, value: v, series: "raw")
        }.sorted { $0.date < $1.date }

        let rolling = rollingAvg(raw.map { ($0.date, $0.value) }, window: 28 * 86400)
            .map { TrendPoint(date: $0.0, value: $0.1, series: "28d avg") }

        return raw + rolling
    }

    // MARK: Training load (CTL / ATL / TSB)

    static func trainingLoad(_ rides: [Ride]) -> [LoadPoint] {
        let weekly = weeklyVolume(rides)
        let byWeek = Dictionary(grouping: rides, by: \.weekStart)

        var ctl = 0.0, atl = 0.0
        return weekly.map { wp in
            let load = (byWeek[wp.week] ?? []).reduce(0.0) { acc, r in
                if let ss = r.sufferScore { return acc + ss }
                return acc + r.movingTimeH * (r.cleanAvgHR ?? 130) / 10
            }
            ctl += (load - ctl) / 42
            atl += (load - atl) / 7
            return LoadPoint(week: wp.week, weeklyLoad: load, ctl: ctl, atl: atl, tsb: ctl - atl)
        }
    }

    // MARK: Year comparison

    static func yearComparison(_ rides: [Ride]) -> [YearLine] {
        let cal = Calendar.current
        return Dictionary(grouping: rides, by: \.year)
            .flatMap { year, yearRides -> [YearLine] in
                var cum = 0.0
                return yearRides.sorted { $0.date < $1.date }.map { r in
                    cum += r.distanceKm
                    let day = cal.ordinality(of: .day, in: .year, for: r.date) ?? 0
                    return YearLine(year: "\(year)", dayOfYear: day, cumKm: cum)
                }
            }
    }

    // MARK: Heatmap

    static func heatmap(_ rides: [Ride]) -> [HeatCell] {
        let cal = Calendar.current
        return Dictionary(grouping: rides) { r -> String in
            let y = cal.component(.year, from: r.date)
            let w = cal.component(.weekOfYear, from: r.date)
            return "\(y)-\(w)"
        }.compactMap { key, cellRides -> HeatCell? in
            let parts = key.split(separator: "-")
            guard parts.count == 2,
                  let year = Int(parts[0]),
                  let week = Int(parts[1]) else { return nil }
            return HeatCell(
                year: "\(year)",
                week: week,
                distanceKm: cellRides.map(\.distanceKm).sum
            )
        }
    }

    // MARK: Fitness trend (90-day rolling windows)

    static func fitnessTrend(_ rides: [Ride]) -> [FitnessPeriod] {
        guard !rides.isEmpty else { return [] }
        let now      = rides.map(\.date).max()!
        let earliest = rides.map(\.date).min()!
        let maxQ     = Int(now.timeIntervalSince(earliest) / (90 * 86400)) + 2

        var quarters: [(Date, Date, [Ride])] = []
        for i in 0..<maxQ {
            let end   = now.addingTimeInterval(-Double(90 * i) * 86400)
            let start = end.addingTimeInterval(-90 * 86400)
            let chunk = rides.filter { $0.date >= start && $0.date < end }
            if !chunk.isEmpty { quarters.append((start, end, chunk)) }
        }
        quarters.reverse()

        var prevEff: Double? = nil
        let fmt = DateFormatter(); fmt.dateFormat = "MMM yyyy"

        return quarters.map { start, end, chunk in
            let hrSpeed = chunk.filter { $0.cleanAvgHR != nil && $0.cleanAvgSpeedKmh != nil }
            let efficiency = hrSpeed.isEmpty ? nil :
                hrSpeed.map { $0.cleanAvgSpeedKmh! / $0.cleanAvgHR! }.avg

            let trend: FitnessPeriod.Trend
            if let e = efficiency, let pe = prevEff {
                trend = e - pe > 0.003 ? .up : e - pe < -0.003 ? .down : .flat
            } else { trend = .none }
            prevEff = efficiency

            return FitnessPeriod(
                label:      "\(fmt.string(from: start)) – \(fmt.string(from: end))",
                rides:      chunk.count,
                totalKm:    chunk.map(\.distanceKm).sum,
                avgDistKm:  chunk.map(\.distanceKm).avg ?? 0,
                avgSpeed:   chunk.compactMap(\.cleanAvgSpeedKmh).avg,
                avgHR:      hrSpeed.compactMap(\.cleanAvgHR).avg,
                efficiency: efficiency,
                trend:      trend,
                climbingM:  chunk.map(\.elevationM).sum
            )
        }
    }

    // MARK: Personal bests

    static func personalBests(_ rides: [Ride]) -> [PersonalBest] {
        func fmt(_ d: Date) -> String {
            let f = DateFormatter(); f.dateStyle = .medium; return f.string(from: d)
        }
        var out: [PersonalBest] = []

        if let r = rides.max(by: { $0.distanceKm < $1.distanceKm }) {
            out.append(.init(record: "Longest ride",      value: String(format: "%.1f km", r.distanceKm), rideName: r.name, date: fmt(r.date)))
        }
        if let r = rides.max(by: { $0.elevationM < $1.elevationM }) {
            out.append(.init(record: "Most elevation",    value: String(format: "%.0f m",  r.elevationM),  rideName: r.name, date: fmt(r.date)))
        }
        if let (r, v) = rides.compactMap({ r in r.cleanAvgSpeedKmh.map { (r, $0) } }).max(by: { $0.1 < $1.1 }) {
            out.append(.init(record: "Fastest avg speed", value: String(format: "%.1f km/h", v),           rideName: r.name, date: fmt(r.date)))
        }
        if let (r, v) = rides.compactMap({ r in r.cleanAvgWatts.map { (r, $0) } }).max(by: { $0.1 < $1.1 }) {
            out.append(.init(record: "Highest avg power", value: String(format: "%.0f W",    v),           rideName: r.name, date: fmt(r.date)))
        }
        if let r = rides.max(by: { $0.movingTimeH < $1.movingTimeH }) {
            out.append(.init(record: "Longest session",   value: fmtTime(r.movingTimeH),                   rideName: r.name, date: fmt(r.date)))
        }
        if let (r, v) = rides.compactMap({ r in r.cleanAvgHR.map { (r, $0) } }).min(by: { $0.1 < $1.1 }) {
            out.append(.init(record: "Lowest avg HR",     value: String(format: "%.0f bpm",  v),           rideName: r.name, date: fmt(r.date)))
        }
        return out
    }

    // MARK: - Helpers

    private static func grouped<K: Hashable>(_ rides: [Ride], by kp: KeyPath<Ride, K>) -> [(K, [Ride])] {
        Dictionary(grouping: rides) { $0[keyPath: kp] }.map { ($0.key, $0.value) }
    }

    private static func rollingAvg(_ pts: [(Date, Double)], window: TimeInterval) -> [(Date, Double)] {
        let sorted = pts.sorted { $0.0 < $1.0 }
        return sorted.enumerated().map { i, pt in
            let cutoff  = pt.0.addingTimeInterval(-window)
            let inWin   = sorted[0...i].filter { $0.0 >= cutoff }
            return (pt.0, inWin.map(\.1).avg ?? pt.1)
        }
    }
}

// MARK: - Ride date helpers

private extension Ride {
    var weekStart: Date {
        let cal = Calendar.current
        var c = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: c) ?? date
    }
    var monthStart: Date {
        let cal = Calendar.current
        var c = cal.dateComponents([.year, .month], from: date)
        return cal.date(from: c) ?? date
    }
}

// MARK: - Array helpers

private extension Array where Element == Double {
    var sum: Double { reduce(0, +) }
    var avg: Double? { isEmpty ? nil : sum / Double(count) }
}

extension Array where Element == Double {
    var safeAvg: Double? { isEmpty ? nil : reduce(0, +) / Double(count) }
}
