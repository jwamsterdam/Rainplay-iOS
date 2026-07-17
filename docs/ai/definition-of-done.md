# Definition of Done

A change is **Done** only when every applicable item below is satisfied. This is
the shared contract for the Software Architect, Developer, and Test Engineer
agents. If an item cannot be met, say so explicitly and explain why — do not
silently skip it.

## 1. Behavior
- The change implements the requested behavior and nothing outside its scope.
- Edge cases are handled (empty hourly ranges, night hours, missing probability,
  bad coordinates, network timeout/offline, out-of-range windows).
- User-facing copy stays Dutch, calm, and fits narrow iPhone screens.

## 2. Build & linters
- The project builds cleanly for the iOS Simulator (Xcode `BuildProject`, or
  `xcodebuild build`), with no new warnings introduced by the change.
- **SwiftLint reports no violations** on the change (`swiftlint lint --quiet`).
- **SwiftFormat lint is clean** on the change (`swiftformat --lint .`).
- Both run as Xcode build-phase warnings; autofix with `swiftlint --fix` and
  `swiftformat .`. Config lives in `.swiftlint.yml` and `.swiftformat`.

## 3. Tests
- New or changed domain logic (`Logic/`), mappers (`Services/`), and state has
  behavior-oriented tests (Swift Testing framework).
- The full test suite passes **locally** (Xcode ⌘U or `xcodebuild test`) — this
  is required before a change is done. CI (`.github/workflows/ci.yml`) is
  **lint-only** (SwiftLint + SwiftFormat) because GitHub runners can't open the
  Xcode 27 project format; it does not run the suite, so the local run is the
  gate. That CI run must still be green.
- No test was weakened or deleted to make the suite pass; any corrected
  assertion is explained.

## 4. Code quality (SonarCloud)
- **New code introduces no new SonarCloud issues** on the changed files
  (bugs, vulnerabilities, code smells, security hotspots).
- **All SonarCloud issues on the change are resolved in code, or explicitly
  and justifiably marked "Accept" / "Won't Fix"** in SonarCloud with a reason —
  never left open and unaddressed.
- The project **Quality Gate passes** for the analysis covering the change.
- Security hotspots on the change are reviewed and marked Safe/Fixed, not left
  "To Review".
- Verify via the read-only SonarCloud Web API (see the SonarCloud section in
  `.claude/agents/test-engineer.md`); e.g. quality-gate status and an issues
  search scoped to the changed files. Note: Automatic Analysis refreshes on
  push, so the definitive check is the analysis of the pushed commit.

## 5. Architecture
- The change fits existing patterns and layer boundaries (`Logic/` pure domain,
  `Services/` external I/O, `State/` app state, `Views/` presentation).
- No decision logic is duplicated in views; derived values live in `Logic/`.
- Any new production dependency is approved by the Software Architect per the
  dependency policy in `AGENTS.md`.

## 6. Accessibility
- Interactive UI has meaningful labels, correct traits, adequate touch targets,
  and supports Dynamic Type where text is shown.

## 7. Localization & locale
- **No hardcoded user-facing text.** Every new string is a `LocalizedStringKey`
  (or `LocalizedStringResource` off the view), with an entry in
  `Localizable.xcstrings` — English source **and** Dutch — with a translator
  comment. Never build sentences by concatenation; use placeholders (`%@`, `%lld`).
- Domain layer stays presentation-free: `Logic/`/`Models/` emit semantic tokens
  (e.g. `OutdoorSummary`, `DayPeriod`, `WeatherKind`), localized only in
  `Views/Formatting/LocalizedLabels.swift`.
- Units and date/time honor the user's Settings choices and fall back to the
  locale for `.system` (see `MeasurementFormatting` / `TimeFormatting`); no
  locale hardcoded in `Logic/`.
- Enum `rawValue`s used for persistence/identity are never displayed directly —
  display goes through a localized `titleKey`.

## 8. Change hygiene
- The diff is focused; no unrelated rewrites or formatting churn.
- Existing worktree edits by the user/teammates are preserved.

## 9. Reporting
- The final response lists: changed files, commands run and their results,
  SonarCloud status for the change, known risks, and remaining follow-ups.

## Quality gate summary
Done requires, at minimum:
- tests pass;
- build is green;
- SwiftLint and SwiftFormat report no issues on the change;
- no hardcoded user-facing text — new strings are in Localizable.xcstrings (en + nl);
- Test Engineer: no blocking issues;
- Software Architect: no blocking issues;
- SonarCloud: quality gate green, no new issues, all issues resolved or
  explicitly accepted;
- any new dependency justified and accepted.
