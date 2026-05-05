import SwiftUI
import Charts

// Reusable for speed, HR, power, and cadence — scatter + 28-day rolling avg.
struct TrendChart: View {
    let rides: [Ride]
    let keyPath: KeyPath<Ride, Double?>
    let label: String
    let unit: String
    let color: Color

    private var data: [TrendPoint] {
        switch keyPath {
        case \.cleanAvgSpeedKmh: return RideAnalytics.speedTrend(rides)
        case \.cleanAvgHR:       return RideAnalytics.hrTrend(rides)
        case \.cleanAvgWatts:    return RideAnalytics.powerTrend(rides)
        case \.cleanAvgCadence:  return RideAnalytics.cadenceTrend(rides)
        default:                 return []
        }
    }

    var body: some View {
        let raw     = data.filter { $0.series == "raw" }
        let rolling = data.filter { $0.series == "28d avg" }

        if raw.isEmpty {
            Text("No \(label.lowercased()) data")
                .foregroundStyle(Color.veloMuted).frame(height: 220)
        } else {
            Chart {
                ForEach(raw) { pt in
                    PointMark(x: .value("Date", pt.date), y: .value(unit, pt.value))
                        .foregroundStyle(color.opacity(0.45))
                        .symbolSize(16)
                }
                ForEach(rolling) { pt in
                    LineMark(x: .value("Date", pt.date), y: .value(unit, pt.value))
                        .foregroundStyle(color)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                }
            }
            .chartXAxis { AxisMarks(values: .stride(by: .month)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.veloBorder)
                AxisValueLabel(format: .dateTime.month(.abbreviated)).foregroundStyle(Color.veloMuted)
            }}
            .chartYAxis { AxisMarks { v in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.veloBorder)
                AxisValueLabel { if let d = v.as(Double.self) {
                    Text("\(Int(d)) \(unit)").foregroundStyle(Color.veloMuted).font(.caption2)
                }}
            }}
            .frame(height: 220)
            .chartLegend(.hidden)
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 12) {
                    legend(color: color.opacity(0.45), text: label)
                    legend(color: color, text: "28d avg")
                }
                .padding(8)
            }
        }
    }

    private func legend(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).font(.system(size: 10, design: .monospaced)).foregroundStyle(Color.veloMuted)
        }
    }
}
