import Combine
import Foundation

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var state: AppState

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.fileURL = fileURL ?? documents.appendingPathComponent("fitness50-state.json")
        self.state = AppState.defaultState()
        load()
    }

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            state = AppState.defaultState()
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            var decoded = try DateCoding.jsonDecoder.decode(AppState.self, from: data)
            decoded = migrate(decoded)
            state = decoded
        } catch {
            state = AppState.defaultState()
        }
    }

    func save() {
        do {
            let data = try DateCoding.jsonEncoder.encode(state)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            assertionFailure("Failed to save app state: \(error)")
        }
    }

    func session(for date: String = DateCoding.dayString(from: Date())) -> DailySession {
        let plannedWorkouts = Program.plan(startDate: state.startDate, date: date)

        if var saved = state.sessions[date] {
            saved.plannedWorkouts = plannedWorkouts
            saved.completedWorkouts = saved.completedWorkouts.filter { plannedWorkouts.contains($0) }
            saved.skippedWorkouts = saved.skippedWorkouts.filter { plannedWorkouts.contains($0) }
            return saved
        }

        return DailySession(
            date: date,
            plannedWorkouts: plannedWorkouts,
            completedWorkouts: [],
            skippedWorkouts: [],
            adHocActivities: [],
            notes: "",
            sorenessRating: 2,
            energyRating: 3,
            sleepRating: 3,
            jointPain: false
        )
    }

    func workouts(for session: DailySession) -> [Workout] {
        session.plannedWorkouts.compactMap {
            Program.workout(id: $0, startDate: state.startDate, date: session.date)
        }
    }

    func upsert(_ session: DailySession) {
        state.sessions[session.date] = session
        save()
    }

    func completeWorkout(_ workoutId: String, date: String = DateCoding.dayString(from: Date())) {
        var session = session(for: date)
        if !session.completedWorkouts.contains(workoutId) {
            session.completedWorkouts.append(workoutId)
        }
        session.skippedWorkouts.removeAll { $0 == workoutId }
        upsert(session)
    }

    func toggleSkippedWorkout(_ workoutId: String, date: String = DateCoding.dayString(from: Date())) {
        var session = session(for: date)
        if session.skippedWorkouts.contains(workoutId) {
            session.skippedWorkouts.removeAll { $0 == workoutId }
        } else {
            session.skippedWorkouts.append(workoutId)
        }
        upsert(session)
    }

    func startTimer(_ timer: PendingTimer) {
        state.pendingTimers.append(timer)
        save()
        TimerScheduler.schedule(timer)
    }

    func cancelTimer(_ timerId: UUID) {
        state.pendingTimers.removeAll { $0.id == timerId }
        save()
        TimerScheduler.cancel(timerId)
    }

    func dismissTimer(_ timerId: UUID) {
        state.pendingTimers.removeAll { $0.id == timerId }
        save()
    }

    func firedTimers(now: Date = Date()) -> [PendingTimer] {
        state.pendingTimers.filter { $0.fireAt <= now }
    }

    func logTimer(_ timerId: UUID, date: String = DateCoding.dayString(from: Date())) {
        guard let timer = state.pendingTimers.first(where: { $0.id == timerId }) else { return }
        var session = session(for: date)

        if let sourceWorkoutId = timer.sourceWorkoutId {
            if !session.completedWorkouts.contains(sourceWorkoutId) {
                session.completedWorkouts.append(sourceWorkoutId)
            }
            session.skippedWorkouts.removeAll { $0 == sourceWorkoutId }
        } else {
            let activity = AdHocActivity(
                id: timer.id.uuidString,
                label: timer.label,
                type: timer.activityType,
                startedAt: timer.fireAt.addingTimeInterval(TimeInterval(-timer.durationMinutes * 60)),
                durationMinutes: timer.durationMinutes
            )
            session.adHocActivities.append(activity)
        }

        state.sessions[session.date] = session
        state.pendingTimers.removeAll { $0.id == timerId }
        save()
    }

    func updateRecovery(date: String = DateCoding.dayString(from: Date()), update: (inout DailySession) -> Void) {
        var session = session(for: date)
        update(&session)
        upsert(session)
    }

    func toggleEasierToday() {
        state.easierToday.toggle()
        save()
    }

    func setActiveWorkout(_ workoutId: String?) {
        state.activeWorkoutId = workoutId
        save()
    }

    func sessionsForLast(days count: Int, endingAt date: Date = Date()) -> [DailySession] {
        (0..<count).compactMap { offset in
            guard let day = Calendar.current.date(byAdding: .day, value: -offset, to: date) else {
                return nil
            }
            return session(for: DateCoding.dayString(from: day))
        }
    }

    func lastSevenMovementDays() -> Int {
        sessionsForLast(days: 7).filter {
            !$0.completedWorkouts.isEmpty || !$0.adHocActivities.isEmpty
        }.count
    }

    private func migrate(_ decoded: AppState) -> AppState {
        var migrated = decoded
        if migrated.profile.goals.isEmpty {
            migrated.profile.goals = AppState.defaultState().profile.goals
        }
        return migrated
    }
}
