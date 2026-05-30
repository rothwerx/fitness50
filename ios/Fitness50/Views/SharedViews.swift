import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct ScreenHeader: View {
    var eyebrow: String
    var title: String
    var subtitle: String?
    var backAction: (() -> Void)?
    var trailing: AnyView?

    init(
        eyebrow: String,
        title: String,
        subtitle: String? = nil,
        backAction: (() -> Void)? = nil,
        trailing: AnyView? = nil
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.backAction = backAction
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            if let backAction {
                Button(action: backAction) {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.largeTitle.weight(.bold))
                    .lineLimit(2)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            trailing
        }
    }
}

struct MetricTile: View {
    var label: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct RecoveryBanner: View {
    var advice: RecoveryAdvice

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "heart.text.square")
                .font(.title2)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 4) {
                Text(advice.title)
                    .font(.headline)
                Text(advice.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private var color: Color {
        switch advice.level {
        case .steady: .green
        case .easier: .orange
        case .recovery: .red
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.accentColor.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(.white)
    }
}

extension WorkoutType {
    var symbolName: String {
        switch self {
        case .strength: "figure.strengthtraining.traditional"
        case .cardio: "timer"
        case .mobility: "wind"
        case .recovery: "heart"
        }
    }
}

enum AppColors {
    static var secondaryBackground: Color {
        #if os(iOS)
        Color(UIColor.secondarySystemBackground)
        #elseif os(macOS)
        Color(NSColor.controlBackgroundColor)
        #else
        Color.gray.opacity(0.12)
        #endif
    }

    static var tertiaryBackground: Color {
        #if os(iOS)
        Color(UIColor.tertiarySystemBackground)
        #elseif os(macOS)
        Color(NSColor.windowBackgroundColor)
        #else
        Color.gray.opacity(0.08)
        #endif
    }

    static var tertiaryFill: Color {
        #if os(iOS)
        Color(UIColor.tertiarySystemFill)
        #elseif os(macOS)
        Color(NSColor.separatorColor)
        #else
        Color.gray.opacity(0.25)
        #endif
    }
}
