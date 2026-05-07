import AUCNativeCore
import SwiftUI

struct StatusDot: View {
    let status: AUCTaskStatus

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 9, height: 9)
            .shadow(color: color.opacity(0.55), radius: 5)
    }

    private var color: Color {
        switch status {
        case .completed:
            AUCDesign.ColorToken.green
        case .running:
            AUCDesign.ColorToken.cyan
        case .waitingPermission, .queued:
            AUCDesign.ColorToken.amber
        case .failed:
            AUCDesign.ColorToken.red
        case .cancelled, .interrupted, .unknown:
            AUCDesign.ColorToken.textSecondary
        }
    }
}

struct Chip: View {
    let label: String
    let systemImage: String

    var body: some View {
        Label(label, systemImage: systemImage)
            .font(AUCDesign.FontToken.sans(size: 11, weight: .semibold))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AUCDesign.ColorToken.panelStrong)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(AUCDesign.ColorToken.stroke, lineWidth: 1)
            }
    }
}

struct FlowRow<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: AUCDesign.Space.sm) {
            content
            Spacer(minLength: 0)
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AUCDesign.FontToken.sans(size: 13, weight: .semibold))
            .padding(.horizontal, AUCDesign.Space.md)
            .padding(.vertical, 9)
            .background(configuration.isPressed ? AUCDesign.ColorToken.violetDark : AUCDesign.ColorToken.violet)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: AUCDesign.Radius.md, style: .continuous))
            .shadow(color: AUCDesign.ColorToken.violet.opacity(configuration.isPressed ? 0.18 : 0.28), radius: 9)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AUCDesign.FontToken.sans(size: 13, weight: .semibold))
            .padding(.horizontal, AUCDesign.Space.md)
            .padding(.vertical, 9)
            .background(configuration.isPressed ? AUCDesign.ColorToken.panelStrong : AUCDesign.ColorToken.panel)
            .foregroundStyle(AUCDesign.ColorToken.textPrimary)
            .clipShape(RoundedRectangle(cornerRadius: AUCDesign.Radius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AUCDesign.Radius.md, style: .continuous)
                    .stroke(AUCDesign.ColorToken.stroke, lineWidth: 1)
            }
    }
}

struct IconCircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AUCDesign.FontToken.sans(size: 14, weight: .semibold))
            .frame(width: 34, height: 34)
            .background(configuration.isPressed ? AUCDesign.ColorToken.panelStrong : AUCDesign.ColorToken.panel)
            .foregroundStyle(AUCDesign.ColorToken.textPrimary)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(AUCDesign.ColorToken.stroke, lineWidth: 1)
            }
    }
}
