import SwiftUI
import Charts

// Grouped bar of jab/hook/cross counts per session.
struct PunchMixChart: View {
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
                    y: .value("Punches", pt.count)
                )
                .foregroundStyle(by: .value("Type", pt.type))
                .position(by: .value("Type", pt.type))
            }
            .chartForegroundStyleScale([
                "Jab":   Color.veloTeal,
                "Hook":  Color.veloOrange,
                "Cross": Color.veloPurple,
            ])
            .chartXAxis { AxisMarks(values: .stride(by: .month)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.veloBorder)
                AxisValueLabel(format: .dateTime.month(.abbreviated)).foregroundStyle(Color.veloMuted)
            }}
            .chartYAxis { AxisMarks { v in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.veloBorder)
                AxisValueLabel { if let d = v.as(Int.self) {
                    Text("\(d)").foregroundStyle(Color.veloMuted).font(.caption2)
                }}
            }}
            .chartLegend(position: .top, alignment: .trailing)
            .frame(height: 220)
        }
    }
}
