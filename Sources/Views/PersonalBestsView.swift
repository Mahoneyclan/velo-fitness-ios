import SwiftUI

struct PersonalBestsView: View {
    let rides: [Ride]
    private var bests: [PersonalBest] { RideAnalytics.personalBests(rides) }

    var body: some View {
        if bests.isEmpty {
            Text("No personal bests found.").foregroundStyle(Color.veloMuted).padding()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                headerRow
                Divider().background(Color.veloBorder)
                ForEach(bests) { best in
                    dataRow(best)
                    Divider().background(Color.veloBorder.opacity(0.5))
                }
            }
            .font(.system(size: 11, design: .monospaced))
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            col("Record",    width: 160, color: .veloOrange)
            col("Value",     width: 100, color: .veloOrange)
            col("Ride",      width: 280, color: .veloOrange)
            col("Date",      width: 90,  color: .veloOrange)
        }
        .padding(.vertical, 6).padding(.horizontal, 10)
        .background(Color.veloBorder.opacity(0.5))
    }

    private func dataRow(_ b: PersonalBest) -> some View {
        HStack(spacing: 0) {
            col(b.record,   width: 160)
            col(b.value,    width: 100, color: .veloOrange)
            col(b.rideName, width: 280)
            col(b.date,     width: 90,  color: .veloMuted)
        }
        .padding(.vertical, 5).padding(.horizontal, 10)
    }

    private func col(_ text: String, width: CGFloat, color: Color = .veloText) -> some View {
        Text(text).foregroundStyle(color).frame(width: width, alignment: .leading).lineLimit(1)
    }
}
