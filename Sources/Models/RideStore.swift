import Foundation
import Observation

enum TimeRange: String, CaseIterable, Identifiable {
    case all = "All time", year = "This year"
    case threeM = "Last 3 months", sixM = "Last 6 months"
    case twelveM = "Last 12 months", twoY = "Last 2 years"
    case threeY = "Last 3 years", fiveY = "Last 5 years"
    var id: String { rawValue }

    func cutoff() -> Date? {
        let now = Date()
        switch self {
        case .all:    return nil
        case .year:   return Calendar.current.date(from: Calendar.current.dateComponents([.year], from: now))
        case .threeM: return now.addingTimeInterval(-90   * 86400)
        case .sixM:   return now.addingTimeInterval(-180  * 86400)
        case .twelveM:return now.addingTimeInterval(-365  * 86400)
        case .twoY:   return now.addingTimeInterval(-730  * 86400)
        case .threeY: return now.addingTimeInterval(-1095 * 86400)
        case .fiveY:  return now.addingTimeInterval(-1825 * 86400)
        }
    }
}

enum RideTypeFilter: String, CaseIterable, Identifiable {
    case all       = "All types"
    case outdoor   = "Outdoor only"
    case indoor    = "Indoor only"
    case commute   = "Commutes only"
    case noCommute = "No commutes"
    var id: String { rawValue }
}

@Observable @MainActor
final class RideStore {
    private(set) var rides: [Ride]     = []
    private(set) var isLoading         = false
    private(set) var syncStatus: String = ""
    private(set) var lastError: String?

    var timeRange:    TimeRange      = .all
    var rideType:     RideTypeFilter = .all
    var customType:   String?        = nil    // specific activity_type string

    var filtered: [Ride] {
        var r = rides
        if let cutoff = timeRange.cutoff() { r = r.filter { $0.date >= cutoff } }
        switch rideType {
        case .all:       break
        case .outdoor:   r = r.filter { !$0.indoor }
        case .indoor:    r = r.filter {  $0.indoor }
        case .commute:   r = r.filter {  $0.commute }
        case .noCommute: r = r.filter { !$0.commute }
        }
        if let t = customType { r = r.filter { $0.activityType == t } }
        return r
    }

    var availableActivityTypes: [String] {
        Array(Set(rides.map(\.activityType))).sorted()
    }

    var sourceDescription: String {
        let sources = Dictionary(grouping: rides, by: \.source)
            .map { "\($0.value.count) from \($0.key.capitalized)" }
            .sorted()
        return sources.joined(separator: " / ")
    }

    // MARK: - Persistence

    private let fileURL: URL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appending(path: "rides.json")

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data   = try Data(contentsOf: fileURL)
            let loaded = try JSONDecoder().decode([Ride].self, from: data)
            rides = qualityFilter(loaded).sorted { $0.date < $1.date }
        } catch {
            lastError = "Load error: \(error.localizedDescription)"
        }
    }

    private func save() throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(rides).write(to: fileURL, options: .atomic)
    }

    // MARK: - Strava sync (all pages, 200/page)

    func syncStrava() async {
        isLoading = true; lastError = nil
        defer { isLoading = false }
        let client = StravaClient()
        var page = 1; var fetched: [Ride] = []
        do {
            while true {
                syncStatus = "Strava page \(page)…"
                let batch = try await client.activities(page: page)
                if batch.isEmpty { break }
                fetched.append(contentsOf: batch.filter(\.isCycling).map { $0.toRide() })
                if batch.count < 200 { break }
                page += 1
                try await Task.sleep(for: .seconds(1))  // respect rate limits
            }
            syncStatus = "Merging \(fetched.count) Strava rides…"
            mergeAndSave(fetched)
            syncStatus = "\(rides.count) rides total"
        } catch {
            lastError = error.localizedDescription
            syncStatus = ""
        }
    }

    // MARK: - Garmin sync (all pages, 100/page)

    func syncGarmin() async {
        isLoading = true; lastError = nil
        defer { isLoading = false }
        let client = GarminClient()
        var start = 0; var fetched: [Ride] = []
        do {
            while true {
                syncStatus = "Garmin batch \(start)…"
                let batch = try await client.activities(start: start)
                if batch.isEmpty { break }
                fetched.append(contentsOf: batch.filter(\.isCycling).map { $0.toRide() })
                if batch.count < 100 { break }
                start += 100
                try await Task.sleep(for: .milliseconds(300))
            }
            syncStatus = "Merging \(fetched.count) Garmin rides…"
            mergeAndSave(fetched)
            syncStatus = "\(rides.count) rides total"
        } catch {
            lastError = error.localizedDescription
            syncStatus = ""
        }
    }

    // MARK: - Merge + dedup

    private func mergeAndSave(_ newRides: [Ride]) {
        rides = qualityFilter(deduplicate(rides + newRides)).sorted { $0.date < $1.date }
        try? save()
    }

    private func qualityFilter(_ input: [Ride]) -> [Ride] {
        input.filter { ($0.distanceKm >= 1.0 || $0.movingTimeS >= 300) && $0.movingTimeS >= 300 }
    }

    private func deduplicate(_ input: [Ride]) -> [Ride] {
        let cal = Calendar.current
        let byDay = Dictionary(grouping: input) { cal.startOfDay(for: $0.date) }
        var unique: [Ride] = []

        for (_, group) in byDay {
            if group.count == 1 { unique.append(group[0]); continue }
            let strava = group.filter { $0.source == "strava" }
            let garmin = group.filter { $0.source == "garmin" }
            guard !strava.isEmpty, !garmin.isEmpty else { unique.append(contentsOf: group); continue }

            var matched = Set<String>()
            for g in garmin {
                for s in strava {
                    let gkm = g.distanceKm, skm = s.distanceKm
                    if gkm == 0 && skm == 0 { matched.insert(g.id); break }
                    if gkm > 0 && skm > 0 && min(gkm, skm) / max(gkm, skm) >= 0.90 {
                        matched.insert(g.id); break
                    }
                }
            }
            unique.append(contentsOf: strava)
            unique.append(contentsOf: garmin.filter { !matched.contains($0.id) })
        }
        return unique
    }
}
