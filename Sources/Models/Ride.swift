import Foundation

struct Ride: Identifiable, Hashable {
    let id: String
    let source: String        // "strava" | "garmin"
    let name: String
    let date: Date
    let distanceKm: Double
    let elevationM: Double
    let movingTimeS: Int
    let elapsedTimeS: Int
    let avgSpeedKmh: Double?
    let maxSpeedKmh: Double?
    let avgHR: Double?
    let maxHR: Double?
    let avgWatts: Double?
    let maxWatts: Double?
    let avgCadence: Double?
    let sufferScore: Double?
    let calories: Double?
    let activityType: String
    let commute: Bool
    let indoor: Bool

    var movingTimeH: Double { Double(movingTimeS) / 3600 }
    var year: Int { Calendar.current.component(.year, from: date) }

    // Data quality filters matching Python dashboard
    var cleanAvgSpeedKmh: Double? {
        guard let v = avgSpeedKmh, v > 0, v <= 60 else { return nil }; return v
    }
    var cleanAvgWatts: Double? {
        guard let v = avgWatts, v > 0, v <= 600 else { return nil }; return v
    }
    var cleanMaxWatts: Double? {
        guard let v = maxWatts, v > 0, v <= 2500 else { return nil }; return v
    }
    var cleanAvgHR: Double? {
        guard let v = avgHR, v >= 70, v <= 220 else { return nil }; return v
    }
    var cleanAvgCadence: Double? {
        guard let v = avgCadence, v >= 20 else { return nil }; return v
    }

    // MARK: - Date parsing (handles mixed Strava/Garmin formats)
    static func parseDate(_ str: String) -> Date? {
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
}

// MARK: - Codable for rides.json compatibility (snake_case keys)

extension Ride: Codable {
    enum CodingKeys: String, CodingKey {
        case id, source, name, date
        case distanceKm    = "distance_km"
        case elevationM    = "elevation_m"
        case movingTimeS   = "moving_time_s"
        case elapsedTimeS  = "elapsed_time_s"
        case avgSpeedKmh   = "avg_speed_kmh"
        case maxSpeedKmh   = "max_speed_kmh"
        case avgHR         = "avg_hr"
        case maxHR         = "max_hr"
        case avgWatts      = "avg_watts"
        case maxWatts      = "max_watts"
        case avgCadence    = "avg_cadence"
        case sufferScore   = "suffer_score"
        case calories
        case activityType  = "activity_type"
        case commute, indoor
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id           = try c.decode(String.self, forKey: .id)
        source       = try c.decode(String.self, forKey: .source)
        name         = try c.decode(String.self, forKey: .name)
        distanceKm   = try c.decodeIfPresent(Double.self, forKey: .distanceKm)  ?? 0
        elevationM   = try c.decodeIfPresent(Double.self, forKey: .elevationM)  ?? 0
        movingTimeS  = try c.decodeIfPresent(Int.self,    forKey: .movingTimeS) ?? 0
        elapsedTimeS = try c.decodeIfPresent(Int.self,    forKey: .elapsedTimeS) ?? 0
        avgSpeedKmh  = try c.decodeIfPresent(Double.self, forKey: .avgSpeedKmh)
        maxSpeedKmh  = try c.decodeIfPresent(Double.self, forKey: .maxSpeedKmh)
        avgHR        = try c.decodeIfPresent(Double.self, forKey: .avgHR)
        maxHR        = try c.decodeIfPresent(Double.self, forKey: .maxHR)
        avgWatts     = try c.decodeIfPresent(Double.self, forKey: .avgWatts)
        maxWatts     = try c.decodeIfPresent(Double.self, forKey: .maxWatts)
        avgCadence   = try c.decodeIfPresent(Double.self, forKey: .avgCadence)
        sufferScore  = try c.decodeIfPresent(Double.self, forKey: .sufferScore)
        calories     = try c.decodeIfPresent(Double.self, forKey: .calories)
        activityType = try c.decodeIfPresent(String.self, forKey: .activityType) ?? "Ride"
        commute      = try c.decodeIfPresent(Bool.self,   forKey: .commute)      ?? false
        indoor       = try c.decodeIfPresent(Bool.self,   forKey: .indoor)       ?? false
        let dateStr  = try c.decode(String.self, forKey: .date)
        date         = Self.parseDate(dateStr) ?? Date()
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        try c.encode(id,           forKey: .id)
        try c.encode(source,       forKey: .source)
        try c.encode(name,         forKey: .name)
        try c.encode(iso.string(from: date), forKey: .date)
        try c.encode(distanceKm,   forKey: .distanceKm)
        try c.encode(elevationM,   forKey: .elevationM)
        try c.encode(movingTimeS,  forKey: .movingTimeS)
        try c.encode(elapsedTimeS, forKey: .elapsedTimeS)
        try c.encodeIfPresent(avgSpeedKmh,  forKey: .avgSpeedKmh)
        try c.encodeIfPresent(maxSpeedKmh,  forKey: .maxSpeedKmh)
        try c.encodeIfPresent(avgHR,        forKey: .avgHR)
        try c.encodeIfPresent(maxHR,        forKey: .maxHR)
        try c.encodeIfPresent(avgWatts,     forKey: .avgWatts)
        try c.encodeIfPresent(maxWatts,     forKey: .maxWatts)
        try c.encodeIfPresent(avgCadence,   forKey: .avgCadence)
        try c.encodeIfPresent(sufferScore,  forKey: .sufferScore)
        try c.encodeIfPresent(calories,     forKey: .calories)
        try c.encode(activityType, forKey: .activityType)
        try c.encode(commute,      forKey: .commute)
        try c.encode(indoor,       forKey: .indoor)
    }
}
