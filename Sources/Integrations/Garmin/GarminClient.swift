import Foundation

// Expanded vs VeloFilms — captures all dashboard metrics.
struct GarminFullActivity: Decodable, Identifiable {
    let activityId: Int
    let activityName: String
    let startTimeLocal: String
    let distance: Double?
    let duration: Double?
    let movingDuration: Double?
    let elevationGain: Double?
    let averageSpeed: Double?
    let maxSpeed: Double?
    let averageHR: Double?
    let maxHR: Double?
    let avgPower: Double?
    let maxPower: Double?
    let averageBikingCadenceInRevPerMinute: Double?
    let trainingStressScore: Double?
    let calories: Double?
    let activityType: ActivityTypeKey?

    var id: Int { activityId }

    struct ActivityTypeKey: Decodable { let typeKey: String }

    private static let cyclingKeys: Set<String> = [
        "road_biking", "mountain_biking", "gravel_cycling", "cycling",
        "indoor_cycling", "virtual_ride", "e_bike_fitness", "e_bike_mountain",
    ]
    var isCycling: Bool { Self.cyclingKeys.contains(activityType?.typeKey ?? "") }

    func toRide() -> Ride {
        let distM = distance ?? 0
        let durS  = duration ?? 0
        let movS  = movingDuration ?? durS
        return Ride(
            id: "garmin_\(activityId)", source: "garmin", name: activityName,
            date: Ride.parseDate(startTimeLocal) ?? Date(),
            distanceKm:   distM / 1000,
            elevationM:   elevationGain ?? 0,
            movingTimeS:  Int(movS),
            elapsedTimeS: Int(durS),
            avgSpeedKmh:  averageSpeed.map { $0 * 3.6 },
            maxSpeedKmh:  maxSpeed.map    { $0 * 3.6 },
            avgHR:        averageHR,
            maxHR:        maxHR,
            avgWatts:     avgPower,
            maxWatts:     maxPower,
            avgCadence:   averageBikingCadenceInRevPerMinute,
            sufferScore:  trainingStressScore,
            calories:     calories,
            activityType: activityType?.typeKey ?? "cycling",
            commute:      false,
            indoor:       false
        )
    }
}

struct GarminClient {
    private let auth = GarminAuth.shared
    private let base = "https://connectapi.garmin.com"

    func activities(start: Int, limit: Int = 100) async throws -> [GarminFullActivity] {
        let token = try await auth.ensureValidToken()
        let url = URL(string: "\(base)/activitylist-service/activities/search/activities?start=\(start)&limit=\(limit)")!
        let data = try await bearer(url: url, token: token)
        return try JSONDecoder().decode([GarminFullActivity].self, from: data)
    }

    private func bearer(url: URL, token: String) async throws -> Data {
        var req = URLRequest(url: url)
        req.setValue("GCM-iOS-5.22.1.4", forHTTPHeaderField: "User-Agent")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req, delegate: GarminAuthDelegate(token: token))
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw GarminError.downloadFailed((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return data
    }
}

private final class GarminAuthDelegate: NSObject, URLSessionTaskDelegate {
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
