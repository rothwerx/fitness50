import Foundation

enum Goal: String, Codable, CaseIterable, Identifiable {
    case fatLoss = "fat loss"
    case stamina
    case mobility
    case strength
    case consistency

    var id: String { rawValue }
}

enum WorkoutType: String, Codable, CaseIterable, Identifiable {
    case strength
    case cardio
    case mobility
    case recovery

    var id: String { rawValue }
}

enum ActivityBaseline: String, Codable, CaseIterable {
    case new
    case light
    case moderate
}

struct UserProfile: Codable, Equatable {
    var age: Int
    var height: String
    var weight: String?
    var activityBaseline: ActivityBaseline
    var mobilityLimitations: String?
    var goals: [Goal]
}

struct ProgressionRules: Codable, Equatable {
    var increaseAfterCompletions: Int
    var increaseBy: String
    var ceiling: String
}

struct Exercise: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var category: WorkoutType
    var progressionRules: ProgressionRules
    var regressionRules: [String]
    var defaultReps: Int?
    var targetSuffix: String?
    var defaultDuration: Int?
    var targetLabel: String?
    var instructions: String
    var timerPresets: [ExerciseTimerPreset]
}

struct ExerciseTimerPreset: Identifiable, Codable, Equatable {
    var id: String
    var label: String
    var durationSeconds: Int
}

struct Workout: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var type: WorkoutType
    var estimatedDuration: Int
    var difficulty: Int
    var phase: String
    var rounds: String?
    var guidance: String?
    var exercises: [Exercise]
}

struct WorkoutPlan: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var phase: String
    var durationWeeks: Int
    var workouts: [Workout]
}

struct AdHocActivity: Identifiable, Codable, Equatable {
    var id: String
    var label: String
    var type: WorkoutType
    var startedAt: Date
    var durationMinutes: Int
}

struct PendingTimer: Identifiable, Codable, Equatable {
    var id: UUID
    var fireAt: Date
    var label: String
    var activityType: WorkoutType
    var durationSeconds: Int
    var sourceWorkoutId: String?

    var durationMinutes: Int {
        max(1, Int(ceil(Double(durationSeconds) / 60.0)))
    }

    init(
        id: UUID,
        fireAt: Date,
        label: String,
        activityType: WorkoutType,
        durationSeconds: Int,
        sourceWorkoutId: String?
    ) {
        self.id = id
        self.fireAt = fireAt
        self.label = label
        self.activityType = activityType
        self.durationSeconds = max(1, durationSeconds)
        self.sourceWorkoutId = sourceWorkoutId
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case fireAt
        case label
        case activityType
        case durationSeconds
        case durationMinutes
        case sourceWorkoutId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        fireAt = try container.decode(Date.self, forKey: .fireAt)
        label = try container.decode(String.self, forKey: .label)
        activityType = try container.decode(WorkoutType.self, forKey: .activityType)
        if let decodedSeconds = try container.decodeIfPresent(Int.self, forKey: .durationSeconds) {
            durationSeconds = max(1, decodedSeconds)
        } else {
            let decodedMinutes = try container.decode(Int.self, forKey: .durationMinutes)
            durationSeconds = max(1, decodedMinutes * 60)
        }
        sourceWorkoutId = try container.decodeIfPresent(String.self, forKey: .sourceWorkoutId)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(fireAt, forKey: .fireAt)
        try container.encode(label, forKey: .label)
        try container.encode(activityType, forKey: .activityType)
        try container.encode(durationSeconds, forKey: .durationSeconds)
        try container.encode(sourceWorkoutId, forKey: .sourceWorkoutId)
    }
}

struct ReminderSettings: Codable, Equatable {
    var enabled: Bool
    var hour: Int
    var minute: Int

    static let defaultSettings = ReminderSettings(enabled: false, hour: 18, minute: 30)
}

struct DailySession: Identifiable, Codable, Equatable {
    var id: String { date }

    var date: String
    var plannedWorkouts: [String]
    var completedWorkouts: [String]
    var skippedWorkouts: [String]
    var adHocActivities: [AdHocActivity]
    var notes: String
    var sorenessRating: Int
    var energyRating: Int
    var sleepRating: Int
    var jointPain: Bool
}

struct AppState: Codable, Equatable {
    var profile: UserProfile
    var startDate: String
    var sessions: [String: DailySession]
    var easierToday: Bool
    var activeWorkoutId: String?
    var pendingTimers: [PendingTimer]
    var reminderSettings: ReminderSettings
    var rescheduledWorkouts: [String: [String]]

    init(
        profile: UserProfile,
        startDate: String,
        sessions: [String: DailySession],
        easierToday: Bool,
        activeWorkoutId: String?,
        pendingTimers: [PendingTimer],
        reminderSettings: ReminderSettings = .defaultSettings,
        rescheduledWorkouts: [String: [String]] = [:]
    ) {
        self.profile = profile
        self.startDate = startDate
        self.sessions = sessions
        self.easierToday = easierToday
        self.activeWorkoutId = activeWorkoutId
        self.pendingTimers = pendingTimers
        self.reminderSettings = reminderSettings
        self.rescheduledWorkouts = rescheduledWorkouts
    }

    private enum CodingKeys: String, CodingKey {
        case profile
        case startDate
        case sessions
        case easierToday
        case activeWorkoutId
        case pendingTimers
        case reminderSettings
        case rescheduledWorkouts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profile = try container.decode(UserProfile.self, forKey: .profile)
        startDate = try container.decode(String.self, forKey: .startDate)
        sessions = try container.decode([String: DailySession].self, forKey: .sessions)
        easierToday = try container.decode(Bool.self, forKey: .easierToday)
        activeWorkoutId = try container.decodeIfPresent(String.self, forKey: .activeWorkoutId)
        pendingTimers = try container.decode([PendingTimer].self, forKey: .pendingTimers)
        reminderSettings = try container.decodeIfPresent(ReminderSettings.self, forKey: .reminderSettings) ?? .defaultSettings
        rescheduledWorkouts = try container.decodeIfPresent([String: [String]].self, forKey: .rescheduledWorkouts) ?? [:]
    }

    static func defaultState(today: Date = Date()) -> AppState {
        AppState(
            profile: UserProfile(
                age: 50,
                height: "",
                weight: nil,
                activityBaseline: .light,
                mobilityLimitations: "",
                goals: [.consistency, .mobility, .strength]
            ),
            startDate: DateCoding.dayString(from: today),
            sessions: [:],
            easierToday: false,
            activeWorkoutId: nil,
            pendingTimers: [],
            reminderSettings: .defaultSettings,
            rescheduledWorkouts: [:]
        )
    }
}

enum DateCoding {
    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    static func dayString(from date: Date) -> String {
        dayFormatter.string(from: date)
    }

    static func date(fromDay day: String) -> Date {
        dayFormatter.date(from: day) ?? Date()
    }
}
