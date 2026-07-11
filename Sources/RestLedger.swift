import Foundation

struct DayRecord: Codable, Equatable {
    var day: String
    var activeSeconds = 0
    var restSeconds = 0
    var awaySeconds = 0
    var heldSeconds = 0
    var breaksCompleted = 0
    var breaksSkipped = 0
    var activeByHour = [Int](repeating: 0, count: 24)
    var skipsByHour = [Int](repeating: 0, count: 24)
    var longestStretchSeconds = 0
    var longestStretchStart: Date?
    var longestStretchEnd: Date?

    var restRatio: Double? {
        guard activeSeconds > 0 else { return nil }
        return Double(restSeconds) / Double(activeSeconds)
    }
}

final class RestLedger {

    struct Config {
        var restThreshold: TimeInterval = 60

        var maxAttributedGap: TimeInterval = 3600

        var calendar = Calendar.current
    }

    private struct Bucket {
        var active = 0.0
        var rest = 0.0
        var away = 0.0
        var held = 0.0
        var completed = 0
        var skipped = 0
        var activeByHour = [Double](repeating: 0, count: 24)
        var skipsByHour = [Int](repeating: 0, count: 24)
        var longestStretch = 0.0
        var stretchStart: Date?
        var stretchEnd: Date?
    }

    private var config: Config
    private var buckets: [String: Bucket] = [:]

    private var lastObserved: Date?
    private var previousIdle: TimeInterval = 0

    private var stretchStart: Date?
    private var stretchSeconds = 0.0
    private var stretchEnd: Date?

    init(config: Config = Config()) { self.config = config }

    func setRestThreshold(_ seconds: TimeInterval) { config.restThreshold = seconds }

    func dayKey(_ date: Date) -> String {
        let c = config.calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    func record(for day: String) -> DayRecord {
        guard let b = buckets[day] else { return DayRecord(day: day) }
        var r = DayRecord(day: day)
        r.activeSeconds = Int(b.active.rounded())
        r.restSeconds = Int(b.rest.rounded())
        r.awaySeconds = Int(b.away.rounded())
        r.heldSeconds = Int(b.held.rounded())
        r.breaksCompleted = b.completed
        r.breaksSkipped = b.skipped
        r.activeByHour = b.activeByHour.map { Int($0.rounded()) }
        r.skipsByHour = b.skipsByHour
        r.longestStretchSeconds = Int(b.longestStretch.rounded())
        r.longestStretchStart = b.stretchStart
        r.longestStretchEnd = b.stretchEnd
        return r
    }

    func snapshot(day: String, now: Date) -> DayRecord {
        var r = record(for: day)
        guard let start = stretchStart, let end = stretchEnd, dayKey(end) == day else { return r }
        let live = Int(stretchSeconds.rounded())
        guard live > r.longestStretchSeconds else { return r }
        r.longestStretchSeconds = live
        r.longestStretchStart = start
        r.longestStretchEnd = end
        return r
    }

    func allDays(asOf now: Date) -> [DayRecord] {
        let today = dayKey(now)
        return buckets.keys.sorted().map {
            $0 == today ? snapshot(day: $0, now: now) : record(for: $0)
        }
    }

    func forget() {
        buckets.removeAll()
        stretchStart = nil
        stretchSeconds = 0
        stretchEnd = nil
    }

    func load(_ records: [DayRecord]) {
        for r in records {
            var b = Bucket()
            b.active = Double(r.activeSeconds)
            b.rest = Double(r.restSeconds)
            b.away = Double(r.awaySeconds)
            b.held = Double(r.heldSeconds)
            b.completed = r.breaksCompleted
            b.skipped = r.breaksSkipped
            b.activeByHour = r.activeByHour.map(Double.init)
            b.skipsByHour = r.skipsByHour
            b.longestStretch = Double(r.longestStretchSeconds)
            b.stretchStart = r.longestStretchStart
            b.stretchEnd = r.longestStretchEnd
            buckets[r.day] = b
        }
    }

    func observe(now: Date, idleSeconds: TimeInterval, watching: Bool, suppressing: Bool) {
        defer { lastObserved = now; previousIdle = max(0, idleSeconds) }

        guard let last = lastObserved else { return }
        let elapsed = now.timeIntervalSince(last)
        guard elapsed > 0 else { return }

        guard elapsed <= config.maxAttributedGap else {
            endStretch()
            return
        }

        let idlePortion = watching ? 0 : min(max(0, idleSeconds), elapsed)
        let activePortion = elapsed - idlePortion
        let activeEnd = now.addingTimeInterval(-idlePortion)

        if activePortion > 0 {
            spread(from: last, to: activeEnd) { b, hour, seconds in
                b.active += seconds
                b.activeByHour[hour] += seconds
                if suppressing { b.held += seconds }
            }
            if stretchStart == nil { stretchStart = last }
            stretchSeconds += activePortion
            stretchEnd = activeEnd
        }

        if !watching, idleSeconds >= config.restThreshold, previousIdle < config.restThreshold {
            endStretch(overridingEnd: now.addingTimeInterval(-idleSeconds))
        }

        if idlePortion > 0, idleSeconds >= config.restThreshold {
            let backfill = previousIdle < config.restThreshold ? previousIdle : 0
            bucket(for: now) { $0.away += idlePortion + backfill }
        }
    }

    func breakBegan(now: Date) { resync(now: now) }

    func breakEnded(now: Date, restedSeconds: Int, completed: Bool) {
        bucket(for: now) { b in
            b.rest += Double(max(0, restedSeconds))
            if completed {
                b.completed += 1
            } else {
                b.skipped += 1
                b.skipsByHour[self.hour(now)] += 1
            }
        }
        if completed { endStretch(overridingEnd: now) }
        resync(now: now)
    }

    func resync(now: Date) {
        lastObserved = now
    }

    func stoppedWatching(now: Date) {
        endStretch()
        previousIdle = 0
        resync(now: now)
    }

    private func hour(_ date: Date) -> Int {
        min(23, max(0, config.calendar.component(.hour, from: date)))
    }

    private func bucket(for date: Date, _ body: (inout Bucket) -> Void) {
        let key = dayKey(date)
        var b = buckets[key] ?? Bucket()
        body(&b)
        buckets[key] = b
    }

    private func spread(from start: Date, to end: Date,
                        _ body: (inout Bucket, Int, Double) -> Void) {
        var cursor = start
        var guardCount = 0
        while cursor < end, guardCount < 64 {
            guardCount += 1
            let hourEnd = nextHour(after: cursor) ?? end
            let slice = min(end, hourEnd)
            let seconds = slice.timeIntervalSince(cursor)
            guard seconds > 0 else { break }
            let key = dayKey(cursor)
            let h = hour(cursor)
            var b = buckets[key] ?? Bucket()
            body(&b, h, seconds)
            buckets[key] = b
            cursor = slice
        }
    }

    private func nextHour(after date: Date) -> Date? {
        guard let start = config.calendar.dateInterval(of: .hour, for: date)?.end else { return nil }
        return start > date ? start : nil
    }

    private func endStretch(overridingEnd: Date? = nil) {
        defer { stretchStart = nil; stretchSeconds = 0; stretchEnd = nil }
        guard let start = stretchStart, stretchSeconds > 0 else { return }
        let end = overridingEnd ?? stretchEnd ?? start
        let finish = max(end, start)
        bucket(for: finish) { b in
            guard self.stretchSeconds > b.longestStretch else { return }
            b.longestStretch = self.stretchSeconds
            b.stretchStart = start
            b.stretchEnd = finish
        }
    }
}

final class RestHistory {
    static let retentionDays = 90

    private let url: URL

    init(url: URL) { self.url = url }

    static func defaultURL() -> URL {
        if let override = ProcessInfo.processInfo.environment["HEARTEYES_HISTORY"], !override.isEmpty {
            return URL(fileURLWithPath: override)
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HeartEyes", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("history.json")
    }

    func load() -> [DayRecord] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([DayRecord].self, from: data)) ?? []
    }

    func save(_ records: [DayRecord], asOf now: Date, calendar: Calendar = .current) {
        let cutoff = calendar.date(byAdding: .day, value: -Self.retentionDays, to: now) ?? now
        let cutoffKey = Self.key(cutoff, calendar)
        let kept = records.filter { $0.day >= cutoffKey }.sorted { $0.day < $1.day }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(kept) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func erase() { try? FileManager.default.removeItem(at: url) }

    private static func key(_ date: Date, _ calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

struct WeekSummary {
    let days: [DayRecord]

    let longestStretchSeconds: Int
    let longestStretchDay: String?
    let longestStretchStart: Date?

    let totalActiveSeconds: Int
    let totalRestSeconds: Int
    let totalHeldSeconds: Int

    let restRatio: Double?

    let breaksCompleted: Int
    let breaksSkipped: Int

    let skipsByHour: [Int]
    let skipCluster: (startHour: Int, count: Int)?

    var isEmpty: Bool { totalActiveSeconds == 0 && breaksCompleted == 0 && breaksSkipped == 0 }

    init(records: [DayRecord], asOf now: Date, calendar: Calendar = .current) {
        var byDay: [String: DayRecord] = [:]
        for r in records { byDay[r.day] = r }

        func key(_ date: Date) -> String {
            let c = calendar.dateComponents([.year, .month, .day], from: date)
            return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
        }

        let startOfToday = calendar.startOfDay(for: now)
        var window: [DayRecord] = []
        for offset in stride(from: -6, through: 0, by: 1) {
            let date = calendar.date(byAdding: .day, value: offset, to: startOfToday) ?? startOfToday
            let k = key(date)
            window.append(byDay[k] ?? DayRecord(day: k))
        }
        days = window

        var longest = 0, longestDay: String?, longestStart: Date?
        var active = 0, rest = 0, held = 0, completed = 0, skipped = 0
        var hours = [Int](repeating: 0, count: 24)
        for d in window {
            if d.longestStretchSeconds > longest {
                longest = d.longestStretchSeconds
                longestDay = d.day
                longestStart = d.longestStretchStart
            }
            active += d.activeSeconds
            rest += d.restSeconds
            held += d.heldSeconds
            completed += d.breaksCompleted
            skipped += d.breaksSkipped
            for h in 0..<24 where h < d.skipsByHour.count { hours[h] += d.skipsByHour[h] }
        }

        longestStretchSeconds = longest
        longestStretchDay = longestDay
        longestStretchStart = longestStart
        totalActiveSeconds = active
        totalRestSeconds = rest
        totalHeldSeconds = held
        restRatio = active > 0 ? Double(rest) / Double(active) : nil
        breaksCompleted = completed
        breaksSkipped = skipped
        skipsByHour = hours
        skipCluster = Self.cluster(in: hours, total: skipped)
    }

    private static func cluster(in hours: [Int], total: Int) -> (startHour: Int, count: Int)? {
        guard total >= 4 else { return nil }
        var best = (start: 0, count: -1)
        for start in 0...21 {
            let c = hours[start] + hours[start + 1] + hours[start + 2]
            if c > best.count { best = (start, c) }
        }
        guard best.count >= 3, Double(best.count) >= 0.5 * Double(total) else { return nil }
        return (best.start, best.count)
    }
}
