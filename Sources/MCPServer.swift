import Foundation

enum MCPServer {
    private static let versions = ["2024-11-05", "2025-03-26", "2025-06-18"]
    private static let maxTasks = 24
    private static let taskSeconds = 20...3600
    private static let maxWords = 200

    private static let instructions = """
        HeartEyes is a macOS menu-bar app for the 20-20-20 rule: every work interval it covers the \
        screen for a short eye break. These tools read and change its settings; a change applies to \
        the running app at once and the user is told about it in the menu bar. A routine gives each \
        break something to do: it is N breaks long and then starts over; tasks are placed on it — \
        taking turns over whatever breaks are left, every Nth break, or on specific break numbers. \
        Specific numbers beat patterns and rarer patterns beat commoner ones; breaks with no task stay \
        a plain eye rest. Each task can carry its own length, a short line to show, and a GIF link. \
        Keep tasks short — most under a minute — and only schedule what the user asked for. Hard mode \
        is deliberately not exposed. read_reflection shares the user's weekly rest numbers with you; \
        use it only when they ask about their week.
        """

    static func run() -> Never {
        while let line = readLine() {
            guard let data = line.data(using: .utf8), !data.isEmpty,
                  let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            handle(message)
        }
        exit(0)
    }

    private static func handle(_ message: [String: Any]) {
        let id = message["id"].flatMap { $0 is NSNull ? nil : $0 }
        guard let method = message["method"] as? String else { return }
        let params = message["params"] as? [String: Any] ?? [:]

        switch method {
        case "initialize":
            let asked = params["protocolVersion"] as? String ?? ""
            reply(id, result: [
                "protocolVersion": versions.contains(asked) ? asked : versions.last!,
                "capabilities": ["tools": [String: Any]()],
                "serverInfo": ["name": "hearteyes",
                               "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"],
                "instructions": instructions,
            ])
        case "ping":
            reply(id, result: [:])
        case "tools/list":
            reply(id, result: ["tools": tools])
        case "tools/call":
            guard let name = params["name"] as? String else {
                fail(id, code: -32602, "Missing tool name"); return
            }
            let args = params["arguments"] as? [String: Any] ?? [:]
            switch call(name, args) {
            case .success(let text):
                reply(id, result: ["content": [["type": "text", "text": text]], "isError": false])
            case .failure(let why):
                switch why {
                case .unknownTool:
                    fail(id, code: -32602, "Unknown tool: \(name)")
                case .invalid(let text):
                    reply(id, result: ["content": [["type": "text", "text": text]], "isError": true])
                }
            }
        default:
            if id != nil, !method.hasPrefix("notifications/") { fail(id, code: -32601, "Method not found: \(method)") }
        }
    }

    private static func reply(_ id: Any?, result: [String: Any]) {
        send(["jsonrpc": "2.0", "id": id ?? NSNull(), "result": result])
    }

    private static func fail(_ id: Any?, code: Int, _ text: String) {
        send(["jsonrpc": "2.0", "id": id ?? NSNull(), "error": ["code": code, "message": text]])
    }

    private static func send(_ object: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: object) else { return }
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }

    private enum CallError: Error {
        case unknownTool
        case invalid(String)
    }

    private struct Problem: Error { let text: String }

    private static let placementSchema: [String: Any] = [
        "type": "object",
        "description": "Where the task lands in the routine. Omit it for “takes turns”.",
        "properties": [
            "kind": ["type": "string", "enum": ["turns", "every", "on"],
                     "description": "turns = shares the breaks nobody else claimed, in list order; every = every Nth break; on = specific break numbers."],
            "n": ["type": "integer", "minimum": 2, "description": "For every: 3 means breaks 3, 6, 9…"],
            "breaks": ["type": "array", "items": ["type": "integer", "minimum": 1],
                       "description": "For on: break numbers from 1 to the routine's length."],
        ],
        "required": ["kind"],
    ]

    private static let taskSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "name": ["type": "string", "maxLength": 60, "description": "Shown as the break's headline, e.g. “10 push-ups”."],
            "seconds": ["type": "integer", "minimum": taskSeconds.lowerBound, "maximum": taskSeconds.upperBound,
                        "description": "How long the break lasts. 45 suits a quick set; 900 is a walk."],
            "placement": placementSchema,
            "line": ["type": "string", "maxLength": 160, "description": "An optional line shown with the task, in the user's voice."],
            "gif_url": ["type": "string", "description": "Optional Giphy, Tenor or direct .gif link to show on this break instead of the usual one."],
        ],
        "required": ["name", "seconds"],
    ]

    private static let tools: [[String: Any]] = [
        [
            "name": "get_settings",
            "description": "Read HeartEyes' current settings: work interval, break length, break screen, the routine and its full plan, and what's up next.",
            "inputSchema": ["type": "object", "properties": [String: Any]()],
        ],
        [
            "name": "set_routine",
            "description": "Replace the break routine and turn it on. A routine is `length` breaks long and then starts over; each task is placed on it. Returns the resulting break-by-break plan — show it to the user.",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "length": ["type": "integer", "minimum": Routine.minLength, "maximum": Routine.maxLength,
                               "description": "How many breaks before the routine starts over. 12 at a 30-min interval is a six-hour day."],
                    "tasks": ["type": "array", "maxItems": maxTasks, "items": taskSchema],
                    "enabled": ["type": "boolean", "description": "Default true."],
                ],
                "required": ["length", "tasks"],
            ],
        ],
        [
            "name": "set_break_screen",
            "description": "Change what every plain break shows: a GIF from a link, or a list of the user's own lines (one is shown per break). Pass mode to switch between the two without replacing content.",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "gif_url": ["type": "string", "description": "A Giphy, Tenor or direct .gif link."],
                    "words": ["type": "array", "items": ["type": "string", "maxLength": 300], "maxItems": maxWords,
                              "description": "Lines in the user's voice; one is shown per break."],
                    "mode": ["type": "string", "enum": ["gif", "words"]],
                ],
            ],
        ],
        [
            "name": "set_interval",
            "description": "Set the work interval between breaks, in minutes.",
            "inputSchema": ["type": "object",
                            "properties": ["minutes": ["type": "integer", "enum": Settings.workIntervals]],
                            "required": ["minutes"]],
        ],
        [
            "name": "set_break_length",
            "description": "Set how long a plain eye break lasts, in seconds.",
            "inputSchema": ["type": "object",
                            "properties": ["seconds": ["type": "integer", "enum": Settings.breakLengths]],
                            "required": ["seconds"]],
        ],
        [
            "name": "read_reflection",
            "description": "The user's week of rest, as HeartEyes' “This week…” panel shows it: longest stretch without a break, minutes of break per hour at the screen, breaks taken and skipped, time held during calls, and which break gets skipped most. Computed on the Mac from a local ledger; calling this shares those numbers with you.",
            "inputSchema": ["type": "object", "properties": [String: Any]()],
        ],
    ]

    private static func call(_ name: String, _ args: [String: Any]) -> Result<String, CallError> {
        do {
            switch name {
            case "get_settings":     return .success(try getSettings())
            case "set_routine":      return .success(try setRoutine(args))
            case "set_break_screen": return .success(try setBreakScreen(args))
            case "set_interval":     return .success(try setInterval(args))
            case "set_break_length": return .success(try setBreakLength(args))
            case "read_reflection":  return .success(try readReflection())
            default:                 return .failure(.unknownTool)
            }
        } catch let error as CallError {
            return .failure(error)
        } catch {
            return .failure(.invalid(error.localizedDescription))
        }
    }

    private static func getSettings() throws -> String {
        let routine = Settings.routine
        let shown = Settings.breaksShownToday
        var out: [String: Any] = [
            "work_interval_minutes": Settings.workMinutes,
            "break_length_seconds": Settings.breakSeconds,
            "hard_mode": Settings.hardMode,
            "break_screen": [
                "mode": Settings.breakVisualRaw == "quote" ? "words" : "gif",
                "gif": Settings.gifLabel ?? Settings.gifPath.map { ($0 as NSString).lastPathComponent } ?? "the default heart",
                "words": Settings.quotes,
            ],
            "routine": routineJSON(routine, enabled: Settings.routineOn),
            "breaks_shown_today": shown,
        ]
        if Settings.routineOn, !routine.isEmpty {
            out["up_next"] = routine.upcoming(3, after: shown).map { $0?.name ?? "eye rest" }
        }
        return json(out)
    }

    private static func routineJSON(_ r: Routine, enabled: Bool) -> [String: Any] {
        [
            "enabled": enabled,
            "length": r.length,
            "tasks": r.tasks.map { t -> [String: Any] in
                var task: [String: Any] = ["name": t.name, "seconds": t.seconds, "placement": placementJSON(t.placement)]
                if let line = t.line { task["line"] = line }
                if let gif = t.gif { task["gif"] = (gif as NSString).lastPathComponent }
                return task
            },
            "plan": plan(r),
        ]
    }

    private static func placementJSON(_ p: Placement) -> [String: Any] {
        switch p {
        case .turns:          return ["kind": "turns"]
        case .every(let n):   return ["kind": "every", "n": n]
        case .on(let breaks): return ["kind": "on", "breaks": breaks]
        }
    }

    private static func plan(_ r: Routine) -> [String] {
        r.slots().enumerated().map { "\($0 + 1) · \($1?.name ?? "eye rest")" }
    }

    private static func setRoutine(_ args: [String: Any]) throws -> String {
        guard let length = args["length"] as? Int, Routine.minLength...Routine.maxLength ~= length else {
            throw CallError.invalid("length must be \(Routine.minLength)–\(Routine.maxLength) breaks.")
        }
        guard let rawTasks = args["tasks"] as? [[String: Any]] else { throw CallError.invalid("tasks must be an array.") }
        guard rawTasks.count <= maxTasks else { throw CallError.invalid("At most \(maxTasks) tasks.") }

        var tasks: [Activity] = []
        var warnings: [String] = []
        for (i, raw) in rawTasks.enumerated() {
            let name = (raw["name"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, name.count <= 60 else { throw CallError.invalid("Task \(i + 1): name must be 1–60 characters.") }
            guard let seconds = raw["seconds"] as? Int, taskSeconds ~= seconds else {
                throw CallError.invalid("Task \(i + 1) (\(name)): seconds must be \(taskSeconds.lowerBound)–\(taskSeconds.upperBound).")
            }
            var task = Activity(name: name, seconds: seconds)
            if let p = raw["placement"] as? [String: Any] {
                switch p["kind"] as? String ?? "turns" {
                case "turns":
                    task.placement = .turns
                case "every":
                    guard let n = p["n"] as? Int, 2...length ~= n else {
                        throw CallError.invalid("Task \(i + 1) (\(name)): every needs n between 2 and \(length).")
                    }
                    task.placement = .every(n)
                case "on":
                    let breaks = (p["breaks"] as? [Int] ?? []).filter { 1...length ~= $0 }
                    guard !breaks.isEmpty else {
                        throw CallError.invalid("Task \(i + 1) (\(name)): on needs break numbers between 1 and \(length).")
                    }
                    task.placement = .on(Array(Set(breaks)).sorted())
                default:
                    throw CallError.invalid("Task \(i + 1) (\(name)): placement kind must be turns, every or on.")
                }
            }
            if let line = (raw["line"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !line.isEmpty {
                task.line = String(line.prefix(160))
            }
            if let link = raw["gif_url"] as? String, !link.isEmpty {
                switch fetchGif(link, into: Settings.taskGifDir(), prune: false) {
                case .success(let url): task.gif = url.path
                case .failure(let why): warnings.append("\(name): GIF not used — \(why.text)")
                }
            }
            tasks.append(task)
        }

        let routine = Routine(length: length, tasks: tasks)
        let enabled = args["enabled"] as? Bool ?? true
        Settings.routine = routine
        Settings.routineOn = enabled
        let next = routine.upcoming(1, after: Settings.breaksShownToday).first.flatMap { $0 }?.name
        Settings.announceChange([Keys.routine, Keys.routineOn],
                                summary: enabled
                                    ? "Your agent set up a new routine" + (next.map { " — next: \($0)" } ?? "") + "."
                                    : "Your agent saved a routine, switched off.")

        var lines = ["Saved a \(length)-break routine, \(enabled ? "on" : "off")."]
        lines += plan(routine)
        if !warnings.isEmpty { lines += [""] + warnings }
        return lines.joined(separator: "\n")
    }

    private static func setBreakScreen(_ args: [String: Any]) throws -> String {
        var changed: [String] = []
        var notes: [String] = []
        var mode = args["mode"] as? String

        if let link = args["gif_url"] as? String, !link.isEmpty {
            switch fetchGif(link, into: Settings.appSupportDir(), prune: true) {
            case .success(let url):
                Settings.gifPath = url.path
                Settings.gifLabel = GifLoader.normalized(link)?.host ?? "Downloaded GIF"
                changed += [Keys.gifPath, Keys.gifLabel]
                notes.append("GIF set from \(Settings.gifLabel!).")
                if mode == nil { mode = "gif" }
            case .failure(let why):
                throw CallError.invalid("Couldn't use that GIF link — \(why.text)")
            }
        }
        if let words = args["words"] as? [String] {
            let kept = words.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }.map { String($0.prefix(300)) }.prefix(maxWords)
            Settings.quotes = Array(kept)
            changed.append(Keys.quotes)
            notes.append("\(kept.count) line\(kept.count == 1 ? "" : "s") saved.")
            if mode == nil { mode = "words" }
        }
        if let mode {
            guard ["gif", "words"].contains(mode) else { throw CallError.invalid("mode must be gif or words.") }
            Settings.breakVisualRaw = mode == "words" ? "quote" : "gif"
            changed.append(Keys.breakVisual)
            notes.append("Breaks now show \(mode == "words" ? "your words" : "a GIF").")
        }
        guard !changed.isEmpty else { throw CallError.invalid("Pass gif_url, words, or mode.") }
        Settings.announceChange(changed, summary: "Your agent updated the break screen.")
        return notes.joined(separator: " ")
    }

    private static func setInterval(_ args: [String: Any]) throws -> String {
        guard let minutes = args["minutes"] as? Int, Settings.workIntervals.contains(minutes) else {
            throw CallError.invalid("minutes must be one of \(Settings.workIntervals).")
        }
        Settings.workMinutes = minutes
        Settings.announceChange([Keys.workMinutes], summary: "Your agent set the work interval to \(minutes) min.")
        return "Work interval is now \(minutes) minutes; the countdown restarts from there."
    }

    private static func setBreakLength(_ args: [String: Any]) throws -> String {
        guard let seconds = args["seconds"] as? Int, Settings.breakLengths.contains(seconds) else {
            throw CallError.invalid("seconds must be one of \(Settings.breakLengths).")
        }
        Settings.breakSeconds = seconds
        Settings.announceChange([Keys.breakSeconds], summary: "Your agent set breaks to \(seconds) seconds.")
        return "Plain breaks now last \(seconds) seconds. Routine tasks keep their own lengths."
    }

    private static func readReflection() throws -> String {
        let now = Date()
        let week = WeekSummary(records: RestHistory(url: RestHistory.defaultURL()).load(), asOf: now)
        var out: [String: Any] = [
            "as_of": ISO8601DateFormatter().string(from: now),
            "note": "Today's numbers are as of the app's last save, up to five minutes ago.",
            "longest_stretch_without_a_break_seconds": week.longestStretchSeconds,
            "break_seconds_per_hour_at_screen": week.restSecondsPerHour ?? 0,
            "breaks_taken": week.breaksCompleted,
            "breaks_skipped": week.breaksSkipped,
            "held_during_calls_seconds": week.totalHeldSeconds,
            "days": week.days.map { d -> [String: Any] in
                [
                    "day": d.day,
                    "screen_seconds": d.activeSeconds,
                    "break_seconds": d.restSeconds,
                    "breaks_taken": d.breaksCompleted,
                    "breaks_skipped": d.breaksSkipped,
                    "longest_stretch_seconds": d.longestStretchSeconds,
                ]
            },
        ]
        if let day = week.longestStretchDay { out["longest_stretch_day"] = day }
        if let start = week.longestStretchStart { out["longest_stretch_started"] = ISO8601DateFormatter().string(from: start) }
        if let c = week.skipCluster { out["skips_cluster_between_hours"] = [c.startHour, c.startHour + 3] }
        if let worst = week.mostSkipped { out["most_skipped_task"] = ["name": worst.name, "skips": worst.count] }
        return json(out)
    }

    private static func fetchGif(_ raw: String, into dir: URL, prune: Bool) -> Result<URL, Problem> {
        guard let url = GifLoader.normalized(raw) else { return .failure(Problem(text: "that doesn't look like a link")) }
        let done = DispatchSemaphore(value: 0)
        var outcome: Result<Data, GifLoader.Failure>?
        GifLoader.fetch(url) { outcome = $0; done.signal() }
        guard done.wait(timeout: .now() + 45) == .success, let outcome else { return .failure(Problem(text: "timed out")) }
        switch outcome {
        case .failure(let why):
            return .failure(Problem(text: why.message))
        case .success(let data):
            do { return .success(try GifLoader.save(data, in: dir, prune: prune)) }
            catch { return .failure(Problem(text: "couldn't save the image")) }
        }
    }

    private static func json(_ object: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }
}
