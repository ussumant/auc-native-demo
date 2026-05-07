import SwiftUI
#if canImport(CoreText)
import CoreText
#endif

enum AUCDesign {
    enum ColorToken {
        // Source of truth: agent-computer/accomplish/apps/web/src/client/styles/globals.css.
        // Raw --auc-* tokens.
        static let primary = Color(hex: 0x8B5CF6)
        static let primaryDark = Color(hex: 0x7C3AED)
        static let primaryLight = Color(hex: 0xA78BFA)
        static let primaryVeryLight = Color(hex: 0xC4B5FD)

        static let void = Color(hex: 0x000000)
        static let surface = Color(hex: 0x0A0A0A)
        static let elevated = Color(hex: 0x111111)

        static let n900 = Color(hex: 0xFAFAFA)
        static let n800 = Color(hex: 0xE4E4E7)
        static let n700 = Color(hex: 0xD4D4D8)
        static let n600 = Color(hex: 0xA1A1AA)
        static let n500 = Color(hex: 0x71717A)
        static let n400 = Color(hex: 0x52525B)
        static let n300 = Color(hex: 0x3F3F46)
        static let n200 = Color(hex: 0x27272A)
        static let n100 = Color(hex: 0x18181B)

        static let success = Color(hex: 0x10B981)
        static let warning = Color(hex: 0xF59E0B)
        static let error = Color(hex: 0xEF4444)

        static let borderSubtle = Color.white.opacity(0.08)
        static let borderMedium = Color.white.opacity(0.15)
        static let glowViolet = Color(hex: 0x8B5CF6).opacity(0.40)
        static let glowVioletStrong = Color(hex: 0x8B5CF6).opacity(0.60)

        // Semantic tokens matching Tailwind CSS variables from globals.css.
        static let background = void
        static let foreground = n900
        static let card = elevated
        static let cardForeground = n900
        static let popover = elevated
        static let popoverForeground = n900
        static let primaryForeground = Color.white
        static let secondary = n100
        static let secondaryForeground = n700
        static let muted = n200
        static let mutedForeground = n600
        static let accent = n100
        static let accentForeground = n900
        static let destructive = error
        static let destructiveForeground = Color.white
        static let border = n300
        static let input = n100
        static let ring = primaryLight
        static let warningSubtle = warning.opacity(0.10)
        static let successSubtle = success.opacity(0.10)

        // Provider and todo tokens from tailwind.config.ts + globals.css.
        static let providerBackground = card
        static let providerBackgroundActive = primary.opacity(0.12)
        static let providerBackgroundHover = n100
        static let providerBorderActive = primaryLight
        static let providerAccent = primary
        static let providerAccentText = Color(hex: 0xDDD6FE)
        static let todoProgressPending = n300
        static let todoItemCompleted = n200
        static let todoItemInProgress = card

        // Component aliases used by Swift views.
        static let appBackground = background
        static let sidebar = card.opacity(0.95)
        static let panel = secondary
        static let panelStrong = muted
        static let stroke = borderSubtle
        static let strokeStrong = borderMedium
        static let textPrimary = foreground
        static let textSecondary = mutedForeground
        static let textTertiary = n500
        static let violet = primary
        static let violetDark = primaryDark
        static let violetLight = primaryLight
        static let violetVeryLight = primaryVeryLight
        static let cyan = Color(hex: 0x47C2FF)
        static let green = success
        static let red = error
        static let amber = warning
    }

    enum Space {
        // Tailwind's 4px spacing basis, named for the Swift views.
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let compact: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let xxxl: CGFloat = 64

        // Layout measurements pulled from the Electron shell.
        static let sidebarWidth: CGFloat = 260
        static let activePanelWidth: CGFloat = 340
        static let commandMaxWidth: CGFloat = 720
        static let runDetailMaxWidth: CGFloat = 980
        static let launcherSheetWidth: CGFloat = 820
        static let launcherSheetHeight: CGFloat = 580
        static let launcherIdleWidth: CGFloat = 640
        static let launcherIdleHeight: CGFloat = 76
        static let launcherExpandedWidth: CGFloat = 760
        static let launcherExpandedHeight: CGFloat = 356
        static let launcherPermissionHeight: CGFloat = 304
        static let launcherDoneHeight: CGFloat = 246
        static let launcherMiniWidth: CGFloat = 430
        static let launcherMiniHeight: CGFloat = 76
        static let settingsSheetWidth: CGFloat = 620
        static let settingsSheetHeight: CGFloat = 430
        static let launcherPillWidth: CGFloat = 620
        static let launcherPillActiveWidth: CGFloat = 500
        static let bottomFadeHeight: CGFloat = 120
    }

    enum Radius {
        // --radius: 0.75rem in the web app; Tailwind sm/md/lg/xl all map to it.
        static let base: CGFloat = 12
        static let sm: CGFloat = base
        static let md: CGFloat = base
        static let lg: CGFloat = base
        static let xl: CGFloat = base
        static let xxl: CGFloat = base
        static let card: CGFloat = base
        static let pill: CGFloat = 999
    }

    struct ShadowToken {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    enum Shadow {
        // Mirrors tailwind.config.ts boxShadow tokens.
        static let sm = ShadowToken(color: Color.black.opacity(0.26), radius: 24, x: 0, y: 8)
        static let `default` = ShadowToken(color: Color.black.opacity(0.30), radius: 36, x: 0, y: 12)
        static let md = ShadowToken(color: Color.black.opacity(0.34), radius: 48, x: 0, y: 18)
        static let lg = ShadowToken(color: Color.black.opacity(0.42), radius: 70, x: 0, y: 24)
        static let xl = ShadowToken(color: Color.black.opacity(0.50), radius: 90, x: 0, y: 28)
        static let xxl = ShadowToken(color: Color.black.opacity(0.58), radius: 110, x: 0, y: 32)
        static let card = ShadowToken(color: Color.black.opacity(0.30), radius: 54, x: 0, y: 18)
        static let cardHover = ShadowToken(color: Color.black.opacity(0.40), radius: 72, x: 0, y: 24)
        static let aucGlow = ShadowToken(color: ColorToken.primary.opacity(0.28), radius: 60, x: 0, y: 18)

        // Backward-compatible aliases for current view code.
        static let cardColor = card.color
        static let cardRadius = card.radius
        static let cardY = card.y
        static let cardHoverColor = cardHover.color
        static let aucGlowColor = aucGlow.color
        static let aucGlowRadius = aucGlow.radius
        static let aucGlowY = aucGlow.y
    }

    enum FontToken {
        static let sansFamily = "Space Grotesk"
        static let fallbackSansFamily = "Geist"
        static let displayFamily = "Instrument Serif"
        static let apparatFallbackFamily = "KMR Apparat"

        nonisolated(unsafe) private static var didRegisterFonts = false

        static func registerBundleFonts() {
            #if canImport(CoreText)
            guard !didRegisterFonts else { return }
            didRegisterFonts = true
            guard let fontsURL = Bundle.main.resourceURL?.appendingPathComponent("fonts") else { return }
            guard let enumerator = FileManager.default.enumerator(
                at: fontsURL,
                includingPropertiesForKeys: nil
            ) else { return }

            for case let fontURL as URL in enumerator {
                let ext = fontURL.pathExtension.lowercased()
                guard ext == "ttf" || ext == "otf" else { continue }
                CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
            }
            #endif
        }

        static func sans(size: CGFloat, weight: Font.Weight = .regular) -> Font {
            Font.custom(sansFamily, size: size).weight(weight)
        }

        static func display(size: CGFloat, weight: Font.Weight = .regular) -> Font {
            Font.custom(displayFamily, size: size).weight(weight)
        }

        static func mono(size: CGFloat, weight: Font.Weight = .regular) -> Font {
            Font.system(size: size, weight: weight, design: .monospaced)
        }

        static func systemFallback(size: CGFloat, weight: Font.Weight = .regular) -> Font {
            Font.system(size: size, weight: weight)
        }
    }

    enum Motion {
        static let fast: Double = 0.15
        static let base: Double = 0.20
        static let slow: Double = 0.30
        static let accomplish = Animation.timingCurve(0.16, 1.0, 0.30, 1.0, duration: base)
    }
}

struct GlassPanel: ViewModifier {
    var cornerRadius: CGFloat = AUCDesign.Radius.md

    func body(content: Content) -> some View {
        content
            .background(AUCDesign.ColorToken.card.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AUCDesign.ColorToken.stroke, lineWidth: 1)
            }
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.04))
                    .frame(height: 1)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            .shadow(
                color: AUCDesign.Shadow.card.color,
                radius: AUCDesign.Shadow.card.radius,
                x: AUCDesign.Shadow.card.x,
                y: AUCDesign.Shadow.card.y
            )
    }
}

extension View {
    func aucPanel(cornerRadius: CGFloat = AUCDesign.Radius.md) -> some View {
        modifier(GlassPanel(cornerRadius: cornerRadius))
    }

    func aucShadow(_ token: AUCDesign.ShadowToken) -> some View {
        shadow(color: token.color, radius: token.radius, x: token.x, y: token.y)
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
}
