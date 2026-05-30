import Foundation

enum RecoveryLevel: String {
    case steady
    case easier
    case recovery
}

struct RecoveryAdvice: Equatable {
    var level: RecoveryLevel
    var title: String
    var message: String
    var volumeModifier: Double
}

struct RollingStats: Equatable {
    var consistency: Int
    var completedDays: Int
    var cardioMinutes: Int
}

enum Progression {
    static func recoveryAdvice(for session: DailySession) -> RecoveryAdvice {
        if session.jointPain || session.sorenessRating >= 4 || session.energyRating <= 1 {
            return RecoveryAdvice(
                level: .recovery,
                title: "Recovery is the plan today",
                message: "Swap intensity for walking or mobility and reduce volume by about 30%.",
                volumeModifier: 0.7
            )
        }

        if session.sorenessRating >= 3 || session.sleepRating <= 2 || session.energyRating <= 2 {
            return RecoveryAdvice(
                level: .easier,
                title: "Make today a little easier",
                message: "Keep the habit, reduce reps or time by about 15%, and leave something in reserve.",
                volumeModifier: 0.85
            )
        }

        return RecoveryAdvice(
            level: .steady,
            title: "Steady effort is enough",
            message: "Use the planned session and stop while you still feel repeatable.",
            volumeModifier: 1.0
        )
    }

    static func applyVolume(_ value: Int?, modifier: Double) -> Int? {
        guard let value, value != 0 else { return value }
        return max(1, Int((Double(value) * modifier).rounded()))
    }

    static func formatTarget(for exercise: Exercise, modifier: Double) -> String {
        if let targetLabel = exercise.targetLabel {
            return targetLabel
        }

        if let defaultReps = exercise.defaultReps {
            let reps = applyVolume(defaultReps, modifier: modifier) ?? defaultReps
            let suffix = exercise.targetSuffix.map { " \($0)" } ?? ""
            return "\(reps) reps\(suffix)"
        }

        if let defaultDuration = exercise.defaultDuration {
            let seconds = applyVolume(defaultDuration, modifier: modifier) ?? defaultDuration
            let target = seconds < 60 ? "\(seconds) sec" : "\(Int(ceil(Double(seconds) / 60.0))) min"
            let suffix = exercise.targetSuffix.map { " \($0)" } ?? ""
            return "\(target)\(suffix)"
        }

        return "Comfortable effort"
    }

    static func rollingStats(sessions: [DailySession]) -> RollingStats {
        let plannedDays = max(1, sessions.filter { !$0.plannedWorkouts.isEmpty }.count)
        let completedDays = sessions.filter { !$0.completedWorkouts.isEmpty || !$0.adHocActivities.isEmpty }.count

        let cardioMinutes = sessions.reduce(0) { total, session in
            let plannedCardioCount = session.completedWorkouts.filter { $0 == "walk30" || $0 == "intervals" }.count
            let adHocCardioMinutes = session.adHocActivities
                .filter { $0.type == .cardio }
                .reduce(0) { $0 + $1.durationMinutes }
            return total + plannedCardioCount * 24 + adHocCardioMinutes
        }

        return RollingStats(
            consistency: Int((Double(completedDays) / Double(plannedDays) * 100).rounded()),
            completedDays: completedDays,
            cardioMinutes: cardioMinutes
        )
    }
}
