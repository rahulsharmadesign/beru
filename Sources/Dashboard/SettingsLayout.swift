import SwiftUI

// Page scaffolding for the dashboard: the shells every route builds inside.
// The reusable controls these pages fill themselves with live in
// Sources/Design/SettingsControls.swift.

struct SettingsHeaderRule: View {
    var body: some View {
        Rectangle()
            .fill(EnhancifyColor.border)
            .frame(height: EnhancifyMetrics.hairline)
            .frame(maxWidth: .infinity)
    }
}

struct SettingsPage<Content: View>: View {
    let title: String
    let subtitle: String
    var icon: String?
    var content: Content

    init(title: String, subtitle: String = "", icon: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: EnhancifyMetrics.headerContentSpacing) {
                SettingsPageHeader(title: title, subtitle: subtitle, icon: icon)
                SettingsHeaderRule()
            }
            .padding(.bottom, EnhancifyMetrics.headerContentSpacing)
            .fixedSize(horizontal: false, vertical: true)
            ScrollView {
                // Explicit stack: a bare ViewBuilder lays sections out with
                // zero gap, so wells would touch edge to edge.
                VStack(alignment: .leading, spacing: EnhancifySpace.xl) {
                    content
                }
                .padding(.top, EnhancifyMetrics.headerContentSpacing)
                .padding(.bottom, EnhancifySpace.xxl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollContentBackground(.hidden)
            .scrollEdgeEffectStyle(.none, for: .vertical)
        }
        // One readable column, centered in the detail pane. Without the cap a
        // 1180pt window stretches every row to full bleed.
        .frame(maxWidth: EnhancifyMetrics.formMaxWidth, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, EnhancifyMetrics.contentPadding)
        .padding(.top, EnhancifySpace.xl)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

struct SettingsPageHeader: View {
    let title: String
    var subtitle: String = ""
    var icon: String? = nil

    var body: some View {
        HStack(alignment: .center, spacing: EnhancifySpace.md) {
            if let icon {
                // Outlined 28pt tile, accent glyph — same size as the sidebar
                // squircle, so the page announces its route before its title.
                ZStack {
                    EnhancifyRadius.shape(EnhancifyRadius.sm)
                        .fill(Color.clear)
                        .overlay {
                            EnhancifyRadius.shape(EnhancifyRadius.sm)
                                .strokeBorder(EnhancifyColor.strongBorder, lineWidth: EnhancifyMetrics.hairline)
                        }
                    EnhancifyIcon(name: icon, size: EnhancifyMetrics.iconSize)
                        .foregroundStyle(EnhancifyColor.accent)
                }
                .frame(width: EnhancifyMetrics.hitTarget, height: EnhancifyMetrics.hitTarget)
            }
            VStack(alignment: .leading, spacing: EnhancifySpace.xxs) {
                Text(title)
                    .font(EnhancifyType.pageTitle)
                    .foregroundStyle(EnhancifyColor.textPrimary)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(EnhancifyType.pageSubtitle)
                        .foregroundStyle(EnhancifyColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// How a section's well is painted. Danger groups keep the section geometry
/// but swap the Haze fill for the destructive wash.
enum SettingsSectionTone {
    case module
    case danger
}

struct SettingsSection<Content: View>: View {
    let title: String
    let subtitle: String?
    var tone: SettingsSectionTone
    var content: Content

    init(
        title: String,
        subtitle: String? = nil,
        tone: SettingsSectionTone = .module,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.tone = tone
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: EnhancifySpace.sm) {
            VStack(alignment: .leading, spacing: EnhancifySpace.xxs) {
                Text(title)
                    .font(EnhancifyType.section)
                    .foregroundStyle(EnhancifyColor.textPrimary)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(EnhancifyType.footnote)
                        .foregroundStyle(EnhancifyColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            // Grouped rows sit in a Haze well so every page — form pages and
            // workspace inspectors alike — reads as one card language.
            VStack(alignment: .leading, spacing: EnhancifySpace.md) {
                content
            }
            .padding(.horizontal, EnhancifySpace.md)
            .padding(.vertical, EnhancifySpace.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(SectionWell(tone: tone))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SectionWell: ViewModifier {
    let tone: SettingsSectionTone

    func body(content: Content) -> some View {
        switch tone {
        case .module:
            content.settingsModule()
        case .danger:
            content.background {
                EnhancifyRadius.shape(EnhancifyRadius.md)
                    .fill(EnhancifyColor.dangerFill)
                    .overlay {
                        EnhancifyRadius.shape(EnhancifyRadius.md)
                            .strokeBorder(EnhancifyColor.dangerBorder, lineWidth: EnhancifyMetrics.hairline)
                    }
            }
        }
    }
}

struct SettingsFootnote: View {
    let text: String

    var body: some View {
        Text(text)
            .font(EnhancifyType.footnote)
            .foregroundStyle(EnhancifyColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct SettingsRow<Control: View>: View {
    let title: String
    var caption: String?
    @ViewBuilder var control: Control

    var body: some View {
        ViewThatFits(in: .horizontal) {
            horizontalLayout
            verticalLayout
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var labels: some View {
        VStack(alignment: .leading, spacing: EnhancifySpace.hair) {
            Text(title)
                .font(EnhancifyType.rowTitle)
                .foregroundStyle(EnhancifyColor.textPrimary)
            if let caption, !caption.isEmpty {
                Text(caption)
                    .font(EnhancifyType.footnote)
                    .foregroundStyle(EnhancifyColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var horizontalLayout: some View {
        // Centered: the label block rides the control's vertical center, so a
        // title-only row reads as one line and captioned rows stay balanced.
        HStack(alignment: .center, spacing: EnhancifySpace.lg) {
            labels
                .frame(minWidth: 0, maxWidth: EnhancifyMetrics.labelMaxWidth, alignment: .leading)
            Spacer(minLength: EnhancifySpace.sm)
            control
                .layoutPriority(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var verticalLayout: some View {
        VStack(alignment: .leading, spacing: EnhancifySpace.xs) {
            labels
            // Leading, like System Settings' stacked rows: a trailing-aligned
            // control under a left label reads detached.
            control
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

extension View {

}
