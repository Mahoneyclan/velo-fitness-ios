import SwiftUI

struct BoxingSessionListView: View {
    let sessions: [BoxingSession]

    fileprivate static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
            Divider().background(Color.veloBorder)
            ForEach(sessions) { s in
                NavigationLink(value: s) {
                    dataRow(s)
                }
                .buttonStyle(.plain)
                Divider().background(Color.veloBorder.opacity(0.5))
            }
        }
        .font(.system(size: 11, design: .monospaced))
        .navigationDestination(for: BoxingSession.self) { s in
            BoxingSessionDetailView(session: s)
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            col("Date",    width: 90,  color: .veloOrange)
            col("Duration",width: 80,  color: .veloOrange)
            col("Punches", width: 80,  color: .veloOrange)
            col("Rate",    width: 70,  color: .veloOrange)
            col("Max Force", width: 90, color: .veloOrange)
            col("Avg HR",  width: 70,  color: .veloOrange)
        }
        .padding(.vertical, 6).padding(.horizontal, 10)
        .background(Color.veloBorder.opacity(0.5))
    }

    private func dataRow(_ s: BoxingSession) -> some View {
        HStack(spacing: 0) {
            col(Self.dateFmt.string(from: s.date), width: 90)
            col(fmtTime(s.durationH), width: 80)
            col(s.totalPunches.map { "\($0)" } ?? "—", width: 80)
            col(s.punchRateAvg.map { String(format: "%.0f/min", $0) } ?? "—", width: 70)
            col(s.punchForceMaxDisplay ?? "—", width: 90, color: .veloPink)
            col(s.avgHR.map { String(format: "%.0f", $0) } ?? "—", width: 70, color: .veloMuted)
        }
        .padding(.vertical, 5).padding(.horizontal, 10)
    }

    private func col(_ text: String, width: CGFloat, color: Color = .veloText) -> some View {
        Text(text).foregroundStyle(color).frame(width: width, alignment: .leading).lineLimit(1)
    }
}

struct BoxingSessionDetailView: View {
    let session: BoxingSession

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    stat("Duration", fmtTime(session.durationH))
                    stat("Avg HR", session.avgHR.map { String(format: "%.0f bpm", $0) } ?? "—")
                    stat("Max HR", session.maxHR.map { String(format: "%.0f bpm", $0) } ?? "—")
                    stat("Calories", session.calories.map { String(format: "%.0f", $0) } ?? "—")
                    stat("Total Punches", session.totalPunches.map { "\($0)" } ?? "—")
                    stat("Punch Rate", session.punchRateAvg.map { String(format: "%.0f/min", $0) } ?? "—")
                    stat("Jab", session.totalJab.map { "\($0)" } ?? "—")
                    stat("Hook", session.totalHook.map { "\($0)" } ?? "—")
                    stat("Cross", session.totalCross.map { "\($0)" } ?? "—")
                    stat("Max Punch Force", session.punchForceMaxDisplay ?? "—")
                    stat("Avg 1s Punch Force", session.punchForceAvg1s.map {
                        "\(String(format: "%.1f", $0)) \(session.punchForceUnit ?? "")"
                    } ?? "—")
                    stat("Step Rate", session.stepRateAvg.map { String(format: "%.0f/min", $0) } ?? "—")
                }
                .padding(20)
            }
        }
        .background(Color.veloDark)
        .navigationTitle(BoxingSessionListView.dateFmt.string(from: session.date))
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.veloMuted)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color.veloText)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.veloCard)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
