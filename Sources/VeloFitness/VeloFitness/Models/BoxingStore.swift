import Foundation
import Observation

/// Syncs directly from Garmin Connect, on-device — same pattern as RideStore's
/// Garmin path, just with a FIT-parsing step (FITBoxingParser) instead of using the
/// activity-list summary. No server, no Python, no iCloud: purely local storage,
/// mirroring how RideStore persists rides.json.
@Observable @MainActor
final class BoxingStore {
    private(set) var sessions: [BoxingSession] = []
    private(set) var isLoading = false
    private(set) var syncStatus = ""
    private(set) var lastError: String?

    var sortedSessions: [BoxingSession] { sessions.sorted { $0.date < $1.date } }

    var allTimeBestForce: BoxingSession? {
        let withForce = sessions.filter { $0.punchForceMax != nil }
        return withForce.max { a, b in
            let av: Double = a.punchForceMax ?? 0
            let bv: Double = b.punchForceMax ?? 0
            return av < bv
        }
    }

    private let fileURL: URL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appending(path: "boxing_sessions.json")

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            sessions = try JSONDecoder().decode([BoxingSession].self, from: data)
        } catch {
            lastError = "Load error: \(error.localizedDescription)"
        }
    }

    private func save() {
        do {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(sessions).write(to: fileURL, options: .atomic)
        } catch {
            lastError = "Save error: \(error.localizedDescription)"
        }
    }

    /// Fetches new boxing activities from Garmin, downloads + parses each one's FIT
    /// file, and merges into local storage. Requires GarminAuth already signed in
    /// (shared with the Cycling tab's Garmin sync — no separate boxing login).
    func syncGarmin() async {
        guard GarminAuth.shared.isAuthenticated else {
            lastError = "Sign in to Garmin from the Cycling tab first (Garmin Sync) — boxing reuses that same session."
            return
        }
        isLoading = true; lastError = nil
        defer { isLoading = false }

        let client = GarminClient()
        let existingIDs = Set(sessions.map(\.id))
        var newSessions: [BoxingSession] = []
        var start = 0
        let batchSize = 100

        do {
            while true {
                syncStatus = "Garmin batch \(start)…"
                let batch = try await client.activities(start: start, limit: batchSize)
                if batch.isEmpty { break }

                for activity in batch where activity.isBoxing {
                    let sessionID = "garmin_\(activity.activityId)"
                    guard !existingIDs.contains(sessionID) else { continue }

                    syncStatus = "Downloading \(activity.activityName)…"
                    do {
                        let zipped = try await client.downloadOriginalFIT(activityId: activity.activityId)
                        guard let metrics = FITBoxingParser.parse(zippedFIT: zipped) else {
                            print("BoxingStore: FIT parse failed for activity \(activity.activityId)")
                            continue
                        }
                        let date = Ride.parseDate(activity.startTimeLocal) ?? Date()
                        newSessions.append(BoxingSession(activityId: activity.activityId, date: date, metrics: metrics))
                    } catch {
                        print("BoxingStore: download/parse failed for activity \(activity.activityId): \(error)")
                    }
                }

                if batch.count < batchSize { break }
                start += batchSize
                try await Task.sleep(for: .milliseconds(300))
            }

            sessions = (sessions + newSessions).sorted { $0.date < $1.date }
            save()
            syncStatus = "\(sessions.count) sessions total (\(newSessions.count) new)"
        } catch {
            lastError = error.localizedDescription
            syncStatus = ""
        }
    }
}
