import Foundation

enum PhaseKey: String {
    case foundation
    case capacity
    case momentum

    var displayName: String {
        switch self {
        case .foundation: "Foundation"
        case .capacity: "Build Capacity"
        case .momentum: "Momentum"
        }
    }
}

enum Program {
    static let beginnerProgram = WorkoutPlan(
        id: "beginner-12-week",
        name: "12-week beginner program",
        phase: "Foundation, Build Capacity, Momentum",
        durationWeeks: 12,
        workouts: Array(workoutLibrary.values)
    )

    static func programWeek(startDate: String, date: String) -> Int {
        let start = DateCoding.date(fromDay: startDate)
        let current = DateCoding.date(fromDay: date)
        let days = Calendar.current.dateComponents([.day], from: start, to: current).day ?? 0
        let dayIndex = max(0, days)
        return min(12, dayIndex / 7 + 1)
    }

    static func programPhase(week: Int) -> PhaseKey {
        if week <= 4 { return .foundation }
        if week <= 8 { return .capacity }
        return .momentum
    }

    static func phaseName(startDate: String, date: String) -> String {
        programPhase(week: programWeek(startDate: startDate, date: date)).displayName
    }

    static func plan(startDate: String, date: String) -> [String] {
        let start = DateCoding.date(fromDay: startDate)
        let current = DateCoding.date(fromDay: date)
        let days = Calendar.current.dateComponents([.day], from: start, to: current).day ?? 0
        let dayIndex = max(0, days)
        let week = min(12, dayIndex / 7 + 1)
        let day = dayIndex % 7
        return weeklyTemplates[programPhase(week: week)]?[day] ?? []
    }

    static func workout(id: String, startDate: String, date: String) -> Workout? {
        let week = programWeek(startDate: startDate, date: date)
        let phase = programPhase(week: week)

        switch id {
        case "strengthA": return strengthA(phase: phase, week: week)
        case "strengthB": return strengthB(phase: phase)
        case "intervals": return intervals(phase: phase)
        case "walk30": return makeWalk(minutes: 30, title: "Easy walk")
        case "longCardio":
            return makeWalk(
                minutes: phase == .foundation ? 40 : 50,
                title: phase == .foundation ? "Longer walk" : "Longer cardio"
            )
        case "mobility": return mobility
        default: return workoutLibrary[id]
        }
    }

    private static let weeklyTemplates: [PhaseKey: [[String]]] = [
        .foundation: [
            ["strengthA"],
            ["walk30", "intervals"],
            ["strengthB"],
            ["walk30"],
            ["strengthA"],
            ["longCardio"],
            ["mobility"]
        ],
        .capacity: [
            ["strengthA"],
            ["intervals"],
            ["strengthB"],
            ["walk30", "mobility"],
            ["strengthA"],
            ["longCardio"],
            ["mobility"]
        ],
        .momentum: [
            ["strengthA"],
            ["intervals"],
            ["strengthB"],
            ["walk30"],
            ["strengthA"],
            ["longCardio"],
            ["mobility"]
        ]
    ]

    private static let workoutLibrary: [String: Workout] = [
        "strengthA": strengthA(phase: .foundation, week: 1),
        "strengthB": strengthB(phase: .foundation),
        "intervals": intervals(phase: .foundation),
        "walk30": makeWalk(minutes: 30, title: "Easy walk"),
        "longCardio": makeWalk(minutes: 40, title: "Longer walk"),
        "mobility": mobility
    ]

    private static func rule(ceiling: String) -> ProgressionRules {
        ProgressionRules(
            increaseAfterCompletions: 4,
            increaseBy: "Add reps, time, or rounds only when recovery feels steady.",
            ceiling: ceiling
        )
    }

    private static func strengthExercise(
        id: String,
        name: String,
        reps: Int,
        instructions: String,
        regressionRules: [String] = ["Reduce reps by 20-30%", "Shorten range of motion"],
        targetSuffix: String? = nil,
        timerPresets: [ExerciseTimerPreset] = [restTimer()]
    ) -> Exercise {
        Exercise(
            id: id,
            name: name,
            category: .strength,
            progressionRules: rule(ceiling: "Stop before form changes or joints complain."),
            regressionRules: regressionRules,
            defaultReps: reps,
            targetSuffix: targetSuffix,
            defaultDuration: nil,
            targetLabel: nil,
            instructions: instructions,
            timerPresets: timerPresets
        )
    }

    private static func timedExercise(
        id: String,
        name: String,
        category: WorkoutType,
        seconds: Int,
        instructions: String,
        regressionRules: [String],
        targetSuffix: String? = nil,
        timerPresets: [ExerciseTimerPreset]? = nil
    ) -> Exercise {
        Exercise(
            id: id,
            name: name,
            category: category,
            progressionRules: rule(ceiling: "Add time only when recovery is comfortable the next day."),
            regressionRules: regressionRules,
            defaultReps: nil,
            targetSuffix: targetSuffix,
            defaultDuration: seconds,
            targetLabel: nil,
            instructions: instructions,
            timerPresets: timerPresets ?? [workTimer(seconds: seconds)]
        )
    }

    private static func customExercise(
        id: String,
        name: String,
        category: WorkoutType,
        targetLabel: String,
        instructions: String,
        regressionRules: [String],
        timerPresets: [ExerciseTimerPreset] = []
    ) -> Exercise {
        Exercise(
            id: id,
            name: name,
            category: category,
            progressionRules: rule(ceiling: "Keep the effort repeatable and joint-friendly."),
            regressionRules: regressionRules,
            defaultReps: nil,
            targetSuffix: nil,
            defaultDuration: nil,
            targetLabel: targetLabel,
            instructions: instructions,
            timerPresets: timerPresets
        )
    }

    private static func restTimer(seconds: Int = 60) -> ExerciseTimerPreset {
        ExerciseTimerPreset(id: "rest-\(seconds)", label: "Rest", durationSeconds: seconds)
    }

    private static func workTimer(seconds: Int) -> ExerciseTimerPreset {
        ExerciseTimerPreset(id: "work-\(seconds)", label: "Work", durationSeconds: seconds)
    }

    private static func timer(id: String, label: String, seconds: Int) -> ExerciseTimerPreset {
        ExerciseTimerPreset(id: id, label: label, durationSeconds: seconds)
    }

    private static func makeWalk(minutes: Int, title: String = "Easy walk") -> Workout {
        Workout(
            id: minutes >= 45 ? "longCardio" : "walk30",
            title: title,
            type: .cardio,
            estimatedDuration: minutes,
            difficulty: minutes >= 45 ? 3 : 1,
            phase: "All phases",
            rounds: nil,
            guidance: "Use a pace you could repeat tomorrow. Splitting the walk is fine.",
            exercises: [
                timedExercise(
                    id: "\(title.lowercased().replacingOccurrences(of: " ", with: "-"))-\(minutes)",
                    name: title,
                    category: .cardio,
                    seconds: minutes * 60,
                    instructions: "Walk at a smooth, conversational pace and finish with a little in reserve.",
                    regressionRules: ["Shorten the walk", "Break it into two easy walks"]
                )
            ]
        )
    }

    private static let mobility = Workout(
        id: "mobility",
        title: "Rest + mobility",
        type: .mobility,
        estimatedDuration: 8,
        difficulty: 1,
        phase: "All phases",
        rounds: nil,
        guidance: "Easy range of motion counts. Nothing here should feel forced.",
        exercises: [
            customExercise(id: "shoulder-circles", name: "Shoulder circles", category: .mobility, targetLabel: "45 sec", instructions: "Slow circles forward and back.", regressionRules: ["Make smaller circles"], timerPresets: [workTimer(seconds: 45)]),
            customExercise(id: "hip-circles", name: "Hip circles", category: .mobility, targetLabel: "45 sec each way", instructions: "Hold a chair if balance is useful.", regressionRules: ["Reduce range"], timerPresets: [workTimer(seconds: 45)]),
            customExercise(id: "calf-stretch", name: "Calf stretch", category: .mobility, targetLabel: "45 sec each side", instructions: "Keep it gentle through calves and Achilles.", regressionRules: ["Bend the knee slightly"], timerPresets: [workTimer(seconds: 45)]),
            customExercise(id: "hamstring-stretch", name: "Hamstring stretch", category: .mobility, targetLabel: "45 sec each side", instructions: "Hinge gently; avoid pulling hard.", regressionRules: ["Use a chair-supported version"], timerPresets: [workTimer(seconds: 45)]),
            customExercise(id: "thoracic-twists", name: "Thoracic twists", category: .mobility, targetLabel: "8 each side", instructions: "Rotate through the upper back while breathing steadily.", regressionRules: ["Do seated twists"]),
            customExercise(id: "ankle-mobility", name: "Ankle mobility", category: .mobility, targetLabel: "8 each side", instructions: "Move the knee over the toes without pain.", regressionRules: ["Use a smaller range"])
        ]
    )

    private static func strengthA(phase: PhaseKey, week: Int) -> Workout {
        let isFoundation = phase == .foundation
        let isMomentum = phase == .momentum
        let rounds = isFoundation ? (week >= 3 ? "2-3 rounds" : "2 rounds") : "3 rounds"
        let reps: (squats: Int, pushups: Int, bridges: Int, stepUps: Int, plank: Int, birdDogs: Int) = {
            if isFoundation { return (10, 8, 10, 10, 20, 10) }
            if phase == .capacity { return (12, 10, 12, 12, 30, 12) }
            return (15, 12, 15, 15, 45, 0)
        }()

        let exercises: [Exercise] = isMomentum ? [
            strengthExercise(id: "squats", name: "Bodyweight squats", reps: reps.squats, instructions: "Sit back, stand tall, and keep the knees comfortable."),
            strengthExercise(id: "incline-pushups", name: "Incline pushups", reps: reps.pushups, instructions: "Lower the incline gradually only if these feel easy."),
            strengthExercise(id: "reverse-lunges", name: "Reverse lunges", reps: 12, instructions: "Hold a wall or chair if useful.", regressionRules: ["Swap for chair squats"], targetSuffix: "each leg"),
            strengthExercise(id: "glute-bridges", name: "Glute bridges", reps: reps.bridges, instructions: "Press through heels without arching the low back."),
            timedExercise(id: "plank", name: "Plank", category: .strength, seconds: reps.plank, instructions: "Brace gently and breathe.", regressionRules: ["Use an elevated plank"]),
            timedExercise(id: "side-plank", name: "Side plank", category: .strength, seconds: 30, instructions: "Keep the hold clean and short of strain.", regressionRules: ["Bend knees", "Use a shorter hold"], targetSuffix: "each side"),
            strengthExercise(id: "step-ups", name: "Step-ups", reps: reps.stepUps, instructions: "Use a low, sturdy step and move with control.", regressionRules: ["Use a lower step"], targetSuffix: "each leg")
        ] : [
            strengthExercise(id: "squats", name: "Bodyweight squats", reps: reps.squats, instructions: "Sit back, stand tall, and keep the knees comfortable."),
            strengthExercise(id: "incline-pushups", name: "Incline pushups", reps: reps.pushups, instructions: "Use a counter or table height that lets you move smoothly."),
            strengthExercise(id: "glute-bridges", name: "Glute bridges", reps: reps.bridges, instructions: "Press through heels without arching the low back."),
            strengthExercise(id: "step-ups", name: "Step-ups", reps: reps.stepUps, instructions: "Use a low, sturdy step and alternate sides.", regressionRules: ["Use a lower step"], targetSuffix: "each leg"),
            timedExercise(id: "plank", name: "Plank", category: .strength, seconds: reps.plank, instructions: "Brace gently and breathe.", regressionRules: ["Use an elevated plank"]),
            strengthExercise(id: "bird-dogs", name: "Bird dogs", reps: reps.birdDogs, instructions: "Reach opposite arm and leg while keeping hips steady.", regressionRules: ["Move only legs"], targetSuffix: "each side")
        ]

        return Workout(
            id: "strengthA",
            title: "Strength A",
            type: .strength,
            estimatedDuration: isFoundation ? 24 : 30,
            difficulty: phase == .momentum ? 4 : phase == .capacity ? 3 : 2,
            phase: phase.displayName,
            rounds: rounds,
            guidance: "Rest 45-60 seconds between exercises as needed. Clean reps beat extra reps.",
            exercises: exercises
        )
    }

    private static func strengthB(phase: PhaseKey) -> Workout {
        if phase == .momentum { return strengthA(phase: phase, week: 9) }

        let isFoundation = phase == .foundation
        let reps = isFoundation ? (lunges: 8, pushups: 10, sidePlank: 15, bridges: 12, deadBugs: 10, plank: 25) : (lunges: 10, pushups: 11, sidePlank: 20, bridges: 15, deadBugs: 12, plank: 30)

        return Workout(
            id: "strengthB",
            title: "Strength B",
            type: .strength,
            estimatedDuration: isFoundation ? 24 : 30,
            difficulty: isFoundation ? 2 : 3,
            phase: phase.displayName,
            rounds: isFoundation ? "2 rounds" : "3 rounds",
            guidance: "Hold a wall or chair for balance whenever it helps. Skip anything that bothers knees or hips.",
            exercises: [
                strengthExercise(id: "reverse-lunges", name: "Reverse lunges", reps: reps.lunges, instructions: "Step back gently while holding support if needed.", regressionRules: ["Swap for chair squats"], targetSuffix: "each leg"),
                strengthExercise(id: "wall-or-incline-pushups", name: isFoundation ? "Wall or incline pushups" : "Incline pushups", reps: reps.pushups, instructions: "Choose the height that keeps shoulders comfortable.", regressionRules: ["Use a higher surface"]),
                timedExercise(id: "side-plank", name: "Side plank", category: .strength, seconds: reps.sidePlank, instructions: "Keep the hold calm and controlled.", regressionRules: ["Bend knees", "Shorten the hold"], targetSuffix: "each side"),
                strengthExercise(id: "glute-bridges", name: "Glute bridges", reps: reps.bridges, instructions: "Press through heels without arching the low back."),
                strengthExercise(id: "dead-bugs", name: "Dead bugs", reps: reps.deadBugs, instructions: "Move slowly and keep the low back comfortable.", regressionRules: ["Tap one heel at a time"], targetSuffix: "each side"),
                timedExercise(id: "plank-or-hollow", name: isFoundation ? "Hollow-body hold or plank" : "Plank", category: .strength, seconds: reps.plank, instructions: "Choose the version that lets you breathe and maintain form.", regressionRules: ["Use a regular plank", "Use an elevated plank"])
            ]
        )
    }

    private static func intervals(phase: PhaseKey) -> Workout {
        let config: (title: String, minutes: Int, jump: String, walk: String) = {
            switch phase {
            case .foundation:
                return ("Walk + intervals", 28, "20 sec jump rope / 70-90 sec easy walk, 6-8 rounds", "1 min fast walk / 2 min normal pace, 8-10 rounds")
            case .capacity:
                return ("Cardio intervals", 30, "30 sec jump rope / 60 sec rest, 8-12 rounds", "1 min light jog / 2 min walk, 8-10 rounds")
            case .momentum:
                return ("Intervals", 34, "45 sec jump rope / 45-60 sec recovery, 10-15 rounds", "2 min jog / 2 min walk, 8-10 rounds")
            }
        }()

        return Workout(
            id: "intervals",
            title: config.title,
            type: .cardio,
            estimatedDuration: config.minutes,
            difficulty: phase == .foundation ? 2 : phase == .capacity ? 3 : 4,
            phase: phase.displayName,
            rounds: nil,
            guidance: "If jump rope bothers knees, calves, or Achilles tendons, switch to walking intervals immediately.",
            exercises: [
                customExercise(id: "warm-walk", name: "Warm walk", category: .cardio, targetLabel: "5 min", instructions: "Start easy and let joints warm up.", regressionRules: ["Warm up longer if stiff"], timerPresets: [timer(id: "warmup-300", label: "Warmup", seconds: 300)]),
                customExercise(id: "jump-rope-option", name: "Option A: jump rope", category: .cardio, targetLabel: config.jump, instructions: "Keep jumps low and relaxed.", regressionRules: ["Switch to brisk walking intervals"], timerPresets: [timer(id: "interval-work-60", label: "Interval", seconds: 60)]),
                customExercise(id: "walking-option", name: "Option B: walking intervals", category: .cardio, targetLabel: config.walk, instructions: "Stay brisk, not breathless.", regressionRules: ["Shorten fast segments"], timerPresets: [timer(id: "interval-work-120", label: "Interval", seconds: 120)]),
                customExercise(id: "cooldown", name: "Easy cooldown", category: .cardio, targetLabel: "3-5 min", instructions: "Finish with relaxed walking.", regressionRules: ["Stop earlier if needed"], timerPresets: [timer(id: "cooldown-300", label: "Cooldown", seconds: 300)])
            ]
        )
    }
}
