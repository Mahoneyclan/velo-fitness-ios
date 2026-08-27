import SwiftUI
import Charts

// Scatter + 28-day rolling average, for punch rate / punch force / HR.
// Mirrors TrendChart.swift's rendering but takes precomputed TrendPoints directly
// instead of switching on a Ride keyPath, so it doesn't need to touch that file.
struct BoxingTrendChart: View {
    let points: [TrendPoint]
    let label: String
    let unit: String
    let color: Color

    var body: some View {
        let raw     = points.filter { $0.series == "raw" }
        let rolling = points.filter { $0.series == "28d avg" }

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
