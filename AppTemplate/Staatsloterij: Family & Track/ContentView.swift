import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        Group {
            if store.isLoading {
                ZStack {
                    AppBackground()
                    ProgressView()
                        .tint(.white)
                        .accessibilityLabel("common.loading")
                }
            } else if store.isAuthenticated {
                MainTabView()
            } else {
                AuthenticationView()
            }
        }
        .environment(\.locale, store.settings.language.locale)
        .alert("common.error", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("common.ok") { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }
}

private struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label("tab.home", systemImage: "house.fill") }
            NavigationStack { TicketsView() }
                .tabItem { Label("tab.tickets", systemImage: "ticket.fill") }
            NavigationStack { CalendarView() }
                .tabItem { Label("tab.calendar", systemImage: "calendar") }
            NavigationStack { FamilyDrawView() }
                .tabItem { Label("tab.family", systemImage: "person.3.fill") }
            NavigationStack { AnalyticsView() }
                .tabItem { Label("tab.analytics", systemImage: "chart.xyaxis.line") }
        }
    }
}
