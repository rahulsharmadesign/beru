import Foundation

/// Builds and launches the swap script that replaces the running app bundle.
///
/// Split out of `AppUpdateService` because this is the most dangerous code in
/// the product: it runs unattended, as the user, and deletes an application
/// directory. Three properties it must hold, each of which the earlier version
/// did not:
///
/// 1. **Unpredictable script location.** The script used to be written to a
///    fixed name in the shared temporary directory. Any process running as the
///    user could pre-create or symlink that path and have its own content
///    executed. It now lives in a `0700` directory with a random name.
/// 2. **Never destroy before the replacement is proven.** The old script ran
///    `rm -rf "$DEST"` and only then copied. A failed or interrupted copy left
///    the user with no application at all. The new script copies to a staging
///    path beside the destination, verifies it, moves the old bundle aside,
///    swaps the new one in, and restores the original if any step fails.
/// 3. **Verify the payload before trusting it.** The downloaded bundle's code
///    signature must be valid, and its identity must match the running app.
enum AppUpdateInstaller {
    struct Payload {
        let dmgPath: String
        let destinationPath: String
        let bundleIdentifier: String
        let processIdentifier: Int32
        /// Leaf certificate common name of the running app, when it has one.
        /// Ad-hoc signed local builds have none, so the check degrades to
        /// "signature must be structurally valid" rather than failing outright.
        let expectedLeafName: String?
    }

    /// Renders the swap script. Pure, so its shape can be asserted in tests
    /// without running anything.
    static func script(for payload: Payload) -> String {
        // Every value is single-quoted for the shell, so a path or certificate
        // name containing `"`, `$`, or backticks is data, never code.
        return """
        #!/bin/bash
        set -euo pipefail

        PID=\(payload.processIdentifier)
        DMG=\(shellQuoted(payload.dmgPath))
        DEST=\(shellQuoted(payload.destinationPath))
        WANT_ID=\(shellQuoted(payload.bundleIdentifier))
        WANT_LEAF=\(shellQuoted(payload.expectedLeafName ?? ""))

        STAGE="$DEST.enhancify-staged"
        BACKUP="$DEST.enhancify-backup"
        MOUNT=""

        cleanup() {
          if [[ -n "$MOUNT" ]]; then hdiutil detach "$MOUNT" -quiet || true; fi
          rm -rf "$STAGE"
        }

        # Any failure before the swap leaves the original untouched. Any failure
        # during the swap restores it. The user always ends with a working app.
        restore() {
          if [[ -d "$BACKUP" && ! -d "$DEST" ]]; then
            mv "$BACKUP" "$DEST" || true
          fi
          cleanup
          exit 1
        }
        trap restore ERR

        # Wait for the app to exit so the bundle is not in use.
        for _ in $(seq 1 150); do
          kill -0 "$PID" 2>/dev/null || break
          sleep 0.2
        done
        sleep 0.5

        MOUNT=$(hdiutil attach -nobrowse -readonly "$DMG" | grep -o '/Volumes/[^ ]*' | tail -1)
        if [[ -z "$MOUNT" ]]; then exit 1; fi

        SRC=$(find "$MOUNT" -maxdepth 2 -name 'Enhancify.app' -print -quit)
        if [[ -z "$SRC" || ! -d "$SRC" ]]; then cleanup; exit 1; fi

        # --- verify the payload BEFORE touching the installed app -------------
        if ! codesign --verify --deep --strict "$SRC" 2>/dev/null; then
          cleanup; exit 1
        fi

        GOT_ID=$(defaults read "$SRC/Contents/Info" CFBundleIdentifier 2>/dev/null || echo "")
        if [[ "$GOT_ID" != "$WANT_ID" ]]; then cleanup; exit 1; fi

        if [[ -n "$WANT_LEAF" ]]; then
          GOT_LEAF=$(codesign -dvvv "$SRC" 2>&1 | sed -n 's/^Authority=//p' | head -1)
          if [[ "$GOT_LEAF" != "$WANT_LEAF" ]]; then cleanup; exit 1; fi
        fi

        # --- stage, then swap -------------------------------------------------
        rm -rf "$STAGE" "$BACKUP"
        cp -R "$SRC" "$STAGE"
        xattr -cr "$STAGE" || true

        # Staged copy must itself be valid; a truncated copy passes cp but not this.
        if ! codesign --verify --deep --strict "$STAGE" 2>/dev/null; then
          cleanup; exit 1
        fi

        if [[ -d "$DEST" ]]; then mv "$DEST" "$BACKUP"; fi
        mv "$STAGE" "$DEST"

        trap - ERR
        rm -rf "$BACKUP"
        if [[ -n "$MOUNT" ]]; then hdiutil detach "$MOUNT" -quiet || true; fi
        rm -f "$DMG"
        open "$DEST"
        rm -rf "$(dirname "$0")"
        """
    }

    /// POSIX single-quoting: wrap in `'`, and close-escape-reopen any `'`.
    static func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Writes the script into a freshly created private directory and returns
    /// its URL. The directory name is random and mode `0700`, so the path cannot
    /// be predicted or pre-created by another process running as the user.
    static func writeScript(_ contents: String, using fileManager: FileManager = .default) throws -> URL {
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("enhancify-update-\(UUID().uuidString)", isDirectory: true)

        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )

        let scriptURL = directory.appendingPathComponent("apply-update.sh")
        try contents.write(to: scriptURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)
        return scriptURL
    }
}
