import SwiftUI
import UIKit

extension Color {
    init(hex: Int) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension AppTheme {
    static let blueColor = Color(hex: blue)
    static let darkBlueColor = Color(hex: darkBlue)
    static let goldColor = Color(hex: gold)
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x071B4A), Color(hex: 0x0A2D73), Color(hex: 0x061538)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(AppTheme.blueColor.opacity(0.32))
                .frame(width: 340, height: 340)
                .blur(radius: 90)
                .offset(x: 150, y: -260)
            Circle()
                .fill(Color.cyan.opacity(0.12))
                .frame(width: 280, height: 280)
                .blur(radius: 100)
                .offset(x: -170, y: 300)
        }
        .ignoresSafeArea()
    }
}

struct AppScreen<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            AppBackground()
            content
        }
        .foregroundStyle(.white)
    }
}

struct PremiumCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
            .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 22))
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.white.opacity(0.24), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.22), radius: 18, y: 10)
            .foregroundStyle(.white)
    }
}

struct GlassField<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
            content
                .padding(.horizontal, 12)
                .frame(minHeight: 46)
                .background(Color.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                }
        }
    }
}

struct GlassFormBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .foregroundStyle(.white)
    }
}

enum AssetScalingMode {
    case cover
    case contain
    case fill
}

struct AssetImageView: View {
    let name: String
    var mode: AssetScalingMode = .contain
    var cornerRadius: CGFloat = 16

    var body: some View {
        Group {
            if UIImage(named: name) != nil {
                image
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.secondary.opacity(0.12))
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                        .foregroundStyle(.secondary)
                    VStack(spacing: 6) {
                        Image(systemName: "photo")
                            .font(.title2)
                        Text(name)
                            .font(.caption2.monospaced())
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .minimumScaleFactor(0.6)
                            .padding(.horizontal, 8)
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .accessibilityLabel(Text(name))
    }

    @ViewBuilder
    private var image: some View {
        switch mode {
        case .cover:
            Image(name).resizable().scaledToFill()
        case .contain:
            Image(name).resizable().scaledToFit()
        case .fill:
            Image(name).resizable()
        }
    }
}

struct EmptyStateView: View {
    let systemImage: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .foregroundStyle(.white)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        }
    }
}

struct KeyboardDoneToolbar: ViewModifier {
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("common.done") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil,
                        from: nil,
                        for: nil
                    )
                }
            }
        }
    }
}

extension View {
    func keyboardDoneToolbar() -> some View {
        modifier(KeyboardDoneToolbar())
    }

    func glassFormBackground() -> some View {
        modifier(GlassFormBackground())
    }

    func serifTitle() -> some View {
        font(.system(.title3, design: .serif, weight: .bold))
    }
}

struct ParticipantAvatar: View {
    let participant: FamilyParticipant
    var size: CGFloat = 64

    var body: some View {
        Group {
            if let data = participant.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(AppTheme.goldColor.opacity(0.22))
                    Text(participant.emoji.isEmpty ? "🙂" : participant.emoji)
                        .font(.system(size: size * 0.45))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(AppTheme.goldColor, lineWidth: 2))
        .accessibilityLabel(participant.name)
    }
}

struct AdultNoticeView: View {
    var body: some View {
        PremiumCard {
            Label {
                Text("responsible.notice")
                    .font(.footnote)
            } icon: {
                Image(systemName: "18.circle.fill")
                    .foregroundStyle(AppTheme.goldColor)
            }
        }
    }
}
