import Foundation

private let utc: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}()

private func at(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int = 0) -> Date {
    utc.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
}

private final class Sim {
    let ledger: RestLedger
    var now: Date
    var lastInput: Date

    init(start: Date, restThreshold: TimeInterval = 60) {
        var cfg = RestLedger.Config()
        cfg.restThreshold = restThreshold
        cfg.calendar = utc
        ledger = RestLedger(config: cfg)
        now = start
        lastInput = start
        ledger.resync(now: start)
    }

    private var idle: TimeInterval { now.timeIntervalSince(lastInput) }

    func type(_ seconds: Int) {
        for _ in 0..<seconds {
            now += 1
            lastInput = now
            ledger.observe(now: now, idleSeconds: 0, watching: false, suppressing: false)
        }
    }

    func away(_ seconds: Int) {
        for _ in 0..<seconds {
            now += 1
            ledger.observe(now: now, idleSeconds: idle, watching: false, suppressing: false)
        }
    }

    func held(_ seconds: Int) {
        for _ in 0..<seconds {
            now += 1
            ledger.observe(now: now, idleSeconds: idle, watching: true, suppressing: true)
        }
    }

    func watching(_ seconds: Int) {
        for _ in 0..<seconds {
            now += 1
            ledger.observe(now: now, idleSeconds: idle, watching: true, suppressing: false)
        }
    }

    func gap(_ seconds: Int) { now += TimeInterval(seconds) }

    func completeBreak(_ seconds: Int) {
        ledger.breakBegan(now: now)
        now += TimeInterval(seconds)
        ledger.breakEnded(now: now, restedSeconds: seconds, completed: true)
    }

    func skipBreak(after rested: Int) {
        ledger.breakBegan(now: now)
        now += TimeInterval(rested)
        ledger.breakEnded(now: now, restedSeconds: rested, completed: false)
    }

    func today() -> DayRecord { ledger.snapshot(day: ledger.dayKey(now), now: now) }
    func day(_ date: Date) -> DayRecord { ledger.snapshot(day: ledger.dayKey(date), now: now) }
}

private var failures = 0
private var checks = 0

private func expect(_ actual: Int, _ expected: Int, _ what: String) {
    checks += 1
    if actual != expected {
        failures += 1
        print("  ✗ \(what): expected \(expected), got \(actual)")
    }
}

private func expect(_ actual: Date?, _ expected: Date?, _ what: String) {
    checks += 1
    if actual != expected {
        failures += 1
        print("  ✗ \(what): expected \(expected.map(String.init(describing:)) ?? "nil"), "
            + "got \(actual.map(String.init(describing:)) ?? "nil")")
    }
}

private func test(_ name: String, _ body: () -> Void) {
    print("• \(name)")
    body()
}

@main
enum RestLedgerTests {
    static func main() {
        let nine = at(2026, 7, 10, 9)

        test("a morning of solid typing is exposure, and one unbroken stretch") {
            let s = Sim(start: nine)
            s.type(1200)
            let d = s.today()
            expect(d.activeSeconds, 1200, "active")
            expect(d.restSeconds, 0, "rest")
            expect(d.awaySeconds, 0, "away")
            expect(d.longestStretchSeconds, 1200, "longest stretch (in progress)")
            expect(d.activeByHour.reduce(0, +), 1200, "hour buckets sum to active")
            expect(d.activeByHour[9], 1200, "all of it lands in the 9am bucket")
        }

        test("a three-hour lunch is one rest, not nine breaks, and never counts as rest") {
            let s = Sim(start: nine)
            s.type(1200)
            s.away(10800)
            s.type(1200)
            let d = s.today()
            expect(d.activeSeconds, 2400, "lunch is not exposure")
            expect(d.awaySeconds, 10800, "the whole lunch, ramp-up included")
            expect(d.restSeconds, 0, "being away is not resting behind the overlay")
            expect(d.breaksCompleted, 0, "no break was ever shown")
            expect(d.longestStretchSeconds, 1200, "the lunch split the day into two stretches")
        }

        test("a break interrupting an idle span does not erase the span") {
            let s = Sim(start: nine)
            s.away(55)
            s.completeBreak(5)
            s.away(70)
            let d = s.today()
            expect(d.awaySeconds, 125, "130 seconds away, less the 5 spent behind the overlay")
            expect(d.activeSeconds, 0, "nobody was ever at the machine")
            expect(d.longestStretchSeconds, 0, "so there is no stretch to report")
        }

        test("a completed break ends the stretch") {
            let s = Sim(start: nine)
            s.type(1200)
            s.completeBreak(20)
            s.type(1200)
            let d = s.today()
            expect(d.activeSeconds, 2400, "active")
            expect(d.restSeconds, 20, "rest")
            expect(d.breaksCompleted, 1, "completed")
            expect(d.breaksSkipped, 0, "skipped")
            expect(d.longestStretchSeconds, 1200, "the break cut the stretch in half")
        }

        test("a skipped break does not end the stretch") {
            let s = Sim(start: nine)
            s.type(1200)
            s.skipBreak(after: 2)
            s.type(1200)
            let d = s.today()
            expect(d.activeSeconds, 2400, "active")
            expect(d.restSeconds, 2, "two seconds is what the eyes actually got")
            expect(d.breaksSkipped, 1, "skipped")
            expect(d.breaksCompleted, 0, "completed")
            expect(d.longestStretchSeconds, 2400, "the stretch ran straight through the skip")
            expect(d.skipsByHour[9], 1, "the skip is filed under the hour it happened")
        }

        test("a long call is exposure, is held, and is one very long stretch") {
            let s = Sim(start: nine)
            s.held(7200)
            let d = s.today()
            expect(d.activeSeconds, 7200, "staring at a call is exposure even with idle hands")
            expect(d.heldSeconds, 7200, "all of it suppressed a due break")
            expect(d.awaySeconds, 0, "a call is not being away")
            expect(d.longestStretchSeconds, 7200, "two hours, no rest")
        }

        test("held time is a subset of exposure, not an addition to it") {
            let s = Sim(start: nine)
            s.type(600)
            s.held(600)
            let d = s.today()
            expect(d.activeSeconds, 1200, "active counts each second once")
            expect(d.heldSeconds, 600, "only the call was held")
        }

        test("a call is exposure from its first minute, before anything is withheld") {
            let s = Sim(start: nine)
            s.watching(1200)
            s.held(1200)
            let d = s.today()
            expect(d.activeSeconds, 2400, "the whole call is exposure")
            expect(d.awaySeconds, 0, "none of it is being away")
            expect(d.heldSeconds, 1200, "but only the second half withheld a break")
            expect(d.longestStretchSeconds, 2400, "and it is all one unbroken stretch")
        }

        test("a closed lid invents nothing, and always breaks the stretch") {
            let s = Sim(start: nine)
            s.type(600)
            s.gap(8 * 3600)
            s.type(600)
            let d = s.today()
            expect(d.activeSeconds, 1199, "the eight hours are not exposure")
            expect(d.awaySeconds, 0, "nor are they away — we simply weren't watching")
            expect(d.longestStretchSeconds, 600, "the stretch cannot survive the gap")
        }

        test("sleeping and waking costs no real seconds, and still breaks the stretch") {
            let s = Sim(start: nine)
            s.type(600)
            s.ledger.stoppedWatching(now: s.now)
            s.gap(8 * 3600)
            s.ledger.resync(now: s.now)
            s.type(600)
            let d = s.today()
            expect(d.activeSeconds, 1200, "every real second of typing survives")
            expect(d.longestStretchSeconds, 600, "and the stretch still broke over the gap")
        }

        test("a pause is not a rest, so the stretch survives it") {
            let s = Sim(start: nine)
            s.type(600)
            s.ledger.resync(now: s.now)
            s.type(600)
            expect(s.today().longestStretchSeconds, 1200, "pausing the app rests nobody's eyes")
        }

        test("a session across midnight lands in both days") {
            let s = Sim(start: at(2026, 7, 10, 23, 50))
            s.type(1200)
            let first = s.day(at(2026, 7, 10, 23, 50))
            let second = s.day(at(2026, 7, 11, 0, 5))
            expect(first.activeSeconds, 600, "ten minutes before midnight")
            expect(second.activeSeconds, 600, "ten minutes after")
            expect(first.activeByHour[23], 600, "filed under 11pm")
            expect(second.activeByHour[0], 600, "filed under midnight")
        }

        test("a clock that steps backwards discards the impossible window") {
            let s = Sim(start: nine)
            s.type(10)
            s.ledger.observe(now: nine.addingTimeInterval(-100), idleSeconds: 0, watching: false, suppressing: false)
            expect(s.day(nine).activeSeconds, 10, "the negative window contributes nothing")
            s.ledger.observe(now: nine.addingTimeInterval(-99), idleSeconds: 0, watching: false, suppressing: false)
            expect(s.day(nine).activeSeconds, 11, "and it recovers rather than seizing up")
        }

        test("a disciplined hour: three intervals, three completed breaks") {
            let s = Sim(start: nine)
            for _ in 0..<3 { s.type(1200); s.completeBreak(20) }
            let d = s.today()
            expect(d.activeSeconds, 3600, "an hour of exposure")
            expect(d.restSeconds, 60, "a minute of it resting")
            expect(d.breaksCompleted, 3, "completed")
            expect(d.longestStretchSeconds, 1200, "never more than one interval unbroken")
            checks += 1
            if let r = d.restRatio, abs(r - 1.0 / 60.0) > 0.0001 {
                failures += 1
                print("  ✗ rest ratio: expected 1/60, got \(r)")
            }
        }

        test("an afternoon of skipping: the stretch grows, the skips cluster") {
            let s = Sim(start: at(2026, 7, 10, 15, 50))
            for _ in 0..<3 { s.type(1200); s.skipBreak(after: 1) }
            let d = s.today()
            expect(d.longestStretchSeconds, 3600, "an hour of unbroken screen despite three breaks")
            expect(d.breaksSkipped, 3, "skipped")
            expect(d.skipsByHour[16], 3, "all three in the 4pm hour")
            expect(d.skipsByHour[9], 0, "and none in the morning")
        }

        test("a day with no exposure has no ratio to report") {
            let s = Sim(start: nine)
            s.away(3600)
            let d = s.today()
            expect(d.activeSeconds, 0, "active")
            checks += 1
            if d.restRatio != nil {
                failures += 1
                print("  ✗ rest ratio: expected nil for a day with no exposure")
            }
        }

        test("history round-trips through JSON and prunes past ninety days") {
            let dir = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("hearteyes-test-\(ProcessInfo.processInfo.processIdentifier)")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: dir) }

            let store = RestHistory(url: dir.appendingPathComponent("history.json"))
            var fresh = DayRecord(day: "2026-07-10")
            fresh.activeSeconds = 3600
            fresh.longestStretchSeconds = 1200
            fresh.longestStretchStart = nine
            let stale = DayRecord(day: "2020-01-01")

            store.save([fresh, stale], asOf: at(2026, 7, 10, 12), calendar: utc)
            let back = store.load()
            expect(back.count, 1, "the 2020 record is past retention")
            expect(back.first?.activeSeconds ?? -1, 3600, "active survives the round trip")
            expect(back.first?.longestStretchStart, nine, "and so does the timestamp")

            store.erase()
            expect(store.load().count, 0, "erase leaves nothing behind")
        }

        func dayRecord(_ day: String, active: Int = 0, rest: Int = 0, held: Int = 0,
                       completed: Int = 0, skipped: Int = 0, longest: Int = 0,
                       skipsByHour: [Int]? = nil) -> DayRecord {
            var r = DayRecord(day: day)
            r.activeSeconds = active; r.restSeconds = rest; r.heldSeconds = held
            r.breaksCompleted = completed; r.breaksSkipped = skipped
            r.longestStretchSeconds = longest
            if let s = skipsByHour { r.skipsByHour = s }
            return r
        }

        let asOf = at(2026, 7, 10, 12)

        test("the week is always exactly seven days, oldest first, zero-filled") {
            let w = WeekSummary(records: [dayRecord("2026-07-08", active: 100)], asOf: asOf, calendar: utc)
            expect(w.days.count, 7, "seven bars, always")
            checks += 1
            if w.days.first?.day != "2026-07-04" || w.days.last?.day != "2026-07-10" {
                failures += 1
                print("  ✗ window runs 07-04…07-10, got \(w.days.first?.day ?? "?")…\(w.days.last?.day ?? "?")")
            }
            expect(w.days[4].activeSeconds, 100, "the one real day lands in its slot")
            expect(w.days[6].activeSeconds, 0, "and today, with no record, is a real zero")
        }

        test("a day older than seven days ago is not in the week") {
            let w = WeekSummary(records: [dayRecord("2026-07-01", active: 9999)], asOf: asOf, calendar: utc)
            expect(w.totalActiveSeconds, 0, "the 1st is outside a window ending on the 10th")
            checks += 1
            if !w.isEmpty { failures += 1; print("  ✗ a week with only stale data should read empty") }
        }

        test("the headline is the single worst stretch of the week, and the day it fell on") {
            let w = WeekSummary(records: [
                dayRecord("2026-07-06", longest: 1800),
                dayRecord("2026-07-09", longest: 8100),
                dayRecord("2026-07-10", longest: 3600),
            ], asOf: asOf, calendar: utc)
            expect(w.longestStretchSeconds, 8100, "the peak, not the sum and not today's")
            checks += 1
            if w.longestStretchDay != "2026-07-09" {
                failures += 1; print("  ✗ wrong day for the peak: \(w.longestStretchDay ?? "nil")")
            }
        }

        test("rest ratio is the week's rest over the week's exposure, not an average of ratios") {
            let w = WeekSummary(records: [
                dayRecord("2026-07-09", active: 3000, rest: 60),
                dayRecord("2026-07-10", active: 1000, rest: 40),
            ], asOf: asOf, calendar: utc)
            expect(w.totalActiveSeconds, 4000, "exposure sums")
            expect(w.totalRestSeconds, 100, "rest sums")
            checks += 1
            if let r = w.restRatio, abs(r - 100.0 / 4000.0) > 0.0001 {
                failures += 1; print("  ✗ pooled ratio expected 0.025, got \(r)")
            }
        }

        test("a week with no exposure has no ratio, not a zero") {
            let w = WeekSummary(records: [dayRecord("2026-07-10", skipped: 0)], asOf: asOf, calendar: utc)
            checks += 1
            if w.restRatio != nil { failures += 1; print("  ✗ empty week should have nil ratio") }
        }

        test("skips that cluster in an afternoon are reported as a band") {
            var pm = [Int](repeating: 0, count: 24)
            pm[16] = 3; pm[17] = 2
            var am = [Int](repeating: 0, count: 24)
            am[9] = 1
            let w = WeekSummary(records: [
                dayRecord("2026-07-09", skipped: 5, skipsByHour: pm),
                dayRecord("2026-07-10", skipped: 1, skipsByHour: am),
            ], asOf: asOf, calendar: utc)
            expect(w.breaksSkipped, 6, "six skips in all")
            checks += 1
            if let c = w.skipCluster, c.startHour == 15 || c.startHour == 16 {
            } else {
                failures += 1
                print("  ✗ expected an afternoon cluster, got \(String(describing: w.skipCluster))")
            }
        }

        test("a scatter of one-off skips is not dressed up as a pattern") {
            var spread = [Int](repeating: 0, count: 24)
            spread[9] = 1; spread[13] = 1; spread[16] = 1; spread[20] = 1
            let w = WeekSummary(records: [dayRecord("2026-07-10", skipped: 4, skipsByHour: spread)],
                                asOf: asOf, calendar: utc)
            checks += 1
            if w.skipCluster != nil {
                failures += 1; print("  ✗ four skips spread across the day is not a cluster")
            }
        }

        print("")
        if failures == 0 {
            print("✓ \(checks) checks passed")
        } else {
            print("✗ \(failures) of \(checks) checks failed")
            exit(1)
        }
    }
}
