//
// ContentView.swift
// AIFWDashboard
//

import SwiftUI

struct ContentView: View {
    @StateObject private var database = ActivityDatabase()
    @State private var selectedTab = 0
    @State private var autoRefresh = true

    let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationView {
            // Sidebar
            List {
                NavigationLink(destination: ActivityView(database: database)) {
                    Label("Activity", systemImage: "list.bullet")
                }
                .tag(0)

                NavigationLink(destination: StatsView(database: database)) {
                    Label("Statistics", systemImage: "chart.bar")
                }
                .tag(1)

                NavigationLink(destination: PolicyView()) {
                    Label("Policy", systemImage: "shield")
                }
                .tag(2)
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 200)

            // Default view
            ActivityView(database: database)
        }
        .onAppear {
            database.loadActivities()
            database.loadStatistics()
        }
        .onReceive(timer) { _ in
            if autoRefresh {
                database.loadActivities()
                database.loadStatistics()
            }
        }
    }
}
