import AppKit
import SwiftUI

/// Notes-style titlebar: traffic discs left, active-context title centered,
/// a glass pill of icon actions right. 28pt strip, full-bleed to the rounded
/// top; only its own content keeps the 10pt side insets so the gaps stay the
/// window-drag region. No animation lives here — the window animator owns
/// every move.
struct PanelTitlebar: View {
    let title: String
    var isZoomed: Bool
    var pinEnabled: Bool
    let onClose: () -> Void
    let onZoom: () -> Void
    let onNewSession: () -> Void
    let onPin: () -> Void
    let onVault: () -> Void
    let onSettings: () -> Void

    var body: some View {
        ZStack {
            Text(title)
                .font(BeruType.titlebarTitle)
                .foregroundStyle(BeruColor.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, PanelMetrics.titlebarTitleClearance)
                .allowsHitTesting(false)

            HStack(spacing: 0) {
                HStack(spacing: BeruSpace.xs) {
                    PanelCloseDot(action: onClose)
                    PanelZoomDot(isZoomed: isZoomed, action: onZoom)
                }
                Spacer(minLength: 0)
                PanelUpdateButton()
                    .padding(.trailing, BeruSpace.xs)
                PanelToolPill {
                    PanelIconHitButton(icon: "plus", help: "New session", action: onNewSession)
                    PanelIconHitButton(icon: "pin", help: "Pin", enabled: pinEnabled, action: onPin)
                    PanelIconHitButton(icon: "folder", help: "Open Vault", action: onVault)
                    PanelSettingsLink(action: onSettings)
                }
            }
        }
        .frame(height: PanelMetrics.closeStripHeight)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, PanelMetrics.moduleInset)
        // Gaps around the title and controls stay the window-drag region;
        // the discs and pill carry their own AppKit hit targets above it.
        .background(PanelDragRegion())
    }
}

/// Icon actions grouped on one solid capsule. `beruOverlayCapsule` is the
/// sanctioned slab pill: an opaque plate, never a second glass lens, and it
/// stays legible under Reduce Transparency.
struct PanelToolPill<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 0) {
            content
        }
        .padding(.horizontal, BeruSpace.hair)
        .frame(height: PanelMetrics.toolPillHeight)
        .beruOverlayCapsule()
    }
}
