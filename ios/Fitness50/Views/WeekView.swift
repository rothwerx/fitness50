import SwiftUI

struct WeekView: View {
    @EnvironmentObject private var store: SessionStore

    var onBack: () -> Void

    var body: some View {
        let weekSessions = store.sessionsForLast(days: 7)
        let monthSessions = store.sessionsForLast(days: 30)
        let weekStats = Progression.rollingStats(sessions: weekSessions)
        let monthStats = Progression.rollingStats(sessions: monthSessions)
        let today = DateCoding.dayString(from: Date())
        let programWeek = Program.programWeek(startDate: store.state.startDate, date: today)
        let phase = Program.phaseName(startDate: store.state.startDate, date: today)

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScreenHeader(
                    eyebrow: Program.beginnerProgram.name,
                    title: "Weekly view",
                    subtitle: "Week \(programWeek) - \(phase)",
                    backAction: onBack
                )

                HStack(spacing: 10) {
                    MetricTile(label: "Consistency", value: "\(weekStats.consistency)%")
                    MetricTile(label: "Moved", value: "\(weekStats.completedDays)/7")
                    MetricTile(label: "Cardio", value: "\(weekStats.cardioMinutes) min")
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("Last 7 days")
                        .font(.headline)
                    HStack(spacing: 10) {
                        ForEach(weekSessions.reversed()) { session in
                            DayDot(session: session)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(AppColors.secondaryBackground, in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Rolling 30 days")
                        .font(.headline)
                    Text("\(monthStats.completedDays) movement days. Missing one day does not erase the pattern.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(AppColors.secondaryBackground, in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(20)
        }
    }
}

private struct DayDot: View {
    var session: DailySession

    private var moved: Bool {
        !session.completedWorkouts.isEmpty || !session.adHocActivities.isEmpty
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(weekdayInitial)
                .font(.caption.weight(.semibold))
            Circle()
                .fill(moved ? Color.green : AppColors.tertiaryFill)
                .frame(width: 28, height: 28)
        }
        .frame(maxWidth: .infinity)
    }

    private var weekdayInitial: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return String(formatter.string(from: DateCoding.date(fromDay: session.date)).prefix(1))
    }
}
