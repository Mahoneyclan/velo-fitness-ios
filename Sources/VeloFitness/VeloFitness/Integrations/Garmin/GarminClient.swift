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

    struct ActivityTypeKey: Decodable {
        let typeKey: String
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            typeKey = try c.decodeIfPresent(String.self, forKey: .typeKey) ?? ""
        }
        enum CodingKeys: String, CodingKey { case typeKey }
    }

    // Garmin's activity list occasionally sends `null` for name/start-time fields
    // (e.g. still-processing activities) — decodeIfPresent + fallback keeps one bad
    // record from failing the whole batch decode, matching Ride.swift's resilience.
    enum CodingKeys: String, CodingKey {
        case activityId, activityName, startTimeLocal, distance, duration, movingDuration
        case elevationGain, averageSpeed, maxSpeed, averageHR, maxHR, avgPower, maxPower
        case averageBikingCadenceInRevPerMinute, trainingStressScore, calories, activityType
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        activityId       = try c.decode(Int.self, forKey: .activityId)
        activityName     = try c.decodeIfPresent(String.self, forKey: .activityName) ?? "Untitled"
        startTimeLocal   = try c.decodeIfPresent(String.self, forKey: .startTimeLocal) ?? ""
        distance         = try c.decodeIfPresent(Double.self, forKey: .distance)
        duration         = try c.decodeIfPresent(Double.self, forKey: .duration)
        movingDuration   = try c.decodeIfPresent(Double.self, forKey: .movingDuration)
        elevationGain    = try c.decodeIfPresent(Double.self, forKey: .elevationGain)
        averageSpeed     = try c.decodeIfPresent(Double.self, forKey: .averageSpeed)
        maxSpeed         = try c.decodeIfPresent(Double.self, forKey: .maxSpeed)
        averageHR        = try c.decodeIfPresent(Double.self, forKey: .averageHR)
        maxHR            = try c.decodeIfPresent(Double.self, forKey: .maxHR)
        avgPower         = try c.decodeIfPresent(Double.self, forKey: .avgPower)
        maxPower         = try c.decodeIfPresent(Double.self, forKey: .maxPower)
        averageBikingCadenceInRevPerMinute = try c.decodeIfPresent(Double.self, forKey: .averageBikingCadenceInRevPerMinute)
        trainingStressScore = try c.decodeIfPresent(Double.self, forKey: .trainingStressScore)
        calories         = try c.decodeIfPresent(Double.self, forKey: .calories)
        activityType     = try c.decodeIfPresent(ActivityTypeKey.self, forKey: .activityType)
    }

    private static let cyclingKeys: Set<String> = [
        "road_biking", "mountain_biking", "gravel_cycling", "cycling",
        "indoor_cycling", "virtual_ride", "e_bike_fitness", "e_bike_mountain",
    ]
    var isCycling: Bool { Self.cyclingKeys.contains(activityType?.typeKey ?? "") }

    // Verified against a real account: Garmin Connect returns "boxing" for f3b
    // activities. The others are kept as a defensive superset — unconfirmed but
    // harmless if never matched.
    private static let boxingKeys: Set<String> = [
        "boxing", "kickboxing", "cardio_kickboxing", "boxing_fitness",
    ]
    var isBoxing: Bool { Self.boxingKeys.contains(activityType?.typeKey ?? "") }

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
        return try JSONDecoder().decode([FailableDecodable<GarminFullActivity>].self, from: data)
            .compactMap { $0.value }
    }

    /// Downloads the original FIT file (zipped) for one activity — same endpoint the
    /// `garminconnect` Python library uses (`/download-service/files/activity/{id}`),
    /// verified against a real account before porting here.
    func downloadOriginalFIT(activityId: Int) async throws -> Data {
        let token = try await auth.ensureValidToken()
        let url = URL(string: "\(base)/download-service/files/activity/\(activityId)")!
        return try await bearer(url: url, token: token)
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

/// Decodes one array element without letting its failure fail the whole array —
/// one malformed Garmin activity (e.g. a still-processing one with unexpected nulls)
/// shouldn't zero out an entire synced page.
private struct FailableDecodable<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws {
        do {
            value = try T(from: decoder)
        } catch {
            print("GarminClient: skipping one activity — decode failed: \(error)")
            value = nil
        }
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
