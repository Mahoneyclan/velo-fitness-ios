import SwiftUI
import Charts

struct BoxingDashboardView: View {
    @Environment(BoxingStore.self) private var store

    private var sessions: [BoxingSession] { store.sortedSessions }

    // MARK: - Summary stats

    private var totalSessions: Int { sessions.count }
    private var totalHours: Double { sessions.map(\.durationH).reduce(0, +) }
    private var totalPunches: Int { sessions.compactMap(\.totalPunches).reduce(0, +) }
    private var avgPunchRate: Double? {
        let vals = sessions.compactMap(\.punchRateAvg)
        return vals.isEmpty ? nil : vals.reduce(0, +) / Double(vals.count)
    }
    private var bestForceSession: BoxingSession? { store.allTimeBestForce }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // ── Stat cards ──
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            StatCardView(title: "Sessions",       value: "\(totalSessions)",
                                         sub: "logged",                             color: .veloOrange)
                            StatCardView(title: "Total Time",     value: fmtTime(totalHours),
                                         sub: "training",                          color: .veloTeal)
                            StatCardView(title: "Total Punches",  value: "\(totalPunches)",
                                         sub: "across all sessions",               color: .veloGreen)
                            StatCardView(title: "Avg Punch Rate",
                                         value: avgPunchRate.map { String(format: "%.0f/min", $0) } ?? "—",
                                         sub: "across all sessions",                color: .veloPurple)
                            StatCardView(title: "Best Punch Force",
                                         value: bestForceSession?.punchForceMaxDisplay ?? "—",
                                         sub: "all-time PB",                        color: .veloPink)
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 20)

                    if sessions.isEmpty {
                        emptyState
                    } else {
                        // ── Charts grid ── (priority order: rate, force, HR, mix, volume)
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
                                  spacing: 14) {
                            ChartCard(title: "Punch Rate Trend") {
                                BoxingTrendChart(points: BoxingAnalytics.punchRateTrend(sessions),
                                                 label: "Punch rate", unit: "/min", color: .veloTeal)
                            }
                            ChartCard(title: "Punch Force Trend") {
                                BoxingTrendChart(points: BoxingAnalytics.punchForceTrend(sessions),
                                                 label: "Punch force", unit: sessions.first?.punchForceUnit ?? "",
                                                 color: .veloPink)
                            }
                            ChartCard(title: "Heart Rate Trend") {
                                BoxingTrendChart(points: BoxingAnalytics.hrTrend(sessions),
                                                 label: "Avg HR", unit: "bpm", color: .veloOrange)
                            }
                            ChartCard(title: "Jab / Hook / Cross Mix") {
                                PunchMixChart(sessions: sessions)
                            }
                            ChartCard(title: "Jab / Hook / Cross Share") {
                                PunchMixShareChart(sessions: sessions)
                            }
                            ChartCard(title: "Session Duration") {
                                BoxingVolumeChart(sessions: sessions)
                            }
                        }
                        .padding(.horizontal, 20)

                        SectionHeader(text: "Sessions")
                            .padding(.horizontal, 20).padding(.top, 20)
                        BoxingSessionListView(sessions: Array(sessions.reversed()))
                            .padding(.horizontal, 20).padding(.bottom, 20)
                    }
                }
            }
            .background(Color.veloDark)
            .navigationTitle("Boxing")
            .toolbar { toolbarContent }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No boxing sessions yet")
                .font(.headline).foregroundStyle(Color.veloText)
            Text("Tap Sync to pull boxing activities from Garmin.")
                .font(.footnote).foregroundStyle(Color.veloMuted)
                .multilineTextAlignment(.center)
            if let err = store.lastError {
                Text(err).font(.caption2).foregroundStyle(Color.veloPink).padding(.top, 4)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 12) {
                if store.isLoading {
                    Text(store.syncStatus)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color.veloMuted)
                }
                Button {
                    Task { await store.syncGarmin() }
                } label: {
                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(store.isLoading ? Color.veloMuted : Color.veloOrange)
                }
                .disabled(store.isLoading)
            }
        }
    }
}
