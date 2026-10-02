import Foundation

enum UsageAlert: Equatable {
    case aheadOfPace
    case onTrack
    case slightlyAhead
    case slowDown
    case conserve
    case critical
    case resetSoon

    /// Compares quota used with how far the billing cycle has gone.
    /// A ratio under 1 means more remains than a steady pace would leave.
    static func level(usedPercent: Double, cycleFraction: Double) -> UsageAlert {
        let used = max(usedPercent, 0) / 100
        let remaining = max(0, 1 - used)
        if used >= 1 || remaining <= 0.05 {
            return .resetSoon
        }
        let elapsed = min(max(cycleFraction, 0.02), 1)
        let ratio = used / elapsed
        if ratio < 0.75 { return .aheadOfPace }
        if ratio <= 1.10 { return .onTrack }
        if ratio <= 1.30 { return .slightlyAhead }
        if ratio <= 1.60 { return .slowDown }
        if ratio <= 2.00 { return .conserve }
        return .critical
    }

    var title: String {
        switch self {
        case .aheadOfPace: return "Ahead of pace"
        case .onTrack: return "On track"
        case .slightlyAhead: return "Slightly ahead"
        case .slowDown: return "Slow down"
        case .conserve: return "Conserve"
        case .critical: return "Critical"
        case .resetSoon: return "Reset soon"
        }
    }

    var tone: AlertTone {
        switch self {
        case .aheadOfPace, .onTrack:
            return .info
        case .slightlyAhead:
            return .caution
        case .slowDown, .conserve:
            return .warning
        case .critical, .resetSoon:
            return .critical
        }
    }
}

enum AlertTone {
    case info
    case caution
    case warning
    case critical
}

enum UsageError: Error, LocalizedError {
    case cursorNotInstalled
    case databaseUnreadable
    case signedOut
    case unauthorized
    case badResponse
    case network

    var errorDescription: String? {
        switch self {
        case .cursorNotInstalled:
            return "Cursor is not installed on this Mac"
        case .databaseUnreadable:
            return "Could not read Cursor data"
        case .signedOut:
            return "Not signed in to Cursor"
        case .unauthorized:
            return "Session expired. Open Cursor, then refresh"
        case .badResponse:
            return "Cursor sent an incomplete response"
        case .network:
            return "Offline. Showing the last numbers"
        }
    }
}

struct UsageSnapshot: Codable, Equatable {
    var planName: String
    var price: String?
    var accountLabel: String?
    var totalPercent: Double
    var autoPercent: Double
    var apiPercent: Double
    var inputTokens: Double
    var outputTokens: Double
    var cacheTokens: Double
    var cycleStart: Date
    var cycleEnd: Date
    var fetchedAt: Date

    var remainingPercent: Double {
        max(0, 100 - totalPercent)
    }

    var cycleFraction: Double {
        let span = cycleEnd.timeIntervalSince(cycleStart)
        guard span > 0 else { return 0 }
        return min(max(Date().timeIntervalSince(cycleStart) / span, 0), 1)
    }

    var alert: UsageAlert {
        UsageAlert.level(usedPercent: totalPercent, cycleFraction: cycleFraction)
    }

    var resetLine: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.setLocalizedDateFormatFromTemplate("dMMM")
        let day = formatter.string(from: cycleEnd)
        let remaining = cycleEnd.timeIntervalSinceNow
        if remaining <= 0 {
            return "Reset is due"
        }
        let days = Int(remaining / 86_400)
        if days >= 1 {
            return "Resets \(day) · \(days) days left"
        }
        let hours = max(1, Int(remaining / 3_600))
        return "Resets \(day) · \(hours) hr left"
    }

    static func formatPercent(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded >= 10 || abs(rounded - rounded.rounded()) < 0.001 {
            return "\(Int(rounded.rounded()))%"
        }
        return String(format: "%.1f%%", rounded)
    }

    static func formatTokens(_ count: Double) -> String {
        let magnitude = abs(count)
        if magnitude >= 1_000_000 {
            return String(format: "%.1fM", count / 1_000_000)
        }
        if magnitude >= 1_000 {
            return String(format: "%.1fK", count / 1_000)
        }
        return String(format: "%.0f", count)
    }

    static func soften(email: String?) -> String? {
        guard let email, let at = email.firstIndex(of: "@"), at > email.startIndex else { return nil }
        let initial = email[email.startIndex]
        let domain = email[email.index(after: at)...]
        return "\(initial)···@\(domain)"
    }
}

enum UsageParser {
    static func snapshot(period: [String: Any], plan: [String: Any], events: [String: Any], accountLabel: String?) throws -> UsageSnapshot {
        guard let usage = period["planUsage"] as? [String: Any] else {
            throw UsageError.badResponse
        }
        let planInfo = plan["planInfo"] as? [String: Any] ?? [:]
        let planName = (planInfo["planName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let price = planInfo["price"] as? String
        let start = date(period["billingCycleStart"]) ?? Date()
        let end = date(period["billingCycleEnd"]) ?? date(planInfo["billingCycleEnd"]) ?? start

        return UsageSnapshot(
            planName: (planName?.isEmpty == false ? planName! : "Cursor"),
            price: price,
            accountLabel: accountLabel,
            totalPercent: number(usage["totalPercentUsed"]) ?? 0,
            autoPercent: number(usage["autoPercentUsed"]) ?? 0,
            apiPercent: number(usage["apiPercentUsed"]) ?? 0,
            inputTokens: number(events["totalInputTokens"]) ?? 0,
            outputTokens: number(events["totalOutputTokens"]) ?? 0,
            cacheTokens: (number(events["totalCacheWriteTokens"]) ?? 0) + (number(events["totalCacheReadTokens"]) ?? 0),
            cycleStart: start,
            cycleEnd: end,
            fetchedAt: Date()
        )
    }

    private static func number(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber:
            return number.doubleValue
        case let string as String:
            return Double(string)
        default:
            return nil
        }
    }

    private static func date(_ value: Any?) -> Date? {
        if let raw = number(value) {
            let seconds = raw > 10_000_000_000 ? raw / 1000 : raw
            return Date(timeIntervalSince1970: seconds)
        }
        if let string = value as? String {
            return ISO8601DateFormatter().date(from: string)
        }
        return nil
    }
}
