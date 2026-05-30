import SwiftUI

struct WorkoutView: View {
    @EnvironmentObject private var store: SessionStore

    var workoutId: String
    var onBack: () -> Void
    var onDone: () -> Void
    var onOpenTimer: (TimerPrefill) -> Void

    private var today: String { DateCoding.dayString(from: Date()) }

    var body: some View {
        let session = store.session(for: today)
        let advice = Progression.recoveryAdvice(for: session)
        let modifier = min(advice.volumeModifier, store.state.easierToday ? 0.85 : 1.0)

        if let workout = Program.workout(id: workoutId, startDate: store.state.startDate, date: today) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ScreenHeader(
                        eyebrow: workout.type.rawValue,
                        title: workout.title,
                        subtitle: workout.rounds.map { "\(workout.phase) - \($0)" } ?? workout.phase,
                        backAction: onBack
                    )

                    VStack(spacing: 12) {
                        ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { index, exercise in
                            ExerciseRow(
                                index: index + 1,
                                exercise: exercise,
                                target: Progression.formatTarget(for: exercise, modifier: modifier),
                                onStartTimer: { preset in
                                    onOpenTimer(
                                        TimerPrefill(
                                            durationSeconds: preset.durationSeconds,
                                            label: "\(exercise.name) - \(preset.label)",
                                            activityType: exercise.category,
                                            sourceWorkoutId: nil
                                        )
                                    )
                                }
                            )
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Keep it repeatable")
                            .font(.headline)
                        Text(workout.guidance ?? advice.message)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(AppColors.secondaryBackground, in: RoundedRectangle(cornerRadius: 8))

                    Button {
                        onOpenTimer(
                            TimerPrefill(
                                durationSeconds: workout.estimatedDuration * 60,
                                label: workout.title,
                                activityType: workout.type,
                                sourceWorkoutId: workout.id
                            )
                        )
                    } label: {
                        Label("Start timer (\(workout.estimatedDuration) min)", systemImage: "timer")
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button(action: onDone) {
                        Label("Mark complete", systemImage: "checkmark")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(20)
            }
        } else {
            ContentUnavailableView("Workout not found", systemImage: "exclamationmark.triangle")
        }
    }
}

private struct ExerciseRow: View {
    var index: Int
    var exercise: Exercise
    var target: String
    var onStartTimer: (ExerciseTimerPreset) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(index)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .background(AppColors.tertiaryBackground, in: Circle())

            VStack(alignment: .leading, spacing: 7) {
                Text(exercise.name)
                    .font(.headline)
                Text(exercise.instructions)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(target)
                    .font(.subheadline.weight(.bold))

                if !exercise.timerPresets.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(exercise.timerPresets) { preset in
                                Button {
                                    onStartTimer(preset)
                                } label: {
                                    Label(timerLabel(for: preset), systemImage: "timer")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppColors.secondaryBackground, in: RoundedRectangle(cornerRadius: 8))
    }

    private func timerLabel(for preset: ExerciseTimerPreset) -> String {
        "\(preset.label) \(formatDuration(preset.durationSeconds))"
    }

    private func formatDuration(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)s"
        }

        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        if remainingSeconds == 0 {
            return "\(minutes)m"
        }

        return "\(minutes)m \(remainingSeconds)s"
    }
}
