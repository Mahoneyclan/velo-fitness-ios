import Foundation

// Expanded vs VeloFilms — captures all metrics needed for the dashboard.
struct StravaListActivity: Decodable {
    let id: Int
    let name: String
    let sportType: String?
    let type: String
    let startDateLocal: String
    let distance: Double
    let movingTime: Int
    let elapsedTime: Int
    let totalElevationGain: Double
    let averageSpeed: Double?
    let maxSpeed: Double?
    let averageHeartrate: Double?
    let maxHeartrate: Double?
    let averageWatts: Double?
    let maxWatts: Double?
    let averageCadence: Double?
    let sufferScore: Double?
    let commute: Bool
    let trainer: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, type, distance, commute, trainer
        case sportType           = "sport_type"
        case startDateLocal      = "start_date_local"
        case movingTime          = "moving_time"
        case elapsedTime         = "elapsed_time"
        case totalElevationGain  = "total_elevation_gain"
        case averageSpeed        = "average_speed"
        case maxSpeed            = "max_speed"
        case averageHeartrate    = "average_heartrate"
        case maxHeartrate        = "max_heartrate"
        case averageWatts        = "average_watts"
        case maxWatts            = "max_watts"
        case averageCadence      = "average_cadence"
        case sufferScore         = "suffer_score"
    }

    private static let cyclingTypes: Set<String> = [
        "Ride", "VirtualRide", "GravelRide", "MountainBikeRide", "EBikeRide", "Handcycle",
    ]
    var isCycling: Bool { Self.cyclingTypes.contains(sportType ?? type) }

    func toRide() -> Ride {
        Ride(
            id: "strava_\(id)", source: "strava", name: name,
            date: Ride.parseDate(startDateLocal) ?? Date(),
            distanceKm:   distance / 1000,
            elevationM:   totalElevationGain,
            movingTimeS:  movingTime,
            elapsedTimeS: elapsedTime,
            avgSpeedKmh:  averageSpeed.map { $0 * 3.6 },
            maxSpeedKmh:  maxSpeed.map    { $0 * 3.6 },
            avgHR:        averageHeartrate,
            maxHR:        maxHeartrate,
            avgWatts:     averageWatts,
            maxWatts:     maxWatts,
            avgCadence:   averageCadence,
            sufferScore:  sufferScore,
            calories:     nil,
            activityType: sportType ?? type,
            commute:      commute,
            indoor:       trainer
        )
    }
}

struct StravaClient {
    private let auth    = StravaAuth.shared
    private let baseURL = "https://www.strava.com/api/v3"

    // Fetch one page (200 per page max) — used by RideStore for full pagination.
    func activities(page: Int) async throws -> [StravaListActivity] {
        let token = try await auth.ensureValidToken()
        let url = URL(string: "\(baseURL)/athlete/activities?page=\(page)&per_page=200")!
        let data = try await get(url: url, token: token)
        return try JSONDecoder().decode([StravaListActivity].self, from: data)
    }

    private func get(url: URL, token: String) async throws -> Data {
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req,
                                   delegate: AuthDelegate(token: token))
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw StravaError.httpError(status) }
        return data
    }
}

private final class AuthDelegate: NSObject, URLSessionTaskDelegate {
    let token: String
    init(token: String) { self.token = token }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection _: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        var r = request
        r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        completionHandler(r)
    }
}
