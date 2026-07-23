import SwiftUI

@main
struct GuyTimeApp: App {
    @StateObject private var store = FeedingStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environment(\.layoutDirection, .rightToLeft)
        }
    }
}
