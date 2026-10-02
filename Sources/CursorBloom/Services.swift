import Foundation
import SQLite3

struct CursorCredentials {
    var token: String
    var accountLabel: String?
}

enum CredentialStore {
    static func load() throws -> CursorCredentials {
        let path = (NSHomeDirectory() as NSString).appendingPathComponent(
            "Library/Application Support/Cursor/User/globalStorage/state.vscdb"
        )
        guard FileManager.default.fileExists(atPath: path) else {
            throw UsageError.cursorNotInstalled
        }

        var db: OpaquePointer?
        let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let uri = "file://\(encoded)?mode=ro&immutable=1"
        guard sqlite3_open_v2(uri, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK, let db else {
            throw UsageError.databaseUnreadable
        }
        defer { sqlite3_close(db) }

        guard let token = value(in: db, key: "cursorAuth/accessToken"), token.isEmpty == false else {
            throw UsageError.signedOut
        }
        let email = value(in: db, key: "cursorAuth/cachedEmail")
        return CursorCredentials(token: token, accountLabel: UsageSnapshot.soften(email: email))
    }

    private static func value(in db: OpaquePointer, key: String) -> String? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT value FROM ItemTable WHERE key = ? LIMIT 1", -1, &statement, nil) == SQLITE_OK,
              let statement else {
            return nil
        }
        defer { sqlite3_finalize(statement) }

        let bound = key.withCString { pointer -> Bool in
            sqlite3_bind_text(statement, 1, pointer, -1, SQLITE_TRANSIENT) == SQLITE_OK
        }
        guard bound, sqlite3_step(statement) == SQLITE_ROW else { return nil }
        guard let raw = sqlite3_column_text(statement, 0) else { return nil }
        return String(cString: raw)
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum UsageClient {
    private static let base = URL(string: "https://api2.cursor.sh")!

    static func fetch(credentials: CursorCredentials) async throws -> UsageSnapshot {
        async let period = post(path: "/aiserver.v1.DashboardService/GetCurrentPeriodUsage", token: credentials.token)
        async let plan = post(path: "/aiserver.v1.DashboardService/GetPlanInfo", token: credentials.token)
        let (periodJSON, planJSON) = try await (period, plan)
        var eventsBody: [String: Any] = [:]
        if let start = periodJSON["billingCycleStart"] { eventsBody["startDate"] = start }
        if let end = periodJSON["billingCycleEnd"] { eventsBody["endDate"] = end }
        let eventsJSON = try await post(
            path: "/aiserver.v1.DashboardService/GetAggregatedUsageEvents",
            token: credentials.token,
            body: eventsBody
        )
        return try UsageParser.snapshot(
            period: periodJSON,
            plan: planJSON,
            events: eventsJSON,
            accountLabel: credentials.accountLabel
        )
    }

    private static func post(path: String, token: String, body: [String: Any] = [:]) async throws -> [String: Any] {
        guard let url = URL(string: path, relativeTo: base)?.absoluteURL else {
            throw UsageError.badResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw UsageError.network
        }

        if let http = response as? HTTPURLResponse, http.statusCode == 401 || http.statusCode == 403 {
            throw UsageError.unauthorized
        }
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw UsageError.badResponse
        }
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let json = object as? [String: Any] else {
            throw UsageError.badResponse
        }
        return json
    }
}
