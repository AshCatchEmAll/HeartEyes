import Foundation

enum Keys {
    static let gifPath = "gifPath"
    static let gifLabel = "gifLabel"
    static let quotes = "quotes"
    static let breakVisual = "breakVisual"
    static let workMinutes = "workMinutes"
    static let breakSeconds = "breakSeconds"
    static let blinkMinutes = "blinkMinutes"
    static let blinkStyle = "blinkStyle"
    static let blinkScope = "blinkScope"
    static let blinkExplained = "blinkExplained"
    static let autoPause = "autoPause"
    static let naturalBreaks = "naturalBreaks"
    static let auditDay = "auditDay"
    static let heldToday = "heldToday"
    static let naturalToday = "naturalToday"
    static let shownToday = "shownToday"
    static let hardMode = "hardMode"
    static let routine = "routine"
    static let routineOn = "routineOn"
    static let routineExplained = "routineExplained"
}

enum Settings {
    static let workIntervals = [10, 20, 30, 45, 60]
    static let breakLengths = [10, 20, 30, 60]
    static let changedNotification = Notification.Name("com.aashish.hearteyes.settingsChanged")

    private static var defaults: UserDefaults { .standard }

    static var workMinutes: Int {
        get { let v = defaults.integer(forKey: Keys.workMinutes); return v == 0 ? 20 : v }
        set { defaults.set(newValue, forKey: Keys.workMinutes) }
    }
    static var breakSeconds: Int {
        get { let v = defaults.integer(forKey: Keys.breakSeconds); return v == 0 ? 20 : v }
        set { defaults.set(newValue, forKey: Keys.breakSeconds) }
    }
    static var gifPath: String? {
        get { defaults.string(forKey: Keys.gifPath) }
        set { defaults.set(newValue, forKey: Keys.gifPath) }
    }
    static var gifLabel: String? {
        get { defaults.string(forKey: Keys.gifLabel) }
        set { defaults.set(newValue, forKey: Keys.gifLabel) }
    }
    static var quotes: [String] {
        get { defaults.stringArray(forKey: Keys.quotes) ?? [] }
        set { defaults.set(newValue, forKey: Keys.quotes) }
    }
    static var breakVisualRaw: String {
        get { defaults.string(forKey: Keys.breakVisual) ?? "" }
        set { defaults.set(newValue, forKey: Keys.breakVisual) }
    }
    static var hardMode: Bool {
        get { defaults.bool(forKey: Keys.hardMode) }
        set { defaults.set(newValue, forKey: Keys.hardMode) }
    }
    static var routineOn: Bool {
        get { defaults.bool(forKey: Keys.routineOn) }
        set { defaults.set(newValue, forKey: Keys.routineOn) }
    }
    static var routine: Routine {
        get {
            defaults.data(forKey: Keys.routine)
                .flatMap { try? JSONDecoder().decode(Routine.self, from: $0) } ?? Routine()
        }
        set {
            defaults.set(try? JSONEncoder().encode(newValue), forKey: Keys.routine)
            pruneTaskGifs(keeping: newValue)
        }
    }

    static var breaksShownToday: Int {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        guard defaults.string(forKey: Keys.auditDay) == f.string(from: Date()) else { return 0 }
        return defaults.integer(forKey: Keys.shownToday)
    }

    static func appSupportDir() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("HeartEyes", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func taskGifDir() -> URL {
        let dir = appSupportDir().appendingPathComponent("tasks", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func pruneTaskGifs(keeping routine: Routine) {
        let dir = taskGifDir()
        let used = Set(routine.tasks.compactMap(\.gif).map { ($0 as NSString).lastPathComponent })
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        for url in files where !used.contains(url.lastPathComponent) {
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            guard Date().timeIntervalSince(modified) > 600 else { continue }
            try? FileManager.default.removeItem(at: url)
        }
    }

    static func announceChange(_ keys: [String], summary: String) {
        DistributedNotificationCenter.default().postNotificationName(
            changedNotification, object: nil,
            userInfo: ["keys": keys, "summary": summary], deliverImmediately: true)
    }
}
