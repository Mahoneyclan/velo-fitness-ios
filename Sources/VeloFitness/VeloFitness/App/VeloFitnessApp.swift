import SwiftUI

@main
struct VeloFitnessApp: App {
    @State private var store = RideStore()

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environment(store)
                .onAppear { store.load() }
                .preferredColorScheme(.dark)
        }
    }
}
