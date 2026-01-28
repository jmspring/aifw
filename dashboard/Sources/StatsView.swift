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
                                    .frame(width: CGFloat(count) / CGFloat(max(database.stats.total, 1)) * geometry.size.width)
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
