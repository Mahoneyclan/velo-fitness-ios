import SwiftUI
import Charts

struct DashboardView: View {
    @Environment(RideStore.self) private var store
    @State private var showStravaImport = false
    @State private var showGarminImport = false

    private var rides: [Ride] { store.filtered }

    // MARK: - Summary stats

    private var totalRides: Int  { rides.count }
    private var totalKm: Double  { rides.map(\.distanceKm).reduce(0, +) }
    private var totalHours: Double { rides.map(\.movingTimeH).reduce(0, +) }
    private var totalElevKm: Double { rides.map(\.elevationM).reduce(0, +) / 1000 }
    private var bestRideKm: Double { rides.map(\.distanceKm).max() ?? 0 }
    private var avgSpeed: Double? {
        let vals = rides.compactMap(\.cleanAvgSpeedKmh)
        return vals.isEmpty ? nil : vals.reduce(0, +) / Double(vals.count)
    }
    private var spanYears: Double {
        guard let first = rides.first?.date, let last = rides.last?.date else { return 0 }
        return max(last.timeIntervalSince(first) / (365.25 * 86400), 0.01)
    }
    private var avgPerRide: Double { totalRides > 0 ? totalKm / Double(totalRides) : 0 }

    var body: some View {
        @Bindable var bindStore = store

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // ── Stat cards ──
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            StatCardView(title: "Total Rides",    value: "\(totalRides)",
                                         sub: "over \(String(format: "%.1f", spanYears)) years", color: .veloOrange)
                            StatCardView(title: "Total Distance", value: "\(Int(totalKm)) km",
                                         sub: "avg \(Int(avgPerRide)) km/ride",   color: .veloTeal)
                            StatCardView(title: "Total Time",     value: fmtTime(totalHours),
                                         sub: "",                                  color: .veloGreen)
                            StatCardView(title: "Climbing",       value: String(format: "%.1f km", totalElevKm),
                                         sub: "total elevation",                   color: .veloPurple)
                            StatCardView(title: "Best Ride",      value: "\(Int(bestRideKm)) km",
                                         sub: "longest single ride",               color: .veloPink)
                            StatCardView(title: "Avg Speed",
                                         value: avgSpeed.map { String(format: "%.1f km/h", $0) } ?? "—",
                                         sub: "across all rides",                  color: .veloAmber)
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 20)

                    // ── Charts grid ──
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
                              spacing: 14) {
                        ChartCard(title: "Weekly Distance & Riding Time") {
                            WeeklyVolumeChart(rides: rides)
                        }
                        ChartCard(title: "Monthly Distance & Elevation") {
                            MonthlyVolumeChart(rides: rides)
                        }
                        ChartCard(title: "Speed Trend") {
                            TrendChart(rides: rides, keyPath: \.cleanAvgSpeedKmh,
                                       label: "Avg speed", unit: "km/h", color: .veloTeal)
                        }
                        ChartCard(title: "Heart Rate Trend") {
                            TrendChart(rides: rides, keyPath: \.cleanAvgHR,
                                       label: "Avg HR", unit: "bpm", color: .veloPink)
                        }
                        ChartCard(title: "Power Trend") {
                            TrendChart(rides: rides, keyPath: \.cleanAvgWatts,
                                       label: "Avg power", unit: "W", color: .veloPurple)
                        }
                        ChartCard(title: "Cadence Trend") {
                            TrendChart(rides: rides, keyPath: \.cleanAvgCadence,
                                       label: "Avg cadence", unit: "rpm", color: .veloAmber)
                        }
                        ChartCard(title: "Cumulative Distance by Year") {
                            YearComparisonChart(rides: rides)
                        }
                        ChartCard(title: "Ride Distance Distribution") {
                            HistogramChart(rides: rides)
                        }
                    }
                    .padding(.horizontal, 20)

                    // Full-width: training load
                    ChartCard(title: "Training Load — Fitness / Fatigue / Form") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CTL = Fitness (42-week EMA) · ATL = Fatigue (7-week EMA) · TSB = Form (CTL − ATL)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Color.veloMuted)
                            TrainingLoadChart(rides: rides)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)

                    // Full-width: heatmap
                    ChartCard(title: "Annual Volume Heatmap") {
                        HeatmapChart(rides: rides)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)

                    // Full-width: fitness trend table
                    ChartCard(title: "Fitness Trend") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("90-day rolling windows · Efficiency = avg speed ÷ avg HR · Higher = fitter")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Color.veloMuted)
                            ScrollView(.horizontal) {
                                FitnessTrendView(rides: rides)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)

                    // Full-width: personal bests
                    ChartCard(title: "Personal Bests") {
                        ScrollView(.horizontal) {
                            PersonalBestsView(rides: rides)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 32)
                }
            }
            .background(Color.veloDark)
            .navigationTitle("")
            .toolbar { toolbarContent }
        }
        .sheet(isPresented: $showStravaImport) { StravaImportView() }
        .sheet(isPresented: $showGarminImport) { GarminImportView() }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Leading: app name + data source
        ToolbarItem(placement: .navigationBarLeading) {
            VStack(alignment: .leading, spacing: 1) {
                Text("VELO FITNESS")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(Color.veloOrange)
                    .tracking(3)
                if !store.sourceDescription.isEmpty {
                    Text(store.sourceDescription)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color.veloMuted)
                }
            }
        }

        // Trailing: sync + filters
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 12) {
                // Sync menu
                Menu {
                    Button("Sync Strava") { showStravaImport = true }
                    Button("Sync Garmin") { showGarminImport = true }
                } label: {
                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(store.isLoading ? Color.veloMuted : Color.veloOrange)
                }
                .disabled(store.isLoading)

                // Type filter
                @Bindable var bindStore = store
                Picker("Type", selection: $bindStore.rideType) {
                    ForEach(RideTypeFilter.allCases) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.veloMuted)

                // Time range filter
                Picker("Range", selection: $bindStore.timeRange) {
                    ForEach(TimeRange.allCases) { r in
                        Text(r.rawValue).tag(r)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.veloMuted)
            }
        }
    }
}

// MARK: - Empty state

private struct EmptyDashboard: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "bicycle").font(.system(size: 72)).foregroundStyle(Color.veloOrange)
            Text("No rides yet").font(.title2.bold()).foregroundStyle(Color.veloText)
            Text("Tap the sync button to import from Strava or Garmin.")
                .foregroundStyle(Color.veloMuted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.veloDark)
    }
}
