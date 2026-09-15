import Foundation

func expect(_ actual: [String], _ expected: [String], _ what: String) {
    checks += 1
    if actual != expected {
        failures += 1
        print("  ✗ \(what):\n      expected \(expected)\n      got      \(actual)")
    }
}

func expect(_ actual: String, _ expected: String, _ what: String) {
    checks += 1
    if actual != expected {
        failures += 1
        print("  ✗ \(what): expected \"\(expected)\", got \"\(actual)\"")
    }
}

enum RoutineTests {
    private static let pushUps = Activity(name: "10 push-ups", seconds: 45)
    private static let pullUps = Activity(name: "10 pull-ups", seconds: 45)
    private static let squats = Activity(name: "10 squats", seconds: 45)
    private static let water = Activity(name: "Drink water", seconds: 20, placement: .every(5))
    private static let walk = Activity(name: "Take a walk", seconds: 30 * 60, placement: .on([20]))

    private static func names(_ r: Routine) -> [String] { r.slots().map { $0?.name ?? "rest" } }

    static func run() {
        test("an empty routine leaves every break a plain eye rest") {
            expect(names(Routine(length: 4)), ["rest", "rest", "rest", "rest"], "nothing scheduled")
        }

        test("tasks that take turns share the breaks in order and wrap") {
            let r = Routine(length: 7, tasks: [pushUps, pullUps, squats])
            expect(names(r), ["10 push-ups", "10 pull-ups", "10 squats",
                              "10 push-ups", "10 pull-ups", "10 squats", "10 push-ups"], "three in rotation")
        }

        test("an every-Nth task alone leaves the other breaks plain") {
            let r = Routine(length: 6, tasks: [Activity(name: "Drink water", seconds: 20, placement: .every(3))])
            expect(names(r), ["rest", "rest", "Drink water", "rest", "rest", "Drink water"], "water every third")
        }

        test("a placed task interrupts the turns without skipping anyone") {
            let r = Routine(length: 8, tasks: [pushUps, pullUps, squats, water])
            expect(names(r), ["10 push-ups", "10 pull-ups", "10 squats", "10 push-ups", "Drink water",
                              "10 pull-ups", "10 squats", "10 push-ups"], "the fifth is water, then pull-ups resume")
        }

        test("a specific break number beats a pattern, and the rarer pattern beats the commoner") {
            let r = Routine(length: 20, tasks: [
                pushUps, water,
                Activity(name: "Stretch", seconds: 30, placement: .every(10)),
                walk,
            ])
            let plan = names(r)
            expect(plan[4], "Drink water", "the fifth is water")
            expect(plan[9], "Stretch", "the tenth is the rarer stretch, not water")
            expect(plan[19], "Take a walk", "the twentieth is the walk, pinned by number")
        }

        test("the user's example plays out exactly as described") {
            let r = Routine(length: 20, tasks: [pushUps, pullUps, squats, water, walk])
            let plan = names(r)
            expect(Array(plan[0..<5]), ["10 push-ups", "10 pull-ups", "10 squats", "10 push-ups", "Drink water"],
                   "first five")
            expect(plan[19], "Take a walk", "twentieth")
            expect(plan.filter { $0 == "Drink water" }.count, 3, "water on the 5th, 10th and 15th")
            expect(r.activity(forBreak: 20)?.seconds ?? 0, 1800, "the walk carries its own length")
        }

        test("the routine starts over after its last break") {
            let r = Routine(length: 3, tasks: [pushUps, water])
            expect(r.upcoming(7).map { $0?.name ?? "rest" },
                   ["10 push-ups", "10 push-ups", "10 push-ups", "10 push-ups", "10 push-ups", "10 push-ups", "10 push-ups"],
                   "water every 5th never lands inside a 3-break routine")
            let w = Routine(length: 3, tasks: [pushUps, Activity(name: "Water", seconds: 20, placement: .on([3]))])
            expect(w.upcoming(7).map { $0?.name ?? "rest" },
                   ["10 push-ups", "10 push-ups", "Water", "10 push-ups", "10 push-ups", "Water", "10 push-ups"],
                   "break 3 comes round again as break 6")
        }

        test("upcoming continues from the breaks already shown today") {
            let r = Routine(length: 12, tasks: [pushUps, pullUps, squats])
            expect(r.upcoming(2, after: 4).map { $0?.name ?? "rest" }, ["10 pull-ups", "10 squats"],
                   "after four shown, the fifth is pull-ups")
        }

        test("a pattern of every 1st, and break numbers outside the routine, do nothing") {
            let r = Routine(length: 4, tasks: [
                pushUps,
                Activity(name: "Water", seconds: 20, placement: .every(1)),
                Activity(name: "Walk", seconds: 900, placement: .on([9])),
            ])
            expect(names(r), ["10 push-ups", "10 push-ups", "10 push-ups", "10 push-ups"], "nonsense placements are ignored")
        }

        test("length is clamped and break lists are parsed leniently") {
            expect(Routine(length: 1).length, Routine.minLength, "too short")
            expect(Routine(length: 999).length, Routine.maxLength, "too long")
            expect(Routine.parseBreaks("3, 7 12 3 40", length: 12).map(String.init), ["3", "7", "12"], "dedupe, sort, drop out of range")
        }

        test("placements describe themselves") {
            expect(Placement.turns.label(length: 12), "takes turns", "turns")
            expect(Placement.every(3).label(length: 12), "every 3rd break", "every")
            expect(Placement.on([12]).label(length: 12), "break 12", "one break")
            expect(Placement.on([3, 7]).label(length: 12), "breaks 3, 7", "several breaks")
        }

        test("counts translate to time at the current interval") {
            expect(Routine.cadence(breaks: 12, workMinutes: 30), "≈ 6 h", "twelve at thirty")
            expect(Routine.cadence(breaks: 5, workMinutes: 20), "≈ 1 h 40 min", "five at twenty")
            expect(Routine.ordinal(2), "2nd", "2nd")
            expect(Routine.ordinal(11), "11th", "11th")
            expect(Routine.ordinal(21), "21st", "21st")
            expect(Routine.duration(45), "45 s", "seconds")
            expect(Routine.duration(5400), "1 hr 30 min", "hours and minutes")
            expect(Routine.durationLong(1800), "30 minutes", "spelled out")
        }

        test("a routine round-trips through JSON, lines and GIFs included") {
            var walk = self.walk
            walk.line = "Leave the desk."
            walk.gif = "/tmp/walk.gif"
            let r = Routine(length: 20, tasks: [pushUps, water, walk])
            let data = try! JSONEncoder().encode(r)
            let back = try! JSONDecoder().decode(Routine.self, from: data)
            checks += 1
            if back != r { failures += 1; print("  ✗ routine changed in the round trip") }
        }

        test("a routine saved by the first build still decodes") {
            let legacy = """
            {"cycle":[{"name":"10 push-ups","seconds":45}],
             "rules":[{"every":3,"activity":{"name":"Water","seconds":30}},
                      {"every":20,"activity":{"name":"Walk","seconds":900}}]}
            """
            let r = try! JSONDecoder().decode(Routine.self, from: legacy.data(using: .utf8)!)
            expect(r.length, 20, "long enough to reach the rarest rule")
            expect(r.tasks.map(\.name), ["10 push-ups", "Water", "Walk"], "every task survives")
            expect(r.tasks[2].placement.label(length: 20), "every 20th break", "rules became patterns")
            expect(r.slots()[2]?.name ?? "rest", "Water", "and the third break is still water")
        }

        test("every template is non-empty and its placements are sane") {
            for (name, r) in Routine.templates {
                checks += 1
                if r.isEmpty { failures += 1; print("  ✗ \(name) is empty") }
                for t in r.tasks {
                    if let n = t.placement.every, n < 2 { failures += 1; print("  ✗ \(name): \(t.name) every \(n)") }
                    if let b = t.placement.breaks, b.contains(where: { $0 < 1 || $0 > r.length }) {
                        failures += 1; print("  ✗ \(name): \(t.name) placed outside the routine")
                    }
                }
            }
        }
    }
}
