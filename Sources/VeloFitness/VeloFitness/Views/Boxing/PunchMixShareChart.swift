import SwiftUI
import Charts

// 100%-stacked column of jab/hook/cross share per session — each session's column
// sums to 100%, showing punch-type mix rather than raw volume (see PunchMixChart
// for the raw-count grouped-bar version).
struct PunchMixShareChart: View {
    let sessions: [BoxingSession]

    private var data: [BoxingAnalytics.PunchMixPoint] { BoxingAnalytics.punchMix(sessions) }

    var body: some View {
        if data.isEmpty {
            Text("No punch mix data")
                .foregroundStyle(Color.veloMuted).frame(height: 220)
        } else {
            Chart(data) { pt in
                BarMark(
                    x: .value("Date", pt.date, unit: .day),
                    y: .value("Share", pt.percent)
                )
                .foregroundStyle(by: .value("Type", pt.type))
            }
            .chartForegroundStyleScale([
                "Jab":   Color.veloTeal,
                "Hook":  Color.veloOrange,
                "Cross": Color.veloPurple,
            ])
            .chartYScale(domain: 0...100)
            .chartXAxis { AxisMarks(values: .stride(by: .month)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.veloBorder)
                AxisValueLabel(format: .dateTime.month(.abbreviated)).foregroundStyle(Color.veloMuted)
            }}
            .chartYAxis { AxisMarks(values: [0, 25, 50, 75, 100]) { v in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.veloBorder)
                AxisValueLabel { if let d = v.as(Double.self) {
                    Text("\(Int(d))%").foregroundStyle(Color.veloMuted).font(.caption2)
                }}
            }}
            .chartLegend(position: .top, alignment: .trailing)
            .frame(height: 220)
        }
    }
}
