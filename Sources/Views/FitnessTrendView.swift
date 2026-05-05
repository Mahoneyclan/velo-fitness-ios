import SwiftUI

struct FitnessTrendView: View {
    let rides: [Ride]
    private var periods: [FitnessPeriod] { RideAnalytics.fitnessTrend(rides) }

    var body: some View {
        if periods.isEmpty {
            Text("Not enough data for fitness trend.")
                .foregroundStyle(Color.veloMuted).padding()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                headerRow
                Divider().background(Color.veloBorder)
                ForEach(periods) { period in
                    dataRow(period)
                    Divider().background(Color.veloBorder.opacity(0.5))
                }
            }
            .font(.system(size: 11, design: .monospaced))
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            col("Period",     width: 200, color: .veloOrange)
            col("Rides",      width: 50,  color: .veloOrange)
            col("Distance",   width: 90,  color: .veloOrange)
            col("Avg Dist",   width: 75,  color: .veloOrange)
            col("Avg Speed",  width: 85,  color: .veloOrange)
            col("Avg HR",     width: 65,  color: .veloOrange)
            col("Efficiency", width: 80,  color: .veloOrange)
            col("Trend",      width: 50,  color: .veloOrange)
            col("Climbing",   width: 95,  color: .veloOrange)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color.veloBorder.opacity(0.5))
    }

    private func dataRow(_ p: FitnessPeriod) -> some View {
        HStack(spacing: 0) {
            col(p.label,                         width: 200)
            col("\(p.rides)",                    width: 50)
            col(String(format: "%.0f km", p.totalKm), width: 90)
            col(String(format: "%.0f km", p.avgDistKm), width: 75)
            col(p.avgSpeed.map { String(format: "%.1f km/h", $0) } ?? "—", width: 85)
            col(p.avgHR.map    { String(format: "%.0f bpm",  $0) } ?? "—", width: 65)
            col(p.efficiency.map { String(format: "%.3f", $0) }    ?? "—", width: 80)
            col(p.trend.rawValue, width: 50,
                color: p.trend == .up ? .veloGreen : p.trend == .down ? .veloPink : .veloMuted)
            col(String(format: "%.0f m", p.climbingM), width: 95)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 10)
    }

    private func col(_ text: String, width: CGFloat, color: Color = .veloText) -> some View {
        Text(text)
            .foregroundStyle(color)
            .frame(width: width, alignment: .leading)
            .lineLimit(1)
    }
}
