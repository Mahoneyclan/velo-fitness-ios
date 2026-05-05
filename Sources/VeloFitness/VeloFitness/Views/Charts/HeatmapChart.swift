import SwiftUI
import Charts

struct HeatmapChart: View {
    let rides: [Ride]
    private var cells: [HeatCell] { RideAnalytics.heatmap(rides) }
    private var years: [String] { Array(Set(cells.map(\.year))).sorted() }
    private var maxKm: Double { cells.map(\.distanceKm).max() ?? 1 }

    var body: some View {
        if cells.isEmpty {
            Text("No data").foregroundStyle(Color.veloMuted).frame(height: 160)
        } else {
            Chart(cells) { cell in
                RectangleMark(
                    x: .value("Week", cell.week),
                    y: .value("Year", cell.year),
                    width: .ratio(0.9),
                    height: .ratio(0.9)
                )
                .foregroundStyle(by: .value("km", cell.distanceKm))
            }
            .chartForegroundStyleScale(range: Gradient(colors: [
                Color.veloDark.opacity(0.6), Color.veloAmber.opacity(0.5), Color.veloOrange,
            ]))
            .chartXAxis { AxisMarks(values: [1, 13, 26, 39, 52]) { v in
                AxisValueLabel { if let w = v.as(Int.self) {
                    let months = ["Jan", "Apr", "Jul", "Oct", "Dec"]
                    let idx    = [1, 13, 26, 39, 52].firstIndex(of: w) ?? 0
                    Text(idx < months.count ? months[idx] : "").foregroundStyle(Color.veloMuted).font(.caption2)
                }}
            }}
            .chartYAxis { AxisMarks { v in
                AxisValueLabel { if let y = v.as(String.self) {
                    Text(y).foregroundStyle(Color.veloMuted).font(.caption2)
                }}
            }}
            .chartLegend(.hidden)
            .frame(height: max(Double(years.count) * 32 + 40, 100))
        }
    }
}
