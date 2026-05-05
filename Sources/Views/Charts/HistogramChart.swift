import SwiftUI
import Charts

struct HistogramChart: View {
    let rides: [Ride]

    private struct Bin: Identifiable {
        let id = UUID()
        let range: String
        let count: Int
        let midpoint: Double
    }

    private var bins: [Bin] {
        guard !rides.isEmpty else { return [] }
        let distances = rides.map(\.distanceKm)
        let maxDist   = distances.max() ?? 0
        let binWidth  = max(ceil(maxDist / 30), 5.0)
        let numBins   = Int(ceil(maxDist / binWidth))

        return (0..<numBins).map { i in
            let lo    = Double(i) * binWidth
            let hi    = lo + binWidth
            let count = distances.filter { $0 >= lo && $0 < hi }.count
            return Bin(range: "\(Int(lo))–\(Int(hi))", count: count, midpoint: lo + binWidth / 2)
        }.filter { $0.count > 0 }
    }

    var body: some View {
        if bins.isEmpty {
            Text("No data").foregroundStyle(Color.veloMuted).frame(height: 180)
        } else {
            Chart(bins) { bin in
                BarMark(x: .value("Distance", bin.midpoint),
                        y: .value("Rides", bin.count))
                    .foregroundStyle(Color.veloOrange.opacity(0.85))
            }
            .chartXAxisLabel("Distance (km)")
            .chartYAxisLabel("Rides")
            .chartXAxis { AxisMarks { v in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.veloBorder)
                AxisValueLabel { if let d = v.as(Double.self) {
                    Text("\(Int(d))").foregroundStyle(Color.veloMuted).font(.caption2)
                }}
            }}
            .chartYAxis { AxisMarks { v in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.veloBorder)
                AxisValueLabel { if let n = v.as(Int.self) {
                    Text("\(n)").foregroundStyle(Color.veloMuted).font(.caption2)
                }}
            }}
            .frame(height: 180)
        }
    }
}
