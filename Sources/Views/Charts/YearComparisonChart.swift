import SwiftUI
import Charts

struct YearComparisonChart: View {
    let rides: [Ride]
    private var data: [YearLine] { RideAnalytics.yearComparison(rides) }
    private var years: [String] {
        Array(Set(data.map(\.year))).sorted()
    }

    private let palette: [Color] = [
        .veloOrange, .veloTeal, .veloGreen, .veloPurple,
        .veloPink, .veloAmber, Color(hex: "#60a5fa"), Color(hex: "#34d399"),
    ]

    var body: some View {
        if data.isEmpty {
            Text("No data").foregroundStyle(Color.veloMuted).frame(height: 220)
        } else {
            Chart {
                ForEach(Array(years.enumerated()), id: \.element) { i, year in
                    let pts = data.filter { $0.year == year }.sorted { $0.dayOfYear < $1.dayOfYear }
                    ForEach(pts) { pt in
                        LineMark(x: .value("Day", pt.dayOfYear),
                                 y: .value("km",  pt.cumKm),
                                 series: .value("Year", year))
                            .foregroundStyle(palette[i % palette.count])
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .interpolationMethod(.linear)
                    }
                }
            }
            .chartXAxisLabel("Day of year")
            .chartYAxisLabel("Cumulative km")
            .chartXAxis { AxisMarks(values: [1, 60, 120, 180, 240, 300, 365]) { v in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.veloBorder)
                AxisValueLabel { if let d = v.as(Int.self) { Text("\(d)").foregroundStyle(Color.veloMuted).font(.caption2) } }
            }}
            .chartYAxis { AxisMarks { v in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.veloBorder)
                AxisValueLabel { if let d = v.as(Double.self) {
                    Text("\(Int(d)) km").foregroundStyle(Color.veloMuted).font(.caption2)
                }}
            }}
            .chartLegend(position: .top, alignment: .leading) {
                HStack(spacing: 12) {
                    ForEach(Array(years.enumerated()), id: \.element) { i, year in
                        HStack(spacing: 4) {
                            Rectangle().fill(palette[i % palette.count]).frame(width: 16, height: 2)
                            Text(year).font(.system(size: 10, design: .monospaced)).foregroundStyle(Color.veloMuted)
                        }
                    }
                }
            }
            .frame(height: 220)
        }
    }
}
