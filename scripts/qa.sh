#!/usr/bin/env bash
#
# Single QA gate for Beru. Run this before claiming any change is done.
#
#   ./scripts/qa.sh                  static guards + generate + build + test
#   ./scripts/qa.sh --static         guards only (fast, no Xcode)
#   ./scripts/qa.sh --fast           guards + generate + build, skip tests
#   ./scripts/qa.sh --update-baseline  rewrite the ratchet after a migration
#
# The static guards are a ratchet, not a wall. Each guard has a baseline count
# in scripts/qa-baseline.txt; the gate fails when a count goes UP. Migrations
# lower the baseline until it reaches zero. This keeps the gate green on a
# codebase that is mid-refactor while still blocking new debt.

set -uo pipefail

cd "$(dirname "$0")/.." || exit 1
REPO_ROOT="$(pwd)"

BASELINE_FILE="scripts/qa-baseline.txt"
CHECKLIST_FILE="docs/QA-CHECKLIST.md"
SCHEME="Beru"
DESTINATION="platform=macOS"

RUN_STATIC=1
RUN_BUILD=1
RUN_TEST=1
UPDATE_BASELINE=0

case "${1:-}" in
    --static) RUN_BUILD=0; RUN_TEST=0 ;;
    --fast) RUN_TEST=0 ;;
    --update-baseline) UPDATE_BASELINE=1; RUN_BUILD=0; RUN_TEST=0 ;;
    "") ;;
    *) echo "unknown option: $1"; exit 2 ;;
esac

if [ -t 1 ]; then
    BOLD=$'\033[1m'; RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else
    BOLD=""; RED=""; GREEN=""; YELLOW=""; DIM=""; RESET=""
fi

FAILURES=0
LOOSENED=""

say() { printf '%s\n' "$*"; }
stage() { printf '\n%s==> %s%s\n' "$BOLD" "$*" "$RESET"; }
fail() { printf '%s FAIL %s %s\n' "$RED" "$RESET" "$*"; FAILURES=$((FAILURES + 1)); }
pass() { printf '%s pass %s %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '%s warn %s %s\n' "$YELLOW" "$RESET" "$*"; }

# ---------------------------------------------------------------- tool lookup

# xcodegen may be on PATH or vendored under .tools (see README).
find_xcodegen() {
    if command -v xcodegen >/dev/null 2>&1; then
        command -v xcodegen
        return 0
    fi
    if [ -x "$REPO_ROOT/.tools/xcodegen/bin/xcodegen" ]; then
        printf '%s\n' "$REPO_ROOT/.tools/xcodegen/bin/xcodegen"
        return 0
    fi
    return 1
}

# --------------------------------------------------------------- file helpers

# Count regex matches under a path. Extra args are passed to grep, so callers
# can scope with --exclude-dir / --exclude. Deliberately avoids xargs and
# `find -exec +`, which need sysconf(_SC_ARG_MAX) and fail inside sandboxes.
count_matches() {
    local pattern="$1" path="$2"
    shift 2
    local total
    total=$(grep -rhoE "$pattern" "$path" --include='*.swift' "$@" 2>/dev/null | wc -l | tr -d ' ')
    printf '%s\n' "${total:-0}"
}

# Emit "lines path" for every Swift file longer than the limit, longest first.
long_files() {
    local limit="$1"
    find Sources -name '*.swift' -print | while IFS= read -r file; do
        local lines
        lines=$(wc -l < "$file" | tr -d ' ')
        if [ "${lines:-0}" -gt "$limit" ]; then
            printf '%s %s\n' "$lines" "$file"
        fi
    done | sort -rn
}

# ------------------------------------------------------------------- baseline

declare -a GUARD_NAMES=()
declare -a GUARD_COUNTS=()
declare -a GUARD_LABELS=()

baseline_for() {
    local name="$1"
    local value
    value=$(grep -E "^${name}=" "$BASELINE_FILE" 2>/dev/null | head -1 | cut -d= -f2)
    printf '%s\n' "${value:-0}"
}

# Register a guard result and compare it against the ratchet.
guard() {
    local name="$1" count="$2" label="$3"
    local base
    base=$(baseline_for "$name")

    GUARD_NAMES+=("$name")
    GUARD_COUNTS+=("$count")
    GUARD_LABELS+=("$label")

    if [ "$count" -gt "$base" ]; then
        fail "$label: $count (baseline $base) ${DIM}new debt introduced${RESET}"
    elif [ "$count" -lt "$base" ]; then
        pass "$label: $count (was $base) ${DIM}improved${RESET}"
        LOOSENED="$LOOSENED $name"
    else
        pass "$label: $count"
    fi
}

# --------------------------------------------------------- stage 1: guards

run_static_guards() {
    stage "Stage 1/4  static guards"

    # Design tokens: raw font sizes, colors and radii belong in Sources/Design.
    guard system_fonts \
        "$(count_matches '\.font\(\.system\(size:' Sources --exclude-dir=Design)" \
        "raw .system(size:) fonts outside Design"

    guard raw_colors \
        "$(count_matches 'Color\(\.sRGB|Color\(red:|NSColor\(srgbRed:' Sources --exclude-dir=Design)" \
        "raw color literals outside Design"

    guard raw_radius \
        "$(count_matches 'cornerRadius: [0-9]+|cornerRadius\([0-9]+' Sources --exclude-dir=Design)" \
        "numeric corner radii outside Design"

    guard offgrid_spacing \
        "$(offgrid_spacing_count)" \
        "off-grid spacing literals (grid: 0 2 4 8 12 16 24 32 48)"

    # Panel sizing contract: the window measures itself from child height
    # preferences, so a state that fills its parent without contributing a
    # height gets clipped against the toolbar and composer.
    guard panel_infinite_height \
        "$(count_matches 'maxHeight: \.infinity' Sources/Panel)" \
        "maxHeight: .infinity in Sources/Panel"

    # Secrets: KeychainStore is the only sanctioned path, reached via SettingsStore.
    guard keychain_reach \
        "$(count_matches 'KeychainStore\.shared' Sources \
            --exclude=KeychainStore.swift --exclude=SettingsStore.swift)" \
        "KeychainStore.shared outside Settings"

    # Global mutable state: hold the line on new process singletons. Raising
    # this number is a decision, not a formality — say in the commit why the
    # thing cannot be owned by whoever uses it.
    guard shared_singletons \
        "$(count_matches 'static let shared' Sources)" \
        "static let shared declarations"

    # Fake observation. A discarded read only refreshes the view by accident.
    guard discarded_observation \
        "$(count_matches 'let _ = [A-Za-z]+\.shared' Sources)" \
        "discarded let _ = Foo.shared observation hacks"

    guard oversized_files \
        "$(long_files 400 | wc -l | tr -d ' ')" \
        "Swift files over 400 lines"

    if [ -n "$LOOSENED" ]; then
        warn "baseline is now loose for:${LOOSENED}"
        warn "run ./scripts/qa.sh --update-baseline to lock in the improvement"
    fi
}

# Spacing literals that are not on the 4pt grid with 8pt rhythm.
offgrid_spacing_count() {
    grep -rhoE '(spacing: [0-9]+|padding\([0-9]+\)|padding\(\.[a-zA-Z]+, [0-9]+\))' \
        Sources --include='*.swift' --exclude-dir=Design 2>/dev/null \
        | grep -oE '[0-9]+$' \
        | awk 'BEGIN { split("0 2 4 8 12 16 24 32 48", g, " "); for (i in g) ok[g[i]] = 1 }
               !($1 in ok) { n++ }
               END { print n + 0 }'
}

write_baseline() {
    {
        say "# QA ratchet for scripts/qa.sh. Counts may only go down."
        say "# Regenerate with ./scripts/qa.sh --update-baseline"
        local i=0
        while [ "$i" -lt "${#GUARD_NAMES[@]}" ]; do
            say "${GUARD_NAMES[$i]}=${GUARD_COUNTS[$i]}"
            i=$((i + 1))
        done
    } > "$BASELINE_FILE"
    pass "wrote $BASELINE_FILE"
}

# ------------------------------------------------------- stages 2-4: Xcode

run_generate() {
    stage "Stage 2/4  xcodegen generate"
    local xcodegen
    if ! xcodegen=$(find_xcodegen); then
        fail "xcodegen not found (brew install xcodegen, or vendor it at .tools/xcodegen/bin/xcodegen)"
        return 1
    fi
    if "$xcodegen" generate >/tmp/beru-qa-xcodegen.log 2>&1; then
        pass "project generated"
    else
        fail "xcodegen failed, see /tmp/beru-qa-xcodegen.log"
        tail -20 /tmp/beru-qa-xcodegen.log
        return 1
    fi
}

run_build() {
    stage "Stage 3/4  build"
    if xcodebuild -scheme "$SCHEME" -destination "$DESTINATION" build \
        >/tmp/beru-qa-build.log 2>&1; then
        pass "build succeeded"
    else
        fail "build failed"
        grep -E 'error:|warning: .*never used' /tmp/beru-qa-build.log | head -30
        say "${DIM}full log: /tmp/beru-qa-build.log${RESET}"
        return 1
    fi
}

run_tests() {
    stage "Stage 4/4  tests"
    if xcodebuild -scheme "$SCHEME" -destination "$DESTINATION" test \
        >/tmp/beru-qa-test.log 2>&1; then
        pass "$(grep -oE 'Executed [0-9]+ tests, with [0-9]+ tests? skipped and [0-9]+ failures' \
            /tmp/beru-qa-test.log | tail -1)"
    else
        fail "tests failed"
        grep -E 'error:|failed|XCTAssert' /tmp/beru-qa-test.log | head -30
        say "${DIM}full log: /tmp/beru-qa-test.log${RESET}"
        return 1
    fi
}

# ------------------------------------------------------------------- main

say "${BOLD}Beru QA gate${RESET}"

if [ "$RUN_STATIC" -eq 1 ]; then
    run_static_guards
fi

if [ "$UPDATE_BASELINE" -eq 1 ]; then
    stage "updating baseline"
    write_baseline
    exit 0
fi

if [ "$RUN_BUILD" -eq 1 ]; then
    run_generate && run_build
fi

if [ "$RUN_TEST" -eq 1 ] && [ "$FAILURES" -eq 0 ]; then
    run_tests
fi

printf '\n'
if [ "$FAILURES" -ne 0 ]; then
    say "${RED}${BOLD}QA gate failed${RESET} ($FAILURES check(s) failed). Nothing is done until this is green."
    exit 1
fi

say "${GREEN}${BOLD}QA gate passed.${RESET}"

if [ "$RUN_TEST" -eq 1 ] && [ -f "$CHECKLIST_FILE" ]; then
    printf '\n%sAutomated checks cannot see the screen. Now do the manual pass:%s\n\n' "$BOLD" "$RESET"
    cat "$CHECKLIST_FILE"
fi
