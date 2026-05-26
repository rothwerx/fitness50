# Standalone timer with push notifications — design

**Date:** 2026-05-26
**Status:** Approved for planning

## Problem

The current in-workout elapsed timer (`WorkoutScreen` in `src/main.tsx`) is a `useState` counter driven by `setInterval`. Browsers throttle and suspend that interval when the tab is backgrounded, so the timer is effectively only useful when the app is in the foreground. The user observed this on their second use of the app.

Beyond the bug, the user has a related need: start a timer for an activity like a 30-minute walk, get a notification when it's done while the phone is in their pocket, and have that activity logged.

## Goals

1. A standalone timer feature: pick a duration and activity type, get a push notification when it fires, log the completion into the day's session.
2. Replace the existing in-workout elapsed timer so the workout screen launches the same standalone timer pre-filled to the workout's `estimatedDuration`.
3. Set up server-side infrastructure on Cloudflare to support Web Push, with minimal disruption to the current Pages-based hosting.

## Non-goals (v1)

- Scheduled daily reminders ("time for today's workout at 7am") — separate future feature.
- Multi-device push fan-out — each install gets notifications for timers started on that install only.
- Multiple concurrent timers UI — data model allows it; v1 UI replaces any running timer if user starts a new one.
- Background-survival of the in-workout *elapsed* counter — being replaced rather than fixed.

## Architecture

```
┌──────────────────┐    POST /api/timers           ┌──────────────────┐
│  PWA (React)     │ ────────────────────────────▶ │  Pages Function  │
│  - TimerScreen   │ ◀──────────────────────────── │  /functions/api  │
│  - Service       │    DELETE /api/timers/:id     │                  │
│    Worker        │                               │   ▼  writes      │
└──────────────────┘                               ┌──────────────────┐
        ▲                                          │  KV namespace    │
        │ push event                               │  TIMERS_KV       │
        │ (Web Push from CF)                       └──────────────────┘
        │                                                  ▲
┌──────────────────┐    every minute                       │
│  Cron Worker     │ ──────────────────────────────────────┘
│  timer-fire      │    scan due, send push, delete
└──────────────────┘
```

Three components:

1. **Existing PWA** gains a new `TimerScreen`, modifications to `WorkoutScreen` and `TodayScreen`, additions to `AppState` and `DailySession`, and push/notificationclick handlers in the service worker.
2. **Pages Functions** (new `/functions/api/timers/`) handle scheduling and cancellation as HTTP endpoints on the same domain as the app.
3. **Tiny separate Worker** (`workers/timer-fire`) runs on a cron trigger every minute, scans KV for due timers, sends Web Push, deletes the record. Separate from Pages because Pages Functions doesn't reliably support scheduled triggers; both bind to the same KV namespace.

### Why not a single Worker + Static Assets

Considered. Trade-off: cleaner one-deploy story, but requires migrating the existing Pages deploy pipeline. Two deploys via the chosen split is mildly worse in deploy ergonomics, but doesn't touch the working Pages setup. If the deploy split proves annoying in practice, the migration to a single Worker is straightforward later.

## Data flow

### Starting a timer

1. User taps "Start timer" on `TodayScreen` (or "Start" from the pre-filled flow on `WorkoutScreen`).
2. If `Notification.permission === "default"`, show inline explainer and request permission.
3. Frontend calls `registration.pushManager.getSubscription()`. If null and permission granted, `subscribe({ userVisibleOnly: true, applicationServerKey: VAPID_PUBLIC_KEY })`. Persist subscription JSON in `AppState.pushSubscription`.
4. Generate `timerId` (UUID), compute `fireAt = new Date(Date.now() + durationMs).toISOString()`.
5. POST `{ timerId, fireAt, label, subscription }` to `/api/timers`.
6. On success, append to `AppState.pendingTimers`.
7. Navigate to TimerScreen running view (countdown rendered from `fireAt - now`).

### Cancelling

1. User taps "Cancel" on TimerScreen.
2. DELETE `/api/timers/<timerId>?fireAt=<iso>` (client knows `fireAt` from local state).
3. Remove from `AppState.pendingTimers`.

### Firing

1. Cron Worker wakes every minute.
2. Lists keys with prefix `timer:`, filters to those whose timestamp portion is in the past.
3. For each due key: read record, send Web Push via VAPID, delete the key. Push failures (404/410) treated identically to success — just delete.
4. Service Worker `push` handler displays a notification: title = label, body = "<label> — done", tag = timerId (collapses any duplicate deliveries).
5. `notificationclick` opens or focuses the app.
6. App, on render, checks `pendingTimers` for any entries with `fireAt < now`. These are treated as "fired, awaiting confirmation" — TodayScreen surfaces a "Log it?" prompt for each. No separate state field; the condition is derived from `pendingTimers` filtered by `fireAt < now`.
7. On confirm, the activity is logged: if `sourceWorkoutId` is set, add it to `session.completedWorkouts` (dedup with Set since it's `string[]`); otherwise append a new `AdHocActivity` to `session.adHocActivities`. Either way, remove the entry from `pendingTimers`.
8. On dismiss, just remove the entry from `pendingTimers` without logging.

## Frontend changes

### `src/types.ts` additions

```ts
export interface PendingTimer {
  timerId: string;
  fireAt: string;            // ISO timestamp
  label: string;
  activityType: WorkoutType;
  sourceWorkoutId?: string;
}

export interface AdHocActivity {
  id: string;
  label: string;
  type: WorkoutType;
  startedAt: string;         // ISO timestamp
  durationMinutes: number;
}

export interface DailySession {
  // ...existing fields
  adHocActivities: AdHocActivity[];
}

export interface AppState {
  // ...existing fields
  pushSubscription?: PushSubscriptionJSON;
  pendingTimers: PendingTimer[];
}
```

### `src/storage.ts` migration

- `defaultState()` returns `pendingTimers: []` (top-level spread in `loadState` covers existing users automatically).
- `getSession()` defaults `adHocActivities: saved.adHocActivities ?? []` in the saved branch and `adHocActivities: []` in the unsaved branch.

### UI changes (`src/main.tsx`)

**`WorkoutScreen`:**
- Remove the `useState(0)` + `setInterval` elapsed counter and the `timer-panel` section.
- Add a "Start timer" CTA that navigates to TimerScreen pre-filled with `{ duration: workout.estimatedDuration, label: workout.title, activityType: workout.type, sourceWorkoutId: workout.id }`.
- Keep the "Mark complete" button as the existing manual-completion path.

**`TodayScreen`:**
- Add a "Start a quick timer" entry (button or card).
- If `AppState.pendingTimers` is non-empty, render a compact chip ("Walk · 14:23 remaining") that opens TimerScreen.
- If any pending timer's `fireAt` is in the past (fired but not yet acted on), render a confirm prompt: "<label> finished — log it?" with Confirm / Dismiss.

**`TimerScreen` (new):**
- Fresh-launch flow: pick `activityType` (`cardio` / `mobility` / `strength` / `recovery`), `label` (text input, defaults to type), duration (preset chips: 10 / 20 / 30 / 45 / 60 min, plus custom). Single "Start" button.
- Pre-filled flow (from WorkoutScreen): skip picker, go straight to running view.
- Running view: large `MM:SS` countdown computed as `fireAt - now` each render. A 1-second `setInterval` triggers re-renders only; displayed value is wall-clock derived, so backgrounding is irrelevant.
- "Cancel" and "Done early" buttons.

**`App`:**
- Add `'timer'` to the `view` union.
- On app open / every render, scan `pendingTimers` for fired entries and surface the confirm prompt on TodayScreen.

### Service worker (`public/service-worker.js`)

Bump `CACHE_NAME` to `fitness50-v2`. Add:

```js
self.addEventListener("push", (event) => {
  const data = event.data?.json() ?? {};
  event.waitUntil(
    self.registration.showNotification(data.title ?? "Timer done", {
      body: data.body,
      tag: data.timerId,
      data: { timerId: data.timerId },
    }),
  );
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  event.waitUntil(
    self.clients.matchAll({ type: "window" }).then((clients) => {
      const existing = clients.find((c) => "focus" in c);
      if (existing) return existing.focus();
      return self.clients.openWindow("/");
    }),
  );
});
```

### Permission flow

- First "Start timer" tap: if permission is `default`, show inline explainer, then `Notification.requestPermission()`.
- If granted: subscribe, store, proceed.
- If denied: still allow the timer (countdown works while app is open), show inline "No notification — open the app to check." Skip the backend POST since there's no subscription to push to.

## Backend

### Project layout additions

```
fitness50/
├── functions/
│   └── api/
│       └── timers/
│           ├── index.ts             # POST
│           └── [id].ts              # DELETE
└── workers/
    └── timer-fire/
        ├── wrangler.toml
        └── src/index.ts             # scheduled() handler
```

### KV schema

One namespace, `TIMERS_KV`. Single key prefix:

```
timer:<fireAt-iso>:<timerId>   →  JSON: { subscription, title, body, timerId }
```

ISO timestamp in the key gives lexical = chronological sort. Cron lists with prefix `timer:` and stops at the first key whose timestamp is in the future.

No separate subscriptions table. The subscription rides on each timer record. Dead subscriptions are detected on push send (404/410) and dropped silently.

### Endpoint contracts

**`POST /api/timers`**

Request body:
```json
{
  "timerId": "<uuid>",
  "fireAt": "<iso-timestamp>",
  "label": "<string>",
  "subscription": { "endpoint": "...", "keys": { "p256dh": "...", "auth": "..." } }
}
```

Behavior:
- Validate shape. Bail with 400 on missing/malformed fields.
- Write `timer:<fireAt>:<timerId>` to KV with TTL of 24h as a safety net.
- Respond 204.

**`DELETE /api/timers/:id?fireAt=<iso>`**

- `fireAt` is required as a query param so the function can compute the KV key without an index lookup.
- Delete `timer:<fireAt>:<id>` from KV. Respond 204 regardless of whether the key existed.

### Cron Worker (`workers/timer-fire/src/index.ts`)

```ts
export default {
  async scheduled(_event, env, ctx) {
    const nowKey = `timer:${new Date().toISOString()}:`;
    const { keys } = await env.TIMERS_KV.list({ prefix: "timer:" });
    const due = keys.filter((k) => k.name < nowKey);

    for (const { name } of due) {
      const raw = await env.TIMERS_KV.get(name);
      if (!raw) continue;
      const record = JSON.parse(raw);
      ctx.waitUntil(sendPush(record, env).finally(() => env.TIMERS_KV.delete(name)));
    }
  },
};
```

`sendPush` uses a Workers-compatible Web Push library (e.g., `@negrel/webpush`) to build a VAPID-signed, payload-encrypted request and `fetch`es it. 404/410 responses are treated as success; the record is deleted either way.

### `workers/timer-fire/wrangler.toml`

```toml
name = "fitness50-timer-fire"
main = "src/index.ts"
compatibility_date = "2026-05-01"

[triggers]
crons = ["* * * * *"]

[[kv_namespaces]]
binding = "TIMERS_KV"
id = "<namespace-id>"
```

### VAPID key setup

One-time, before first deploy:

1. `npx web-push generate-vapid-keys` → outputs `publicKey` and `privateKey`.
2. Public key committed in `src/config.ts` as `VAPID_PUBLIC_KEY` (safe to ship in client code).
3. Private key + subject (`mailto:`) stored as secrets:
   - Pages: dashboard → Settings → Environment Variables → encrypt (`VAPID_PRIVATE_KEY`, `VAPID_SUBJECT`).
   - Worker: `wrangler secret put VAPID_PRIVATE_KEY` and `wrangler secret put VAPID_SUBJECT` from `workers/timer-fire/`.

### KV namespace setup

```
wrangler kv namespace create TIMERS_KV
# → outputs namespace id
```

Bind that id to:
- The Pages project (dashboard → Settings → Functions → KV namespace bindings, binding name `TIMERS_KV`).
- The Worker `wrangler.toml` (shown above).

## Edge cases

| Case | Behavior |
| --- | --- |
| Subscription invalidated | Frontend re-subscribes transparently on next app open; backend drops the record on push 404/410. |
| Cron lag (up to ~60s) | Notification can land up to ~60s after countdown shows 00:00. Acceptable for 30-min timers. |
| Push arrives while app foregrounded | Notification shows AND in-app confirm prompt surfaces. Both lead to the same action. |
| Cancel races cron fire | Either DELETE wins (no push) or cron wins (push lands, app has no pending timer, `notificationclick` opens app and confirms — no error). |
| Multiple devices | Each install's subscription is independent. Timer started on phone notifies only phone. |
| Multiple concurrent timers | Data model allows. v1 UI replaces existing timer if user starts new one. |
| Permission denied / revoked | Timer runs locally, no notification. Inline "no notification" hint. |
| Clock skew | Frontend uses local `Date.now()`. Modern phones are NTP-synced; ignore. |
| Service worker update | `skipWaiting()` + `clients.claim()` already in place; new handlers activate on next load. |

## Verification

No automated test runner. Required steps:

1. `npm run build` — `tsc` catches type errors on new state shape and API request/response types.
2. `npm run dev` + manual click-through — verify TimerScreen UI, countdown math, cancel flow, permission prompt.
3. `wrangler dev --test-scheduled` in `workers/timer-fire/` against a fake KV entry with `fireAt` in the past — verify scheduled handler reads, attempts push, deletes.
4. **Real-device round-trip** (only meaningful verification of the push path): deploy to preview branch, install or use existing home-screen install on iPhone, set a 1-minute timer, lock screen, verify notification appears, tap notification, verify app opens and surfaces confirm prompt, verify ad-hoc activity appears in week view stats.
5. Post-deploy smoke: set a 30-second timer, lock phone, verify notification fires within ~90s.

## Cost

For single-user scale: ~10 KV writes/day, 1,440 cron invocations/day, ~10 push messages/day. All comfortably within Cloudflare free tiers. No marginal cost.

## Open questions

None at design time. Implementation plan will pin down the specific Web Push library (`@negrel/webpush` vs alternatives) after a quick compatibility check against current Workers runtime.
