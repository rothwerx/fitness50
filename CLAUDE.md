# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Commands

- `xcodebuild -project ios/Fitness50.xcodeproj -scheme Fitness50 -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/fitness50-derived build` - build and typecheck the native iOS app.

There is no separate test target yet. Use the Xcode build as the verification step.

## Architecture

Fitness50 is now a native SwiftUI iOS app. The previous React/Vite PWA, service worker, Pages Functions, and Cloudflare Worker timer infrastructure were removed after the native app reached feature parity.

The app is local-only. State is persisted as JSON in the app documents directory at `fitness50-state.json`; there is no backend.

Key files:

- `ios/Fitness50/Models/AppModels.swift` - `AppState`, `DailySession`, `Workout`, `Exercise`, `UserProfile`, and timer models.
- `ios/Fitness50/Domain/Program.swift` - the 12-week beginner program. Weeks 1-4 are `foundation`, 5-8 are `capacity`, and 9-12 are `momentum` with the week capped at 12. `Program.plan(startDate:date:)` derives workout IDs for a day, and `Program.workout(id:startDate:date:)` builds phase-specific workout details.
- `ios/Fitness50/Domain/Progression.swift` - recovery advice, volume modifiers, target formatting, and rolling stats.
- `ios/Fitness50/Domain/SessionStore.swift` - state loading/saving, session derivation, workout completion/skip mutations, recovery updates, and timer logging.
- `ios/Fitness50/Domain/TimerScheduler.swift` - native local notification scheduling/cancellation for timers.
- `ios/Fitness50/Views/` - SwiftUI screens for Today, Workout, Week, Recovery, Timer, and shared view components.

Important behavior:

- `plannedWorkouts` is derived from `startDate` and date, not stored as source of truth.
- Saved completions/skips are filtered against the current plan when reading a session.
- Recovery advice changes displayed workout target volume.
- UI exercise targets must go through `Progression.formatTarget(for:modifier:)`.
- State changes should flow through `SessionStore`; do not bypass it with direct file writes from views.
- Timers store an absolute `fireAt`, derive countdown from wall-clock time, and use local notifications rather than Web Push.
