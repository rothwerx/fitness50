import SwiftUI

enum AppScreen: Hashable {
    case today
    case workout(String)
    case week
    case recovery
    case timer(TimerPrefill?)
}

struct TimerPrefill: Hashable {
    var durationMinutes: Int
    var label: String
    var activityType: WorkoutType
    var sourceWorkoutId: String?
}

struct ContentView: View {
    @EnvironmentObject private var store: SessionStore
    @State private var screen: AppScreen = .today

    var body: some View {
        NavigationStack {
            Group {
                switch screen {
                case .today:
                    TodayView(
                        onOpenWorkout: { workoutId in
                            store.setActiveWorkout(workoutId)
                            screen = .workout(workoutId)
                        },
                        onOpenWeek: { screen = .week },
                        onOpenRecovery: { screen = .recovery },
                        onOpenTimer: { screen = .timer(nil) }
                    )
                case .workout(let workoutId):
                    WorkoutView(
                        workoutId: workoutId,
                        onBack: { screen = .today },
                        onDone: {
                            store.completeWorkout(workoutId)
                            store.setActiveWorkout(nil)
                            screen = .today
                        },
                        onOpenTimer: { prefill in screen = .timer(prefill) }
                    )
                case .week:
                    WeekView(onBack: { screen = .today })
                case .recovery:
                    RecoveryView(onBack: { screen = .today })
                case .timer(let prefill):
                    TimerView(prefill: prefill, onBack: { screen = .today })
                }
            }
            .animation(.default, value: screen)
        }
    }
}
