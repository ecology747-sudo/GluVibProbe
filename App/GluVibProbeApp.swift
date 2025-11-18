import SwiftUI
import HealthKit

@main
struct GluVibProbeApp: App {
    
    @StateObject private var healthStore = HealthStore()   // ✅

    init() {
        healthStore.requestAuthorization { success in
            print("HealthKit authorization:", success)
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthStore)           // ✅
        }
    }
}
