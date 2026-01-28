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
