import SwiftUI
import Charts

struct WeeklyVolumeChart: View {
    let rides: [Ride]

    private var data: [WeekPoint] { RideAnalytics.weeklyVolume(rides) }

    var body: some View {
        if data.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: 8) {
                // Distance bars
                Chart(data) { pt in
                    BarMark(x: .value("Week", pt.week, unit: .weekOfYear),
                            y: .value("km", pt.distanceKm))
                        .foregroundStyle(Color.veloOrange.opacity(0.85))
                }
                .chartXAxis { AxisMarks(values: .stride(by: .month)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.veloBorder)
                    AxisTick(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.veloBorder)
                    AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                        .foregroundStyle(Color.veloMuted)
                }}
                .chartYAxis { AxisMarks { v in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.veloBorder)
                    AxisValueLabel { if let d = v.as(Double.self) { Text("\(Int(d)) km").foregroundStyle(Color.veloMuted).font(.caption2) } }
                }}
                .frame(height: 140)

                // Time line
                Chart(data) { pt in
                    LineMark(x: .value("Week", pt.week, unit: .weekOfYear),
                             y: .value("h",  pt.timeH))
                        .foregroundStyle(Color.veloTeal)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    AreaMark(x: .value("Week", pt.week, unit: .weekOfYear),
                             y: .value("h",  pt.timeH))
                        .foregroundStyle(Color.veloTeal.opacity(0.08))
                }
                .chartXAxis(.hidden)
                .chartYAxis { AxisMarks { v in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.veloBorder)
                    AxisValueLabel { if let d = v.as(Double.self) { Text(fmtTime(d)).foregroundStyle(Color.veloTeal).font(.caption2) } }
                }}
                .frame(height: 80)

                HStack(spacing: 16) {
                    label(color: .veloOrange, text: "Distance (km)")
                    label(color: .veloTeal,   text: "Riding time")
                }
            }
        }
    }

    private var emptyState: some View {
        Text("No data").foregroundStyle(Color.veloMuted).frame(height: 220)
    }

    private func label(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).font(.system(size: 10, design: .monospaced)).foregroundStyle(Color.veloMuted)
        }
    }
}
