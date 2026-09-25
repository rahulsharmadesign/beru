import Foundation

/// The shipped default local model id, and how much memory a local model
/// costs on this Mac. SettingsStore reads the default rather than repeating
/// the string.
///
/// There used to be a three-model install catalog here (Gemma 3 1B, Qwen 3 8B,
/// Qwen 2.5 7B) driving an in-app installer. It is gone on purpose: the 1B
/// entry was too weak for Enhance/Grammar for the app to recommend, and
/// downloading belongs to the Ollama app / `ollama pull` in Terminal, where
/// file variants and sizes are visible. Any installed id can be typed into
/// Settings → Models; the default is only the fresh-install choice.
enum RecommendedOllamaModel {
    /// ~4.7 GB resident. Only the default where that is a small share of RAM.
    static let largeID = "qwen2.5:7b"
    /// ~2 GB resident. The default on 8–16 GB Macs, where a 7B model next to
    /// an editor and a browser pushes macOS into swap and stalls the machine.
    static let compactID = "qwen2.5:3b"
    /// Below this, the 7B default is swapped for the compact one.
    static let largeModelMinimumMemoryGB = 24

    /// One model serving both roles: two different models make Ollama swap
    /// weights in and out when the user switches tabs.
    static var defaultID: String {
        defaultID(physicalMemoryGB: thisMacMemoryGB)
    }

    static func defaultID(physicalMemoryGB: Int) -> String {
        physicalMemoryGB >= largeModelMinimumMemoryGB ? largeID : compactID
    }

    /// Installed RAM, rounded to whole GB.
    static var thisMacMemoryGB: Int {
        Int((Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824).rounded())
    }

    /// Rough resident size of a 4-bit quantized model, read from the size tag
    /// in its id (`qwen2.5:7b` → 7B parameters). Nil when the id carries no
    /// size, so no warning is guessed for it.
    static func estimatedResidentGB(forModel model: String) -> Double? {
        let id = model.lowercased()
        guard let range = id.range(of: #"(\d+(\.\d+)?)b\b"#, options: .regularExpression) else {
            return nil
        }
        guard let billions = Double(id[range].dropLast()), billions > 0 else { return nil }
        // Q4 weights are ~0.6 GB per billion parameters, plus runtime and a
        // default-sized context.
        return billions * 0.6 + 0.5
    }

    /// Settings caption when the chosen model is heavy for this Mac. Nil when
    /// it fits comfortably. Pure so the thresholds are testable.
    static func memoryAdvice(model: String, physicalMemoryGB: Int) -> String? {
        if physicalMemoryGB <= 8 {
            return "This Mac has \(physicalMemoryGB) GB of memory. A local model competes with your apps for it and can freeze the Mac — Apple on-device or an API model is the better fit."
        }
        guard let resident = estimatedResidentGB(forModel: model),
              resident > Double(physicalMemoryGB) * 0.25 else { return nil }
        let size = String(format: "%.0f", resident.rounded())
        return "\(model) uses about \(size) GB while loaded, a lot for this Mac's \(physicalMemoryGB) GB. If the Mac slows down, try \(compactID) (about 2 GB), Apple on-device, or an API model."
    }
}
