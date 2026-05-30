# Fitness50 Native iOS Status

Fitness50 is now a native SwiftUI iOS app. The old React/Vite PWA and Web Push infrastructure have been removed from the repository.

## Implemented Feature Parity

- 12-week beginner program with foundation, capacity, and momentum phases.
- Date-derived daily workout plans.
- Completion and skip tracking.
- Recovery check-in with soreness, energy, sleep, and joint pain inputs.
- Recovery-based volume adjustment and easier-today mode.
- Workout detail screen with formatted exercise targets.
- Weekly view with last-7-day consistency and rolling 30-day movement count.
- Ad-hoc activity support through timers.
- Standalone timer with activity type, label, duration presets, custom duration, foreground countdown, and local notification.
- Workout timer prefill from workout duration, label, type, and source workout ID.
- Fired timer prompts that can log standalone timers as ad-hoc activities or mark source workouts complete.

## Current Architecture

The app is local-only and stores `AppState` as JSON in the app documents directory.

```text
ios/Fitness50/
  Fitness50App.swift
  Models/AppModels.swift
  Domain/Program.swift
  Domain/Progression.swift
  Domain/SessionStore.swift
  Domain/TimerScheduler.swift
  Views/ContentView.swift
  Views/TodayView.swift
  Views/WorkoutView.swift
  Views/WeekView.swift
  Views/RecoveryView.swift
  Views/TimerView.swift
  Views/SharedViews.swift
  Resources/Assets.xcassets
```

## Verification

Build with:

```sh
xcodebuild -project ios/Fitness50.xcodeproj -scheme Fitness50 -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/fitness50-derived build
```

## Later Enhancements

- Daily workout reminders.
- Apple Health write support.
- Home Screen widget.
- Live Activity for active timers.
- Data export/import.
