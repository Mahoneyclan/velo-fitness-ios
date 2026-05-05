import SwiftUI
import Charts

struct MonthlyVolumeChart: View {
    let rides: [Ride]
    private var data: [MonthPoint] { RideAnalytics.monthlyVolume(rides) }

    var body: some View {
        if data.isEmpty {
            Text("No data").foregroundStyle(Color.veloMuted).frame(height: 220)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Chart(data) { pt in
                    BarMark(x: .value("Month", pt.month, unit: .month),
                            y: .value("km", pt.distanceKm))
                        .foregroundStyle(Color.veloOrange.opacity(0.85))
                }
                .chartXAxis { AxisMarks(values: .stride(by: .month)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.veloBorder)
                    AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                        .foregroundStyle(Color.veloMuted)
                }}
                .chartYAxis { AxisMarks { v in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.veloBorder)
                    AxisValueLabel { if let d = v.as(Double.self) { Text("\(Int(d))").foregroundStyle(Color.veloMuted).font(.caption2) } }
                }}
                .frame(height: 140)

                Chart(data) { pt in
                    LineMark(x: .value("Month", pt.month, unit: .month),
                             y: .value("m", pt.elevationM))
                        .foregroundStyle(Color.veloGreen)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    PointMark(x: .value("Month", pt.month, unit: .month),
                              y: .value("m", pt.elevationM))
                        .foregroundStyle(Color.veloGreen).symbolSize(20)
                }
                .chartXAxis(.hidden)
                .chartYAxis { AxisMarks { v in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.veloBorder)
                    AxisValueLabel { if let d = v.as(Double.self) { Text("\(Int(d))m").foregroundStyle(Color.veloGreen).font(.caption2) } }
                }}
                .frame(height: 80)

                HStack(spacing: 16) {
                    label(color: .veloOrange, text: "Distance (km)")
                    label(color: .veloGreen,  text: "Elevation (m)")
                }
            }
        }
    }

    private func label(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).font(.system(size: 10, design: .monospaced)).foregroundStyle(Color.veloMuted)
        }
    }
}
