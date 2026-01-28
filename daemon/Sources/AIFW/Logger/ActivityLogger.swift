//
// ActivityLogger.swift
// AIFW
//
// SQLite-based activity logging
//

import Foundation
import SQLite3

/// Protocol for activity logging
public protocol ActivityLoggerProtocol {
    func log(
        eventType: String,
        processName: String?,
        pid: Int32,
        ppid: Int32,
        path: String?,
        command: String?,
        destination: String?,
        allowed: Bool,
        reason: String?
    )

    func getRecentActivity(limit: Int) -> [ActivityRecord]
    func getStatistics() -> (total: Int, allowed: Int, denied: Int)
    func clearAll()
}

/// SQLite-based activity logger
public class ActivityLogger: ActivityLoggerProtocol {
    private var db: OpaquePointer?
    private let dbPath: String

    public init(dbPath: String) {
        self.dbPath = NSString(string: dbPath).expandingTildeInPath

        // Ensure directory exists
        let directory = (self.dbPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(
            atPath: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // Open database
        if sqlite3_open(self.dbPath, &db) != SQLITE_OK {
            print("Error opening database at \(self.dbPath)")
        }

        createTables()
    }

    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }

    // MARK: - Database Setup

    private func createTables() {
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS activity (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            event_type TEXT NOT NULL,
            process_name TEXT,
            pid INTEGER NOT NULL,
            ppid INTEGER NOT NULL,
            path TEXT,
            command TEXT,
            destination TEXT,
            allowed INTEGER NOT NULL,
            reason TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );

        CREATE INDEX IF NOT EXISTS idx_timestamp ON activity(timestamp);
        CREATE INDEX IF NOT EXISTS idx_event_type ON activity(event_type);
        CREATE INDEX IF NOT EXISTS idx_allowed ON activity(allowed);
        CREATE INDEX IF NOT EXISTS idx_pid ON activity(pid);
        CREATE INDEX IF NOT EXISTS idx_created_at ON activity(created_at);
        """

        var error: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, createTableSQL, nil, nil, &error) != SQLITE_OK {
            if let error = error {
                let errorMessage = String(cString: error)
                print("Error creating tables: \(errorMessage)")
                sqlite3_free(error)
            }
        }
    }

    // MARK: - Logging

    public func log(
        eventType: String,
        processName: String?,
        pid: Int32,
        ppid: Int32,
        path: String?,
        command: String?,
        destination: String?,
        allowed: Bool,
        reason: String?
    ) {
        let insertSQL = """
        INSERT INTO activity
        (timestamp, event_type, process_name, pid, ppid, path, command, destination, allowed, reason)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil) == SQLITE_OK else {
            print("Error preparing insert statement")
            return
        }

        defer { sqlite3_finalize(stmt) }

        let timestamp = ISO8601DateFormatter().string(from: Date())

        sqlite3_bind_text(stmt, 1, timestamp, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(stmt, 2, eventType, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        if let processName = processName {
            sqlite3_bind_text(stmt, 3, processName, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else {
            sqlite3_bind_null(stmt, 3)
        }
        sqlite3_bind_int(stmt, 4, pid)
        sqlite3_bind_int(stmt, 5, ppid)
        if let path = path {
            sqlite3_bind_text(stmt, 6, path, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else {
            sqlite3_bind_null(stmt, 6)
        }
        if let command = command {
            sqlite3_bind_text(stmt, 7, command, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else {
            sqlite3_bind_null(stmt, 7)
        }
        if let destination = destination {
            sqlite3_bind_text(stmt, 8, destination, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else {
            sqlite3_bind_null(stmt, 8)
        }
        sqlite3_bind_int(stmt, 9, allowed ? 1 : 0)
        if let reason = reason {
            sqlite3_bind_text(stmt, 10, reason, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else {
            sqlite3_bind_null(stmt, 10)
        }

        if sqlite3_step(stmt) != SQLITE_DONE {
            print("Error inserting activity record")
        }
    }

    // MARK: - Querying

    public func getRecentActivity(limit: Int = 100) -> [ActivityRecord] {
        let querySQL = """
        SELECT id, timestamp, event_type, process_name, pid, ppid, path, command, destination, allowed, reason
        FROM activity
        ORDER BY id DESC
        LIMIT ?
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, querySQL, -1, &stmt, nil) == SQLITE_OK else {
            print("Error preparing query")
            return []
        }

        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int(stmt, 1, Int32(limit))

        var records: [ActivityRecord] = []

        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(stmt, 0))
            let timestamp = String(cString: sqlite3_column_text(stmt, 1))
            let eventType = String(cString: sqlite3_column_text(stmt, 2))

            let processName = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
            let pid = sqlite3_column_int(stmt, 4)
            let ppid = sqlite3_column_int(stmt, 5)
            let path = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
            let command = sqlite3_column_text(stmt, 7).map { String(cString: $0) }
            let destination = sqlite3_column_text(stmt, 8).map { String(cString: $0) }
            let allowed = sqlite3_column_int(stmt, 9) == 1
            let reason = sqlite3_column_text(stmt, 10).map { String(cString: $0) }

            let date = ISO8601DateFormatter().date(from: timestamp) ?? Date()

            records.append(ActivityRecord(
                id: id,
                timestamp: date,
                eventType: eventType,
                processName: processName,
                pid: pid,
                ppid: ppid,
                path: path,
                command: command,
                destination: destination,
                allowed: allowed,
                reason: reason
            ))
        }

        return records
    }

    public func getStatistics() -> (total: Int, allowed: Int, denied: Int) {
        let querySQL = """
        SELECT
            COUNT(*) as total,
            SUM(CASE WHEN allowed = 1 THEN 1 ELSE 0 END) as allowed_count,
            SUM(CASE WHEN allowed = 0 THEN 1 ELSE 0 END) as denied_count
        FROM activity
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, querySQL, -1, &stmt, nil) == SQLITE_OK else {
            print("Error preparing statistics query")
            return (0, 0, 0)
        }

        defer { sqlite3_finalize(stmt) }

        if sqlite3_step(stmt) == SQLITE_ROW {
            let total = Int(sqlite3_column_int(stmt, 0))
            let allowed = Int(sqlite3_column_int(stmt, 1))
            let denied = Int(sqlite3_column_int(stmt, 2))
            return (total, allowed, denied)
        }

        return (0, 0, 0)
    }

    public func clearAll() {
        let deleteSQL = "DELETE FROM activity"
        var error: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, deleteSQL, nil, nil, &error) != SQLITE_OK {
            if let error = error {
                print("Error clearing activity: \(String(cString: error))")
                sqlite3_free(error)
            }
        }
    }
}
