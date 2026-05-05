import SwiftUI
import Charts

struct TrainingLoadChart: View {
    let rides: [Ride]
    private var data: [LoadPoint] { RideAnalytics.trainingLoad(rides) }

    var body: some View {
        if data.isEmpty {
            Text("No data").foregroundStyle(Color.veloMuted).frame(height: 280)
        } else {
            Chart {
                ForEach(data) { pt in
                    BarMark(x: .value("Week", pt.week, unit: .weekOfYear),
                            y: .value("Load", pt.weeklyLoad))
                        .foregroundStyle(Color.veloOrange.opacity(0.35))
                        .annotation(position: .overlay) { }
                }
                ForEach(data) { pt in
                    LineMark(x: .value("Week", pt.week, unit: .weekOfYear),
                             y: .value("CTL", pt.ctl),
                             series: .value("Series", "Fitness (CTL)"))
                        .foregroundStyle(Color.veloGreen)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                }
                ForEach(data) { pt in
                    LineMark(x: .value("Week", pt.week, unit: .weekOfYear),
                             y: .value("ATL", pt.atl),
                             series: .value("Series", "Fatigue (ATL)"))
                        .foregroundStyle(Color.veloPink)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                }
                ForEach(data) { pt in
                    LineMark(x: .value("Week", pt.week, unit: .weekOfYear),
                             y: .value("TSB", pt.tsb),
                             series: .value("Series", "Form (TSB)"))
                        .foregroundStyle(Color.veloTeal)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        .interpolationMethod(.catmullRom)
                    AreaMark(x: .value("Week", pt.week, unit: .weekOfYear),
                             y: .value("TSB", pt.tsb))
                        .foregroundStyle(Color.veloTeal.opacity(0.06))
                }
            }
            .chartXAxis { AxisMarks(values: .stride(by: .month)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.veloBorder)
                AxisValueLabel(format: .dateTime.month(.abbreviated)).foregroundStyle(Color.veloMuted)
            }}
            .chartYAxis { AxisMarks { v in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.veloBorder)
                AxisValueLabel { if let d = v.as(Double.self) {
                    Text(String(format: "%.0f", d)).foregroundStyle(Color.veloMuted).font(.caption2)
                }}
            }}
            .chartLegend(position: .top, alignment: .leading) {
                HStack(spacing: 16) {
                    label(color: .veloOrange.opacity(0.5), text: "Weekly Load")
                    label(color: .veloGreen,  text: "Fitness (CTL)")
                    label(color: .veloPink,   text: "Fatigue (ATL)")
                    label(color: .veloTeal,   text: "Form (TSB)")
                }
            }
            .frame(height: 280)
        }
    }

    private func label(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).font(.system(size: 10, design: .monospaced)).foregroundStyle(Color.veloMuted)
        }
    }
}
