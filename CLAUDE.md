# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

- `npm run dev` — Vite dev server (binds 0.0.0.0)
- `npm run build` — `tsc` typecheck, then `vite build`
- `npm run preview` — preview the built bundle

There is no test runner, linter, or formatter configured. `npm run build` is the only verification step; the `tsc` pass enforces `strict` TypeScript.

## Architecture

Single-page React 19 PWA written in TypeScript and bundled with Vite. State is held entirely in `localStorage` under key `fitness50-state`; there is no backend. PWA support comes from `public/manifest.webmanifest` and `public/service-worker.js` (cache-first app-shell strategy, registered from `main.tsx`).

The whole UI lives in [src/main.tsx](src/main.tsx) — `App` is a screen-switcher (`today` / `workout` / `week` / `recovery`) with all sub-screens defined in the same file. There is no router and no component directory.

Domain logic is split into four small modules; understand them together before changing behavior:

- [src/types.ts](src/types.ts) — `AppState`, `DailySession`, `Workout`, `Exercise`, `UserProfile`. `DailySession` is the per-day record; `plannedWorkouts` is derived on read (see storage.ts), not stored.
- [src/program.ts](src/program.ts) — the 12-week beginner program. Three phases keyed off week number: weeks 1–4 `foundation`, 5–8 `capacity`, 9–12 `momentum` (capped at 12). Each phase has a 7-day `weeklyTemplates` array mapping `dayIndex % 7 → workout IDs`. `planForDate(startDate, date)` returns the IDs for that date; `getWorkoutForDate(workoutId, startDate, date)` builds the actual `Workout` via `workoutFactories`, so rep/round counts are computed from the current phase rather than stored statically. `workoutLibrary` only exists as a foundation-week snapshot for `beginnerProgram`.
- [src/progression.ts](src/progression.ts) — `getRecoveryAdvice(session)` returns one of three levels (`steady` / `easier` / `recovery`) with a `volumeModifier` (1.0 / 0.85 / 0.7). The `WorkoutScreen` multiplies this by an additional 0.85 if `state.easierToday` is on, then `applyVolume` rounds reps/duration. Any UI that displays exercise targets must go through `formatExerciseTarget` so the modifier is applied.
- [src/storage.ts](src/storage.ts) — `loadState` / `saveState` / `getSession` / `upsertSession`. `getSession` always re-runs `planForDate` and filters saved `completedWorkouts` / `skippedWorkouts` to the current plan, so changing the weekly template won't leave dangling completions in old sessions. `loadState` spreads `defaultState()` over the parsed JSON, which is how new fields are migrated for existing users — add defaults there when extending `AppState`.

State flow: `App` loads once via `useState(() => loadState())` and persists on every change via `useEffect(() => saveState(state), [state])`. All mutations funnel through `setState` + `upsertSession`; do not write to `localStorage` directly elsewhere.

Styling is a single hand-written stylesheet at [src/styles.css](src/styles.css) — no CSS framework, no CSS-in-JS. Icons come from `lucide-react`.
