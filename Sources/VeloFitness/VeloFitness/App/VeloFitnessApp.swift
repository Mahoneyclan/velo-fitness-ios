import SwiftUI

@main
struct VeloFitnessApp: App {
    @State private var rideStore = RideStore()
    @State private var boxingStore = BoxingStore()

    var body: some Scene {
        WindowGroup {
            TabView {
                DashboardView()
                    .tabItem { Label("Cycling", systemImage: "bicycle") }
                BoxingDashboardView()
                    .tabItem { Label("Boxing", systemImage: "figure.boxing") }
            }
            .environment(rideStore)
            .environment(boxingStore)
            .onAppear {
                rideStore.load()
                boxingStore.load()
            }
            .preferredColorScheme(.dark)
        }
    }
}
