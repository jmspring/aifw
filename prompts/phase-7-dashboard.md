# Phase 7: Dashboard (Optional SwiftUI App)

**Branch**: `phase-7-dashboard`  
**Prerequisites**: Phases 0-6 complete  
**Duration**: 3-4 hours  
**Focus**: SwiftUI monitoring application  

## Objective

Implement a SwiftUI dashboard that provides real-time visualization of firewall activity, statistics, and policy management. This is an optional UI layer for users who want a graphical interface.

## Context

**Review before starting**:
- All previous phases (esp. ActivityLogger schema)
- SwiftUI basics

**What Dashboard Does**:
- Real-time activity feed
- Statistics and charts
- Policy configuration UI
- Auto-refresh

**What Dashboard Does NOT Do**:
- Run the firewall (daemon does that)
- Make policy decisions
- Interact with ES framework

## Implementation

### 1. Create Feature Branch

```bash
git checkout main
git pull origin main
git checkout -b phase-7-dashboard
```

### 2. Create SwiftUI App

Create `dashboard/Package.swift`:

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AIFWDashboard",
    platforms: [.macOS(.v13)],
    products: [
        .executable(
            name: "aifw-dashboard",
            targets: ["AIFWDashboard"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "AIFWDashboard",
            dependencies: [],
            path: "Sources"
        )
    ]
)
```

### 3. Create Main App

Create `dashboard/Sources/AIFWDashboardApp.swift`:

```swift
//
// AIFWDashboardApp.swift
// AIFWDashboard
//

import SwiftUI

@main
struct AIFWDashboardApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 600)
        }
    }
}
```

### 4. Create Data Models

Create `dashboard/Sources/Models.swift`:

```swift
//
// Models.swift
// AIFWDashboard
//

import Foundation
import SQLite3

struct ActivityRecord: Identifiable {
    let id: Int
    let timestamp: Date
    let eventType: String
    let processName: String?
    let pid: Int32
    let path: String?
    let command: String?
    let destination: String?
    let allowed: Bool
    let reason: String?
    
    var icon: String {
        switch eventType {
        case "file_write": return "doc.fill"
        case "file_delete": return "trash.fill"
        case "process_exec": return "terminal.fill"
        case "network_connect": return "network"
        default: return "questionmark.circle"
        }
    }
    
    var color: String {
        allowed ? "green" : "red"
    }
}

struct Statistics {
    var total: Int = 0
    var allowed: Int = 0
    var denied: Int = 0
    var byType: [String: Int] = [:]
}

class ActivityDatabase: ObservableObject {
    @Published var activities: [ActivityRecord] = []
    @Published var stats: Statistics = Statistics()
    
    private let dbPath: String
    private var db: OpaquePointer?
    
    init() {
        self.dbPath = NSHomeDirectory() + "/.config/aifw/activity.db"
        openDatabase()
    }
    
    private func openDatabase() {
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            print("Error opening database")
            return
        }
    }
    
    func loadActivities(limit: Int = 100) {
        activities.removeAll()
        
        let query = """
        SELECT id, timestamp, event_type, process_name, pid, path, 
               command, destination, allowed, reason
        FROM activity
        ORDER BY id DESC
        LIMIT ?
        """
        
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            return
        }
        
        sqlite3_bind_int(stmt, 1, Int32(limit))
        
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(stmt, 0))
            let timestamp = String(cString: sqlite3_column_text(stmt, 1))
            let eventType = String(cString: sqlite3_column_text(stmt, 2))
            let processName = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
            let pid = sqlite3_column_int(stmt, 4)
            let path = sqlite3_column_text(stmt, 5).map { String(cString: $0) }
            let command = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
            let destination = sqlite3_column_text(stmt, 7).map { String(cString: $0) }
            let allowed = sqlite3_column_int(stmt, 8) == 1
            let reason = sqlite3_column_text(stmt, 9).map { String(cString: $0) }
            
            let date = ISO8601DateFormatter().date(from: timestamp) ?? Date()
            
            activities.append(ActivityRecord(
                id: id,
                timestamp: date,
                eventType: eventType,
                processName: processName,
                pid: pid,
                path: path,
                command: command,
                destination: destination,
                allowed: allowed,
                reason: reason
            ))
        }
        
        sqlite3_finalize(stmt)
    }
    
    func loadStatistics() {
        let query = """
        SELECT 
            COUNT(*) as total,
            SUM(CASE WHEN allowed = 1 THEN 1 ELSE 0 END) as allowed,
            SUM(CASE WHEN allowed = 0 THEN 1 ELSE 0 END) as denied,
            event_type,
            COUNT(*) as type_count
        FROM activity
        GROUP BY event_type
        """
        
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            return
        }
        
        var total = 0
        var allowed = 0
        var denied = 0
        var byType: [String: Int] = [:]
        
        while sqlite3_step(stmt) == SQLITE_ROW {
            if total == 0 {
                total = Int(sqlite3_column_int(stmt, 0))
                allowed = Int(sqlite3_column_int(stmt, 1))
                denied = Int(sqlite3_column_int(stmt, 2))
            }
            
            let eventType = String(cString: sqlite3_column_text(stmt, 3))
            let count = Int(sqlite3_column_int(stmt, 4))
            byType[eventType] = count
        }
        
        stats = Statistics(total: total, allowed: allowed, denied: denied, byType: byType)
        
        sqlite3_finalize(stmt)
    }
}
```

### 5. Create Main View

Create `dashboard/Sources/ContentView.swift`:

```swift
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
```

### 6. Create Activity View

Create `dashboard/Sources/ActivityView.swift`:

```swift
//
// ActivityView.swift
// AIFWDashboard
//

import SwiftUI

struct ActivityView: View {
    @ObservedObject var database: ActivityDatabase
    @State private var filter: String = "All"
    @State private var searchText: String = ""
    
    var filteredActivities: [ActivityRecord] {
        var filtered = database.activities
        
        // Apply filter
        if filter == "Blocked" {
            filtered = filtered.filter { !$0.allowed }
        } else if filter == "Approved" {
            filtered = filtered.filter { $0.allowed }
        }
        
        // Apply search
        if !searchText.isEmpty {
            filtered = filtered.filter { activity in
                activity.path?.contains(searchText) ?? false ||
                activity.command?.contains(searchText) ?? false ||
                activity.destination?.contains(searchText) ?? false
            }
        }
        
        return filtered
    }
    
    var body: some View {
        VStack {
            // Header
            HStack {
                Text("Activity Log")
                    .font(.title)
                    .bold()
                
                Spacer()
                
                Picker("Filter", selection: $filter) {
                    Text("All").tag("All")
                    Text("Blocked").tag("Blocked")
                    Text("Approved").tag("Approved")
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 300)
            }
            .padding()
            
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                TextField("Search paths, commands, destinations...", text: $searchText)
            }
            .padding(8)
            .background(Color(.textBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)
            
            // Activity list
            List(filteredActivities) { activity in
                ActivityRow(activity: activity)
            }
            .listStyle(InsetListStyle())
            
            // Footer
            HStack {
                Text("Total: \(filteredActivities.count) events")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Refresh") {
                    database.loadActivities()
                }
            }
            .padding()
        }
    }
}

struct ActivityRow: View {
    let activity: ActivityRecord
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: activity.icon)
                .foregroundColor(activity.allowed ? .green : .red)
                .frame(width: 30)
            
            // Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(activity.eventType)
                        .font(.headline)
                    
                    if let processName = activity.processName {
                        Text("• \(processName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("• PID \(activity.pid)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let path = activity.path {
                    Text(path)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.primary)
                }
                
                if let command = activity.command {
                    Text(command)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.primary)
                }
                
                if let destination = activity.destination {
                    Text(destination)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.primary)
                }
                
                if let reason = activity.reason {
                    Text(reason)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(activity.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Status badge
            Text(activity.allowed ? "ALLOWED" : "DENIED")
                .font(.caption2)
                .bold()
                .padding(6)
                .background(activity.allowed ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                .foregroundColor(activity.allowed ? .green : .red)
                .cornerRadius(4)
        }
        .padding(.vertical, 8)
    }
}
```

### 7. Create Statistics View

Create `dashboard/Sources/StatsView.swift`:

```swift
//
// StatsView.swift
// AIFWDashboard
//

import SwiftUI

struct StatsView: View {
    @ObservedObject var database: ActivityDatabase
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Summary cards
                HStack(spacing: 20) {
                    StatCard(
                        title: "Total Events",
                        value: "\(database.stats.total)",
                        icon: "chart.bar.fill",
                        color: .blue
                    )
                    
                    StatCard(
                        title: "Allowed",
                        value: "\(database.stats.allowed)",
                        icon: "checkmark.circle.fill",
                        color: .green
                    )
                    
                    StatCard(
                        title: "Denied",
                        value: "\(database.stats.denied)",
                        icon: "xmark.circle.fill",
                        color: .red
                    )
                }
                .padding()
                
                // Event type breakdown
                VStack(alignment: .leading, spacing: 10) {
                    Text("Events by Type")
                        .font(.title2)
                        .bold()
                    
                    ForEach(Array(database.stats.byType.sorted(by: { $0.value > $1.value })), id: \.key) { type, count in
                        HStack {
                            Text(type)
                                .font(.headline)
                            
                            Spacer()
                            
                            Text("\(count)")
                                .font(.title3)
                                .bold()
                            
                            // Bar
                            GeometryReader { geometry in
                                Rectangle()
                                    .fill(Color.blue.opacity(0.3))
                                    .frame(width: CGFloat(count) / CGFloat(database.stats.total) * geometry.size.width)
                            }
                            .frame(width: 200, height: 20)
                        }
                        .padding()
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.system(size: 32, weight: .bold))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}
```

### 8. Create Policy View

Create `dashboard/Sources/PolicyView.swift`:

```swift
//
// PolicyView.swift
// AIFWDashboard
//

import SwiftUI

struct PolicyView: View {
    @State private var policyText: String = ""
    
    var body: some View {
        VStack {
            Text("Policy Configuration")
                .font(.title)
                .bold()
                .padding()
            
            TextEditor(text: $policyText)
                .font(.system(.body, design: .monospaced))
                .padding()
            
            HStack {
                Button("Load Policy") {
                    loadPolicy()
                }
                
                Button("Save Policy") {
                    savePolicy()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .onAppear {
            loadPolicy()
        }
    }
    
    private func loadPolicy() {
        let path = NSHomeDirectory() + "/.config/aifw/policy.json"
        if let content = try? String(contentsOfFile: path) {
            policyText = content
        }
    }
    
    private func savePolicy() {
        let path = NSHomeDirectory() + "/.config/aifw/policy.json"
        try? policyText.write(toFile: path, atomically: true, encoding: .utf8)
    }
}
```

## Build and Test

```bash
cd dashboard

# Build
swift build

# Run
swift run aifw-dashboard

# The dashboard window should appear showing:
# - Activity log (left sidebar)
# - Real-time updates every 2 seconds
# - Statistics view
# - Policy editor
```

## Create Pull Request

```bash
git add dashboard/
git commit -m "Phase 7: Implement SwiftUI Dashboard

Add optional monitoring dashboard:
- Real-time activity feed with auto-refresh
- Statistics with charts
- Policy configuration UI
- Search and filtering
- Clean SwiftUI interface

Key Features:
✅ Real-time activity monitoring
✅ Auto-refresh every 2 seconds
✅ Search and filter capabilities
✅ Statistics visualization
✅ Policy editor
✅ Native macOS UI

Usage: swift run aifw-dashboard"

git push -u origin phase-7-dashboard
gh pr create --title "Phase 7: Dashboard (Optional)" --base main
gh pr merge phase-7-dashboard --squash
```

## Success Criteria

✅ Dashboard displays activity  
✅ Auto-refresh works  
✅ Statistics calculated correctly  
✅ Policy editor functional  
✅ Search/filter work  
✅ Clean UI  

## Next Steps

**Project Complete!** All phases done. Consider:
- Installation script
- Distribution (DMG/pkg)
- Documentation polish
- v1.0 release

Congratulations! 🎉
