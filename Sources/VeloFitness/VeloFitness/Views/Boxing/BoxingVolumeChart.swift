import SwiftUI
import Charts

// Session duration over time.
struct BoxingVolumeChart: View {
    let sessions: [BoxingSession]

    private var sorted: [BoxingSession] { sessions.sorted { $0.date < $1.date } }

    var body: some View {
        if sorted.isEmpty {
            Text("No session data")
                .foregroundStyle(Color.veloMuted).frame(height: 220)
        } else {
            Chart(sorted) { s in
                BarMark(
                    x: .value("Date", s.date, unit: .day),
                    y: .value("Minutes", s.durationH * 60)
                )
                .foregroundStyle(Color.veloGreen)
            }
            .chartXAxis { AxisMarks(values: .stride(by: .month)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.veloBorder)
                AxisValueLabel(format: .dateTime.month(.abbreviated)).foregroundStyle(Color.veloMuted)
            }}
            .chartYAxis { AxisMarks { v in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.veloBorder)
                AxisValueLabel { if let d = v.as(Double.self) {
                    Text("\(Int(d))m").foregroundStyle(Color.veloMuted).font(.caption2)
                }}
            }}
            .frame(height: 220)
        }
    }
}
