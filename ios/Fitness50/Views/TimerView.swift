import SwiftUI

struct TimerView: View {
    @EnvironmentObject private var store: SessionStore

    var prefill: TimerPrefill?
    var onBack: () -> Void

    @State private var activityType: WorkoutType
    @State private var label: String
    @State private var durationSeconds: Int

    init(prefill: TimerPrefill?, onBack: @escaping () -> Void) {
        self.prefill = prefill
        self.onBack = onBack
        _activityType = State(initialValue: prefill?.activityType ?? .cardio)
        _label = State(initialValue: prefill?.label ?? "Walk")
        _durationSeconds = State(initialValue: prefill?.durationSeconds ?? 30 * 60)
    }

    var body: some View {
        if let running = store.state.pendingTimers.first {
            TimerRunningView(timer: running, onBack: onBack, onCancel: {
                store.cancelTimer(running.id)
                onBack()
            })
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ScreenHeader(
                        eyebrow: "Standalone timer",
                        title: "Start a timer",
                        backAction: onBack
                    )

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Activity")
                            .font(.headline)

                        Picker("Activity", selection: $activityType) {
                            ForEach(WorkoutType.allCases) { type in
                                Text(type.rawValue.capitalized).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text("Label")
                            .font(.headline)
                            .padding(.top, 4)

                        TextField("Walk, stretch, etc.", text: $label)
                            .textFieldStyle(.roundedBorder)

                        Text("Duration")
                            .font(.headline)
                            .padding(.top, 4)

                        DurationPicker(durationSeconds: $durationSeconds)
                    }
                    .padding(16)
                    .background(AppColors.secondaryBackground, in: RoundedRectangle(cornerRadius: 8))

                    Button(action: startTimer) {
                        Label("Start \(formattedDuration(durationSeconds)) \(activityType.rawValue)", systemImage: "play.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || durationSeconds < 1)
                }
                .padding(20)
            }
        }
    }

    private func startTimer() {
        let timer = PendingTimer(
            id: UUID(),
            fireAt: Date().addingTimeInterval(TimeInterval(durationSeconds)),
            label: label.trimmingCharacters(in: .whitespacesAndNewlines),
            activityType: activityType,
            durationSeconds: durationSeconds,
            sourceWorkoutId: prefill?.sourceWorkoutId
        )
        store.startTimer(timer)
    }

    private func formattedDuration(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)-sec"
        }

        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        if remainingSeconds == 0 {
            return "\(minutes)-min"
        }

        return "\(minutes)-min \(remainingSeconds)-sec"
    }
}

private struct DurationPicker: View {
    @Binding var durationSeconds: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 8)], spacing: 8) {
                ForEach([30, 45, 60, 120, 300, 600, 1200, 1800, 2700, 3600], id: \.self) { seconds in
                    Button(formatDuration(seconds)) {
                        durationSeconds = seconds
                    }
                    .buttonStyle(.bordered)
                    .tint(durationSeconds == seconds ? .accentColor : .secondary)
                }
            }

            Stepper(value: $durationSeconds, in: 15...(240 * 60), step: 15) {
                Text(formatDuration(durationSeconds))
                    .font(.headline.monospacedDigit())
            }
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds) sec"
        }

        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        if remainingSeconds == 0 {
            return "\(minutes) min"
        }

        return "\(minutes)m \(remainingSeconds)s"
    }
}

private struct TimerRunningView: View {
    var timer: PendingTimer
    var onBack: () -> Void
    var onCancel: () -> Void

    @State private var now = Date()

    private var remainingSeconds: Int {
        max(0, Int(ceil(timer.fireAt.timeIntervalSince(now))))
    }

    private var isDone: Bool {
        remainingSeconds == 0
    }

    private var displayTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScreenHeader(
                    eyebrow: timer.activityType.rawValue,
                    title: timer.label,
                    backAction: onBack
                )

                VStack(spacing: 14) {
                    Image(systemName: "timer")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.accentColor)
                    Text(displayTime)
                        .font(.system(size: 58, weight: .bold, design: .monospaced))
                    Text(isDone ? "Time's up - log it from Today when you're back." : "Lock your phone - we'll notify you when it's done.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(AppColors.secondaryBackground, in: RoundedRectangle(cornerRadius: 8))

                Button("Cancel timer", action: onCancel)
                    .buttonStyle(PrimaryButtonStyle())

                Button("Done early", action: onCancel)
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
            }
            .padding(20)
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
            now = date
        }
    }
}
