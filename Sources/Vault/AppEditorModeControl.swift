import SwiftUI

/// Edit/Preview segmented pill for the Vault's markdown editor, its only user.
struct AppEditorModeControl: View {
    @Binding var showingPreview: Bool

    var body: some View {
        HStack(spacing: BeruSpace.hair) {
            mode("Edit", active: !showingPreview) { showingPreview = false }
            mode("Preview", active: showingPreview) { showingPreview = true }
        }
        .padding(BeruSpace.hair)
        .background(BeruColor.badge, in: Capsule())
        .fixedSize()
    }

    private func mode(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(BeruType.control)
                .fontWeight(.medium)
                .lineLimit(1)
                .foregroundStyle(active ? BeruColor.onAccent : BeruColor.textPrimary)
                .padding(.horizontal, BeruSpace.sm)
                .padding(.vertical, BeruSpace.xxs)
                .background(active ? BeruColor.accent : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .fixedSize()
    }
}
