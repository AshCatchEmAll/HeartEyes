import Foundation

enum Placement: Codable, Equatable {
    case turns
    case every(Int)
    case on([Int])

    private enum Keys: String, CodingKey { case kind, every, breaks }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        switch try c.decode(String.self, forKey: .kind) {
        case "every": self = .every(try c.decode(Int.self, forKey: .every))
        case "on":    self = .on(try c.decode([Int].self, forKey: .breaks))
        default:      self = .turns
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        switch self {
        case .turns:          try c.encode("turns", forKey: .kind)
        case .every(let n):   try c.encode("every", forKey: .kind); try c.encode(n, forKey: .every)
        case .on(let breaks): try c.encode("on", forKey: .kind); try c.encode(breaks, forKey: .breaks)
        }
    }

    var every: Int? { if case .every(let n) = self { return n }; return nil }
    var breaks: [Int]? { if case .on(let b) = self { return b }; return nil }

    func label(length: Int) -> String {
        switch self {
        case .turns:          return "takes turns"
        case .every(let n):   return "every \(Routine.ordinal(n)) break"
        case .on(let breaks):
            let kept = breaks.filter { $0 >= 1 && $0 <= length }
            return kept.count == 1 ? "break \(kept[0])" : "breaks " + kept.map(String.init).joined(separator: ", ")
        }
    }
}

struct Activity: Codable, Equatable {
    var name: String
    var seconds: Int
    var placement: Placement = .turns
    var line: String?
    var gif: String?

    init(name: String, seconds: Int, placement: Placement = .turns, line: String? = nil, gif: String? = nil) {
        self.name = name
        self.seconds = seconds
        self.placement = placement
        self.line = line
        self.gif = gif
    }

    private enum Keys: String, CodingKey { case name, seconds, placement, line, gif }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        name = try c.decode(String.self, forKey: .name)
        seconds = try c.decode(Int.self, forKey: .seconds)
        placement = try c.decodeIfPresent(Placement.self, forKey: .placement) ?? .turns
        line = try c.decodeIfPresent(String.self, forKey: .line)
        gif = try c.decodeIfPresent(String.self, forKey: .gif)
    }
}

struct Routine: Codable, Equatable {
    static let minLength = 2
    static let maxLength = 48
    static let defaultLength = 12

    var length: Int = defaultLength
    var tasks: [Activity] = []

    init(length: Int = defaultLength, tasks: [Activity] = []) {
        self.length = max(Self.minLength, min(Self.maxLength, length))
        self.tasks = tasks
    }

    private enum Keys: String, CodingKey { case length, tasks, cycle, rules }
    private struct LegacyRule: Decodable { let every: Int; let activity: Activity }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        if let tasks = try c.decodeIfPresent([Activity].self, forKey: .tasks) {
            self.init(length: try c.decodeIfPresent(Int.self, forKey: .length) ?? Self.defaultLength, tasks: tasks)
            return
        }
        let cycle = try c.decodeIfPresent([Activity].self, forKey: .cycle) ?? []
        let rules = try c.decodeIfPresent([LegacyRule].self, forKey: .rules) ?? []
        var tasks = cycle
        for r in rules {
            var t = r.activity
            t.placement = .every(r.every)
            tasks.append(t)
        }
        self.init(length: max(Self.defaultLength, rules.map(\.every).max() ?? 0), tasks: tasks)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(length, forKey: .length)
        try c.encode(tasks, forKey: .tasks)
    }

    var isEmpty: Bool { tasks.isEmpty }
    var names: [String] { tasks.map(\.name) }

    func slots() -> [Activity?] {
        var out = [Activity?](repeating: nil, count: length)
        for s in 1...length {
            if let pinned = tasks.first(where: { $0.placement.breaks?.contains(s) == true }) {
                out[s - 1] = pinned
                continue
            }
            var best: (Activity, Int)?
            for t in tasks {
                guard let n = t.placement.every, n > 1, s % n == 0 else { continue }
                if best == nil || n > best!.1 { best = (t, n) }
            }
            out[s - 1] = best?.0
        }
        let turns = tasks.filter { $0.placement == .turns }
        guard !turns.isEmpty else { return out }
        var j = 0
        for s in out.indices where out[s] == nil {
            out[s] = turns[j % turns.count]
            j += 1
        }
        return out
    }

    func activity(forBreak n: Int) -> Activity? {
        guard n > 0 else { return nil }
        return slots()[(n - 1) % length]
    }

    func upcoming(_ count: Int, after shown: Int = 0) -> [Activity?] {
        (1...max(1, count)).map { activity(forBreak: shown + $0) }
    }

    static func cadence(breaks: Int, workMinutes: Int) -> String {
        let minutes = breaks * workMinutes
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "≈ \(m) min" }
        return m == 0 ? "≈ \(h) h" : "≈ \(h) h \(m) min"
    }

    static func ordinal(_ n: Int) -> String {
        let tens = n % 100, ones = n % 10
        if (11...13).contains(tens) { return "\(n)th" }
        switch ones {
        case 1:  return "\(n)st"
        case 2:  return "\(n)nd"
        case 3:  return "\(n)rd"
        default: return "\(n)th"
        }
    }

    static func parseBreaks(_ text: String, length: Int) -> [Int] {
        let numbers = text.split { !$0.isNumber }.compactMap { Int($0) }
        var seen = Set<Int>()
        return numbers.filter { $0 >= 1 && $0 <= length && seen.insert($0).inserted }.sorted()
    }

    static func duration(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds) s" }
        let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
        var parts: [String] = []
        if h > 0 { parts.append("\(h) hr") }
        if m > 0 { parts.append("\(m) min") }
        if s > 0 { parts.append("\(s) s") }
        return parts.joined(separator: " ")
    }

    static func durationLong(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds) seconds" }
        let h = seconds / 3600, m = (seconds % 3600) / 60
        var parts: [String] = []
        if h > 0 { parts.append(h == 1 ? "an hour" : "\(h) hours") }
        if m > 0 { parts.append(m == 1 ? "a minute" : "\(m) minutes") }
        return parts.joined(separator: " and ")
    }

    static let water = Activity(name: "Drink some water", seconds: 30, placement: .every(3))

    static let templates: [(name: String, routine: Routine)] = [
        ("Just add water", Routine(length: 12, tasks: [water])),
        ("Desk workout", Routine(length: 12, tasks: [
            Activity(name: "10 push-ups", seconds: 45, line: "Your body should support your ambitions."),
            Activity(name: "10 squats", seconds: 45),
            Activity(name: "Hold a plank", seconds: 45),
            water,
            Activity(name: "Take a walk", seconds: 15 * 60, placement: .on([12]),
                     line: "Leave the desk. It'll still be here."),
        ])),
        ("Stretch & sip", Routine(length: 12, tasks: [
            Activity(name: "Roll your shoulders", seconds: 30),
            Activity(name: "Stretch your neck", seconds: 30),
            Activity(name: "Stand up and reach", seconds: 30),
            water,
        ])),
    ]
}
