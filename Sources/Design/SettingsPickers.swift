import SwiftUI

// Haze pickers and menus for settings: capsule triggers over native menus.
// `Picker(.menu)` and `.segmented` stay out so every dropdown reads as one
// pill-first language.
//
// The trigger is our own Button presenting an NSMenu. SwiftUI `Menu` cannot
// carry this look on Tahoe: its AppKit host strips every visual in the label
// except plain text (fills, strokes, shapes) and re-tints glyphs with the
// accent, so a styled Menu label renders as bare text.

/// One entry in a dropdown. `isOn` draws the checkmark; `isSeparator` draws
/// a divider and ignores every other field.
struct DropdownItem: Identifiable {
    let id = UUID()
    let title: String
    var isOn: Bool = false
    var isEnabled: Bool = true
    var isSeparator: Bool = false
    var action: () -> Void = {}

    static func separator() -> DropdownItem {
        var item = DropdownItem(title: "")
        item.isSeparator = true
        return item
    }
}

/// AppKit anchor the popup panel hangs off. Lives in the pill's background
/// so it tracks the pill's window position.
final class DropdownAnchorView: NSView {
    func open(_ items: [DropdownItem], preferred index: Int?) {
        DropdownPopup.toggle(anchor: self, items: items)
    }
}

private struct DropdownAnchor: NSViewRepresentable {
    let view: DropdownAnchorView

    func makeNSView(context: Context) -> DropdownAnchorView { view }
    func updateNSView(_ view: DropdownAnchorView, context: Context) {}
}

/// Chevron drawn as a stroked shape: font glyphs and template images get
/// re-tinted by AppKit hosts, a plain vector path does not. Narrower and
/// taller than the pill box so it reads as Lucide's chevron, not a wide flat
/// check.
private struct MenuChevron: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.20, y: rect.minY + rect.height * 0.32))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.32))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.20, y: rect.minY + rect.height * 0.32))
        return path
    }
}

/// Haze dropdown pill: our own capsule trigger over a native popup menu.
/// The shared machinery for `SettingsMenuPicker`, `SettingsMenuPill`, and
/// `SettingsOverflowMenu`.
struct DropdownPill: View {
    let title: String
    let items: [DropdownItem]
    var height: CGFloat = EnhancifyMetrics.pillHeight
    var horizontalPadding: CGFloat = EnhancifySpace.md
    var accessibilityLabel: String = ""

    @State private var anchor = DropdownAnchorView()
    @State private var isHovered = false

    var body: some View {
        Button {
            anchor.open(items, preferred: items.firstIndex(where: { $0.isOn }))
        } label: {
            HStack(spacing: EnhancifySpace.xxs) {
                Text(title)
                    .font(EnhancifyType.control)
                    .foregroundStyle(EnhancifyColor.textPrimary)
                    .lineLimit(1)
                MenuChevron()
                    .stroke(
                        EnhancifyColor.textSecondary,
                        style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: EnhancifyMetrics.iconSizeDense, height: EnhancifyMetrics.iconSizeDense)
            }
            .padding(.horizontal, horizontalPadding)
            .frame(height: height)
            .background {
                Capsule().fill(isHovered ? EnhancifyColor.hoverFill : Color.clear)
            }
            .overlay {
                Capsule().strokeBorder(EnhancifyColor.strongBorder, lineWidth: EnhancifyMetrics.hairline)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background { DropdownAnchor(view: anchor) }
        .onHover { isHovered = $0 }
        .enhancifyHoverEase(isHovered)
        .accessibilityLabel(accessibilityLabel.isEmpty ? title : accessibilityLabel)
        .accessibilityValue(title)
    }
}

/// One choice in a `SettingsMenuPicker` or `SettingsSegmented`.
struct SettingsPickerOption<Value: Hashable>: Identifiable {
    var id: Value { value }
    let value: Value
    let title: String
}

/// Haze picker: pill trigger over a native menu. Replaces `Picker(.menu)`.
struct SettingsMenuPicker<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [SettingsPickerOption<Value>]
    var accessibilityLabel: String

    private var title: String {
        options.first { $0.value == selection }?.title ?? ""
    }

    var body: some View {
        DropdownPill(
            title: title,
            items: options.map { option in
                DropdownItem(
                    title: option.title,
                    isOn: option.value == selection,
                    action: { selection = option.value }
                )
            },
            accessibilityLabel: accessibilityLabel
        )
    }
}

/// Haze menu pill with a caller-computed label, e.g. the Runs filter pills.
struct SettingsMenuPill: View {
    let label: String
    let items: [DropdownItem]
    var accessibilityLabel: String = ""

    var body: some View {
        DropdownPill(
            title: label,
            items: items,
            accessibilityLabel: accessibilityLabel
        )
    }
}

/// Action menu for toolbars and rows (Folder, Use for). Same 32pt pill as
/// every other control so toolbar rows hold one height.
struct SettingsOverflowMenu: View {
    let title: String
    let items: [DropdownItem]

    var body: some View {
        DropdownPill(
            title: title,
            items: items,
            accessibilityLabel: title
        )
    }
}

/// Haze segmented control: capsule track, solid selected chip.
/// Replaces `Picker(.segmented)`. The selected fill travels between options
/// with the same spring as panel tabs (Animate UI highlight).
struct SettingsSegmented<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [SettingsPickerOption<Value>]
    var accessibilityLabel: String

    @Namespace private var segmentHighlight
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: EnhancifySpace.hair) {
            ForEach(options) { option in
                let selected = selection == option.value
                Button {
                    selection = option.value
                } label: {
                    Text(option.title)
                        .font(EnhancifyType.footnoteMedium)
                        .foregroundStyle(selected ? EnhancifyColor.textPrimary : EnhancifyColor.textSecondary)
                        .lineLimit(1)
                        .padding(.horizontal, EnhancifySpace.sm)
                        .frame(minHeight: EnhancifyMetrics.pillHeightSm)
                        .background {
                            if selected {
                                Capsule()
                                    .fill(EnhancifyColor.panelSolid)
                                    .overlay {
                                        // panelSolid reads white in light mode; a
                                        // plain hairline vanishes on it, so the
                                        // chip takes the strong stroke.
                                        Capsule().strokeBorder(EnhancifyColor.strongBorder, lineWidth: EnhancifyMetrics.hairline)
                                    }
                                    .matchedGeometryEffect(id: "segmentHighlight", in: segmentHighlight)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(EnhancifySpace.hair)
        .background {
            Capsule().fill(EnhancifyColor.subtleFill)
        }
        .fixedSize()
        .animation(reduceMotion ? nil : EnhancifyMotion.tabSwitchAnimation, value: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }
}
