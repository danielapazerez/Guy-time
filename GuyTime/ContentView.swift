import SwiftUI

struct ContentView: View {
    @State private var showSplash = true

    var body: some View {
        ZStack {
            TabView {
                HomeView().tabItem { Label("ראשי", systemImage: "house.fill") }
                HistoryView().tabItem { Label("היסטוריה", systemImage: "clock.arrow.circlepath") }
                StatisticsView().tabItem { Label("גרפים", systemImage: "chart.xyaxis.line") }
                SettingsView().tabItem { Label("הגדרות", systemImage: "gearshape.fill") }
            }

            if showSplash {
                SplashView().transition(.opacity).zIndex(10)
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(1.0))
            withAnimation(.easeOut(duration: 0.35)) { showSplash = false }
        }
    }
}

private struct SplashView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "heart.circle.fill").font(.system(size: 84)).foregroundStyle(.pink)
                Text("Guy Time").font(.system(size: 34, weight: .bold, design: .rounded))
                Text("הזמן של גיא").foregroundStyle(.secondary)
            }
        }
    }
}
