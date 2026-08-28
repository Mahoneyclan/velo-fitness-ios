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

    /// Zoom the y-axis to the data's actual spread instead of forcing it down to 0 —
    /// with only a handful of sessions, a 0-based axis flattens real variability into
    /// a nearly straight line. Safe for a line/scatter trend chart (unlike a bar chart,
    /// where a non-zero baseline would misrepresent magnitude); the break mark below
    /// makes the truncation visible rather than silent.
    private var yDomain: ClosedRange<Double> {
        let values = points.map(\.value)
        guard let dataMin = values.min(), let dataMax = values.max() else { return 0...1 }
        if dataMin == dataMax {
            let pad = max(abs(dataMin) * 0.1, 0.5)
            return max(0, dataMin - pad)...(dataMax + pad)
        }
        let pad = (dataMax - dataMin) * 0.15
        return max(0, dataMin - pad)...(dataMax + pad)
    }

    private var isAxisBroken: Bool { yDomain.lowerBound > 0 }

    /// Compute exactly 4 evenly-spaced ticks ourselves — letting Charts pick its own
    /// count (even with a desiredCount hint) can still pack 6 ticks into a range too
    /// narrow to label distinctly at any fixed precision.
    private var yAxisTicks: [Double] {
        let step = (yDomain.upperBound - yDomain.lowerBound) / 3
        return (0...3).map { yDomain.lowerBound + Double($0) * step }
    }

    /// Smallest decimal precision (0–3) at which every tick in yAxisTicks formats to
    /// a distinct string — a zoomed-in domain can need more than the "obvious" 1
    /// decimal place to keep adjacent ticks from colliding on the same label.
    private var tickDecimals: Int {
        for decimals in 0...3 {
            let formatted = yAxisTicks.map { String(format: "%.\(decimals)f", $0) }
            if Set(formatted).count == formatted.count { return decimals }
        }
        return 3
    }

    private func formattedTick(_ value: Double) -> String {
        String(format: "%.\(tickDecimals)f", value)
    }

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
            .chartYScale(domain: yDomain)
            .chartXAxis { AxisMarks(values: .stride(by: .month)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.veloBorder)
                AxisValueLabel(format: .dateTime.month(.abbreviated)).foregroundStyle(Color.veloMuted)
            }}
            .chartYAxis { AxisMarks(values: yAxisTicks) { v in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.veloBorder)
                AxisValueLabel { if let d = v.as(Double.self) {
                    Text("\(formattedTick(d)) \(unit)").foregroundStyle(Color.veloMuted).font(.caption2)
                }}
            }}
            .frame(height: 220)
            .chartLegend(.hidden)
            .chartOverlay { proxy in
                if isAxisBroken, let plotFrame = proxy.plotFrame {
                    GeometryReader { geo in
                        let rect = geo[plotFrame]
                        AxisBreakMark()
                            .position(x: rect.minX, y: rect.maxY)
                    }
                }
            }
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

/// A small "//" zigzag drawn across the y-axis to flag a non-zero baseline —
/// the standard visual convention for a truncated/broken axis.
private struct AxisBreakMark: View {
    var body: some View {
        ZStack {
            Rectangle().fill(Color.veloDark).frame(width: 14, height: 12)
            ZigZag().stroke(Color.veloMuted, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .frame(width: 10, height: 8)
        }
    }

    private struct ZigZag: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: 0, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.width * 0.4, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.width * 0.6, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.width, y: rect.minY))
            return p
        }
    }
}
