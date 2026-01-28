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
                        Text("- \(processName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text("- PID \(activity.pid)")
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
