import SwiftUI

/// 24pt circular spinner. Used while a prompt loads and while Replace writes.
struct BeruLoader: View {
    var tint: Color = BeruColor.accent

    var body: some View {
        ProgressView()
            .progressViewStyle(.circular)
            .controlSize(.regular)
            .tint(tint)
            .frame(width: BeruMetrics.loaderSize, height: BeruMetrics.loaderSize)
            .accessibilityLabel("Loading")
    }
}
