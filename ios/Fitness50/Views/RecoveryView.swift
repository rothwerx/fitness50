import SwiftUI

struct RecoveryView: View {
    @EnvironmentObject private var store: SessionStore

    var onBack: () -> Void

    private var today: String { DateCoding.dayString(from: Date()) }
    private var session: DailySession { store.session(for: today) }

    var body: some View {
        let advice = Progression.recoveryAdvice(for: session)

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScreenHeader(
                    eyebrow: "Recovery check-in",
                    title: "How are you today?",
                    backAction: onBack
                )

                RatingControl(
                    label: "Soreness",
                    value: session.sorenessRating,
                    onChange: { value in store.updateRecovery { $0.sorenessRating = value } }
                )

                RatingControl(
                    label: "Energy",
                    value: session.energyRating,
                    onChange: { value in store.updateRecovery { $0.energyRating = value } }
                )

                RatingControl(
                    label: "Sleep",
                    value: session.sleepRating,
                    onChange: { value in store.updateRecovery { $0.sleepRating = value } }
                )

                Toggle(
                    "Knees or joints need extra care today",
                    isOn: Binding(
                        get: { session.jointPain },
                        set: { isOn in store.updateRecovery { $0.jointPain = isOn } }
                    )
                )
                .padding(16)
                .background(AppColors.secondaryBackground, in: RoundedRectangle(cornerRadius: 8))

                RecoveryBanner(advice: advice)
            }
            .padding(20)
        }
    }
}

private struct RatingControl: View {
    var label: String
    var value: Int
    var onChange: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(label)
                    .font(.headline)
                Spacer()
                Text("\(value)/5")
                    .font(.headline.monospacedDigit())
            }

            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { onChange(Int($0.rounded())) }
                ),
                in: 1...5,
                step: 1
            )
        }
        .padding(16)
        .background(AppColors.secondaryBackground, in: RoundedRectangle(cornerRadius: 8))
    }
}
