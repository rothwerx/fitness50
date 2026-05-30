import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: SessionStore
    @State private var now = Date()

    var onOpenWorkout: (String) -> Void
    var onOpenWeek: () -> Void
    var onOpenRecovery: () -> Void
    var onOpenTimer: () -> Void

    private var today: String { DateCoding.dayString(from: Date()) }
    private var session: DailySession { store.session(for: today) }
    private var workouts: [Workout] { store.workouts(for: session) }
    private var firedTimers: [PendingTimer] { store.firedTimers(now: now) }
    private var missedWorkouts: [(date: String, workout: Workout)] { store.missedWorkoutsFromYesterday() }

    var body: some View {
        let advice = Progression.recoveryAdvice(for: session)
        let week = Program.programWeek(startDate: store.state.startDate, date: today)
        let phase = Program.phaseName(startDate: store.state.startDate, date: today)
        let completedCount = session.completedWorkouts.count
        let totalMinutes = workouts.reduce(0) { $0 + $1.estimatedDuration }

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScreenHeader(
                    eyebrow: formattedToday,
                    title: "Today",
                    subtitle: "Week \(week) - \(phase)",
                    trailing: AnyView(
                        Button(action: onOpenWeek) {
                            Image(systemName: "calendar")
                        }
                        .buttonStyle(.bordered)
                    )
                )

                RecoveryBanner(advice: advice)

                HStack(spacing: 10) {
                    MetricTile(label: "Planned", value: "\(workouts.count)")
                    MetricTile(label: "Minutes", value: "\(totalMinutes)")
                    MetricTile(label: "Last 7", value: "\(store.lastSevenMovementDays()) days")
                }

                ReminderCard(
                    enabled: Binding(
                        get: { store.state.reminderSettings.enabled },
                        set: { store.setReminderEnabled($0) }
                    ),
                    time: reminderTimeBinding
                )

                if let timer = store.state.pendingTimers.first {
                    Button(action: onOpenTimer) {
                        Label("\(timer.label) - see timer", systemImage: "timer")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                ForEach(firedTimers) { timer in
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(timer.label) finished - log it?")
                            .font(.headline)

                        HStack(spacing: 10) {
                            Button {
                                store.logTimer(timer.id, date: today)
                            } label: {
                                Label("Log it", systemImage: "checkmark")
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Dismiss") {
                                store.dismissTimer(timer.id)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                }

                Button(action: onOpenTimer) {
                    Label("Start a quick timer", systemImage: "timer")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(action: onOpenRecovery) {
                    Label("Check in", systemImage: "slider.horizontal.3")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                ForEach(missedWorkouts, id: \.workout.id) { missed in
                    MissedWorkoutCard(
                        workout: missed.workout,
                        onMoveToToday: {
                            store.moveMissedWorkoutToToday(missed.workout.id, from: missed.date, today: today)
                        },
                        onSkip: {
                            store.toggleSkippedWorkout(missed.workout.id, date: missed.date)
                        }
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Planned movement")
                        .font(.title2.weight(.bold))

                    ForEach(workouts) { workout in
                        WorkoutCard(
                            workout: workout,
                            done: session.completedWorkouts.contains(workout.id),
                            skipped: session.skippedWorkouts.contains(workout.id),
                            rescheduled: store.state.rescheduledWorkouts[today]?.contains(workout.id) == true,
                            onStart: { onOpenWorkout(workout.id) },
                            onDone: { store.completeWorkout(workout.id) },
                            onSkip: { store.toggleSkippedWorkout(workout.id) },
                            onMoveToTomorrow: { store.moveWorkoutToTomorrow(workout.id, date: today) },
                            onKeepCalendar: { store.clearRescheduledWorkout(workout.id, date: today) }
                        )
                    }
                }

                Button(action: { store.toggleEasierToday() }) {
                    Label(store.state.easierToday ? "Easier mode is on" : "Easier today", systemImage: "wind")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(store.state.easierToday ? .orange : .accentColor)

                Text(completedCount > 0 ? "Good. The goal is repeatable progress." : "Starting small still counts.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
            }
            .padding(20)
        }
        .onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { date in
            now = date
        }
    }

    private var formattedToday: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: Date())
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding {
            var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            components.hour = store.state.reminderSettings.hour
            components.minute = store.state.reminderSettings.minute
            return Calendar.current.date(from: components) ?? Date()
        } set: { date in
            let components = Calendar.current.dateComponents([.hour, .minute], from: date)
            store.setReminderTime(
                hour: components.hour ?? store.state.reminderSettings.hour,
                minute: components.minute ?? store.state.reminderSettings.minute
            )
        }
    }
}

private struct ReminderCard: View {
    @Binding var enabled: Bool
    @Binding var time: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $enabled) {
                Label("Workout reminders", systemImage: "bell")
                    .font(.headline)
            }

            if enabled {
                DatePicker("At", selection: $time, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
            }
        }
        .padding(16)
        .background(AppColors.secondaryBackground, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct MissedWorkoutCard: View {
    var workout: Workout
    var onMoveToToday: () -> Void
    var onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.title2)
                    .frame(width: 32)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Missed yesterday")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(workout.title)
                        .font(.headline)
                    Text("\(workout.estimatedDuration) min - \(workout.type.rawValue)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                Button(action: onMoveToToday) {
                    Label("Do today", systemImage: "calendar.badge.plus")
                }
                .buttonStyle(.borderedProminent)

                Button(action: onSkip) {
                    Label("Skip", systemImage: "minus")
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct WorkoutCard: View {
    var workout: Workout
    var done: Bool
    var skipped: Bool
    var rescheduled: Bool
    var onStart: () -> Void
    var onDone: () -> Void
    var onSkip: () -> Void
    var onMoveToTomorrow: () -> Void
    var onKeepCalendar: () -> Void

    @State private var showingSkipOptions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: workout.type.symbolName)
                    .font(.title2)
                    .frame(width: 32)
                    .foregroundStyle(done ? .green : .accentColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text(workout.title)
                        .font(.headline)
                    Text("\(workout.estimatedDuration) min - \(workout.type.rawValue)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let rounds = workout.rounds {
                        Text(rounds)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    if rescheduled {
                        Label("Carried forward", systemImage: "arrow.forward")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }
                Spacer()
            }

            HStack(spacing: 10) {
                Button(action: onStart) {
                    Label("Start", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(done)

                Button(action: onDone) {
                    Label(done ? "Done" : "Done", systemImage: "checkmark")
                }
                .buttonStyle(.bordered)
                .disabled(done)

                Button {
                    showingSkipOptions = true
                } label: {
                    Image(systemName: skipped ? "arrow.counterclockwise" : "minus")
                }
                .buttonStyle(.bordered)
                .disabled(done)
                .accessibilityLabel(skipped ? "Undo skip \(workout.title)" : "Skip \(workout.title)")
            }
        }
        .padding(16)
        .background(done ? Color.green.opacity(0.10) : AppColors.secondaryBackground, in: RoundedRectangle(cornerRadius: 8))
        .confirmationDialog("Change \(workout.title)", isPresented: $showingSkipOptions, titleVisibility: .visible) {
            Button("Move to tomorrow") {
                onMoveToTomorrow()
            }

            Button(skipped ? "Undo skip" : "Mark skipped") {
                onSkip()
            }

            if rescheduled {
                Button("Remove carry-forward") {
                    onKeepCalendar()
                }
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Keep the calendar as-is, mark it skipped, or carry this workout forward.")
        }
    }
}
