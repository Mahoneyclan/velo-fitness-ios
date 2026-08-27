import Foundation

struct BoxingSession: Identifiable, Hashable, Codable {
    let id: String
    let date: Date
    let durationS: Int
    let avgHR: Double?
    let maxHR: Double?
    let calories: Double?
    let punchRateAvg: Double?
    let totalPunches: Int?
    let totalJab: Int?
    let totalHook: Int?
    let totalCross: Int?
    let punchForceMax: Double?
    let punchForceAvg1s: Double?
    let punchForceUnit: String?
    let stepRateAvg: Double?
    let energyExpenditure: Double?
    let totalSteps: Int?
    let batteryUsedPct: Double?
    let source: String

    var durationH: Double { Double(durationS) / 3600 }
    var year: Int { Calendar.current.component(.year, from: date) }

    /// Built directly from a synced Garmin activity + its parsed FIT metrics — the
    /// on-device path, no external JSON involved.
    init(activityId: Int, date: Date, metrics: FITBoxingParser.ParsedBoxingMetrics) {
        self.id = "garmin_\(activityId)"
        self.date = date
        self.durationS = Int(metrics.durationS ?? 0)
        self.avgHR = metrics.avgHR
        self.maxHR = metrics.maxHR
        self.calories = metrics.calories
        self.punchRateAvg = metrics.punchRateAvg
        self.totalPunches = metrics.totalPunches.map { Int($0) }
        self.totalJab = metrics.totalJab.map { Int($0) }
        self.totalHook = metrics.totalHook.map { Int($0) }
        self.totalCross = metrics.totalCross.map { Int($0) }
        self.punchForceMax = metrics.punchForceMax ?? metrics.punchForceMaxRecord
        self.punchForceAvg1s = metrics.punchForceAvg1s
        // Unresolvable from the FIT file itself — every force dev field's `units` string
        // is the app's static label "G,N,Kg | lbs", not the unit actually selected on the
        // watch. Set BoxingSettings.punchForceUnit once to whatever your f3b app is
        // configured to display.
        self.punchForceUnit = (self.punchForceMax != nil) ? BoxingSettings.punchForceUnit : nil
        self.stepRateAvg = metrics.stepRateAvg
        self.energyExpenditure = metrics.energyExpenditure
        self.totalSteps = metrics.totalSteps.map { Int($0) }
        self.batteryUsedPct = metrics.batteryUsedPct
        self.source = "garmin"
    }

    /// Punch force displayed with its as-recorded unit — not converted.
    /// See project plan: G-force → Newtons requires an assumed mass we don't have,
    /// so sessions show whichever unit the watch was set to record in.
    var punchForceMaxDisplay: String? {
        guard let v = punchForceMax else { return nil }
        return "\(String(format: "%.1f", v)) \(punchForceUnit ?? "")"
    }

    enum CodingKeys: String, CodingKey {
        case id, date, source
        case durationS         = "duration_s"
        case avgHR             = "avg_hr"
        case maxHR              = "max_hr"
        case calories
        case punchRateAvg       = "punch_rate_avg"
        case totalPunches       = "total_punches"
        case totalJab           = "total_jab"
        case totalHook          = "total_hook"
        case totalCross         = "total_cross"
        case punchForceMax      = "punch_force_max"
        case punchForceAvg1s    = "punch_force_avg_1s"
        case punchForceUnit     = "punch_force_unit"
        case stepRateAvg        = "step_rate_avg"
        case energyExpenditure  = "energy_expenditure"
        case totalSteps         = "total_steps"
        case batteryUsedPct     = "battery_used_pct"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id               = try c.decode(String.self, forKey: .id)
        durationS        = try c.decodeIfPresent(Int.self, forKey: .durationS) ?? 0
        avgHR            = try c.decodeIfPresent(Double.self, forKey: .avgHR)
        maxHR            = try c.decodeIfPresent(Double.self, forKey: .maxHR)
        calories         = try c.decodeIfPresent(Double.self, forKey: .calories)
        punchRateAvg     = try c.decodeIfPresent(Double.self, forKey: .punchRateAvg)
        totalPunches     = try c.decodeIfPresent(Int.self, forKey: .totalPunches)
        totalJab         = try c.decodeIfPresent(Int.self, forKey: .totalJab)
        totalHook        = try c.decodeIfPresent(Int.self, forKey: .totalHook)
        totalCross       = try c.decodeIfPresent(Int.self, forKey: .totalCross)
        punchForceMax    = try c.decodeIfPresent(Double.self, forKey: .punchForceMax)
        punchForceAvg1s  = try c.decodeIfPresent(Double.self, forKey: .punchForceAvg1s)
        punchForceUnit   = try c.decodeIfPresent(String.self, forKey: .punchForceUnit)
        stepRateAvg      = try c.decodeIfPresent(Double.self, forKey: .stepRateAvg)
        energyExpenditure = try c.decodeIfPresent(Double.self, forKey: .energyExpenditure)
        totalSteps       = try c.decodeIfPresent(Int.self, forKey: .totalSteps)
        batteryUsedPct   = try c.decodeIfPresent(Double.self, forKey: .batteryUsedPct)
        source           = try c.decodeIfPresent(String.self, forKey: .source) ?? "garmin"
        let dateStr      = try c.decode(String.self, forKey: .date)
        date             = Self.parseDate(dateStr) ?? Date()
    }

    // MARK: - Date parsing (mirrors Ride.parseDate — kept local to avoid a cross-file dependency)
    private static func parseDate(_ str: String) -> Date? {
        let iso = ISO8601DateFormatter()
        for opts: ISO8601DateFormatter.Options in [
            [.withInternetDateTime, .withFractionalSeconds],
            [.withInternetDateTime],
            [.withFullDate, .withTime, .withColonSeparatorInTime],
            [.withFullDate, .withTime, .withColonSeparatorInTime, .withTimeZone],
        ] {
            iso.formatOptions = opts
            if let d = iso.date(from: str) { return d }
        }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        for format in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd"] {
            fmt.dateFormat = format
            if let d = fmt.date(from: str) { return d }
        }
        return nil
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        try c.encode(id, forKey: .id)
        try c.encode(iso.string(from: date), forKey: .date)
        try c.encode(durationS, forKey: .durationS)
        try c.encodeIfPresent(avgHR, forKey: .avgHR)
        try c.encodeIfPresent(maxHR, forKey: .maxHR)
        try c.encodeIfPresent(calories, forKey: .calories)
        try c.encodeIfPresent(punchRateAvg, forKey: .punchRateAvg)
        try c.encodeIfPresent(totalPunches, forKey: .totalPunches)
        try c.encodeIfPresent(totalJab, forKey: .totalJab)
        try c.encodeIfPresent(totalHook, forKey: .totalHook)
        try c.encodeIfPresent(totalCross, forKey: .totalCross)
        try c.encodeIfPresent(punchForceMax, forKey: .punchForceMax)
        try c.encodeIfPresent(punchForceAvg1s, forKey: .punchForceAvg1s)
        try c.encodeIfPresent(punchForceUnit, forKey: .punchForceUnit)
        try c.encodeIfPresent(stepRateAvg, forKey: .stepRateAvg)
        try c.encodeIfPresent(energyExpenditure, forKey: .energyExpenditure)
        try c.encodeIfPresent(totalSteps, forKey: .totalSteps)
        try c.encodeIfPresent(batteryUsedPct, forKey: .batteryUsedPct)
        try c.encode(source, forKey: .source)
    }
}
