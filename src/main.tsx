import React, { useEffect, useMemo, useState } from "react";
import { createRoot } from "react-dom/client";
import {
  Activity,
  CalendarDays,
  Check,
  ChevronLeft,
  HeartPulse,
  Minus,
  Play,
  RotateCcw,
  SlidersHorizontal,
  Timer,
  Wind,
} from "lucide-react";
import "./styles.css";
import { beginnerProgram, getPhaseName, getProgramWeek, getWorkoutForDate } from "./program";
import { applyVolume, getRecoveryAdvice, rollingStats } from "./progression";
import { getSession, loadState, saveState, upsertSession } from "./storage";
import { getOrCreateSubscription } from "./push";
import { cancelTimer, scheduleTimer } from "./timer-api";
import type { AppState, DailySession, PendingTimer, Workout, WorkoutType } from "./types";

const todayIso = () => new Date().toISOString().slice(0, 10);
const dayName = new Intl.DateTimeFormat(undefined, { weekday: "long", month: "short", day: "numeric" });

function App() {
  const [state, setState] = useState<AppState>(() => loadState());
  const [screen, setScreen] = useState<"today" | "workout" | "week" | "recovery" | "timer">("today");
  const [timerPrefill, setTimerPrefill] = useState<{
    durationMinutes: number;
    label: string;
    activityType: WorkoutType;
    sourceWorkoutId?: string;
  } | undefined>(undefined);
  const date = todayIso();
  const session = getSession(state, date);
  const activeWorkout = state.activeWorkoutId ? getWorkoutForDate(state.activeWorkoutId, state.startDate, date) : undefined;

  useEffect(() => saveState(state), [state]);

  useEffect(() => {
    if ("serviceWorker" in navigator) {
      navigator.serviceWorker.register("/service-worker.js").catch(() => undefined);
    }
  }, []);

  const updateSession = (next: DailySession) => setState((current) => upsertSession(current, next));
  const setActiveWorkout = (workoutId: string) => {
    setState((current) => ({ ...current, activeWorkoutId: workoutId }));
    setScreen("workout");
  };

  const openTimer = (prefill?: typeof timerPrefill) => {
    setTimerPrefill(prefill);
    setScreen("timer");
  };

  return (
    <main className="app-shell">
      {screen === "today" && (
        <TodayScreen
          state={state}
          session={session}
          onStart={setActiveWorkout}
          onDone={(workoutId) => updateSession(completeWorkout(session, workoutId))}
          onSkip={(workoutId) => updateSession(skipWorkout(session, workoutId))}
          onEasier={() => setState((current) => ({ ...current, easierToday: !current.easierToday }))}
          onOpenWeek={() => setScreen("week")}
          onOpenRecovery={() => setScreen("recovery")}
          onOpenTimer={() => openTimer()}
        />
      )}
      {screen === "workout" && activeWorkout && (
        <WorkoutScreen
          workout={activeWorkout}
          session={session}
          easierToday={state.easierToday}
          onBack={() => setScreen("today")}
          onDone={() => {
            updateSession(completeWorkout(session, activeWorkout.id));
            setState((current) => ({ ...current, activeWorkoutId: undefined }));
            setScreen("today");
          }}
          onOpenTimer={(prefill) => openTimer(prefill)}
        />
      )}
      {screen === "week" && <WeeklyScreen state={state} onBack={() => setScreen("today")} />}
      {screen === "recovery" && (
        <RecoveryScreen session={session} onBack={() => setScreen("today")} onChange={updateSession} />
      )}
      {screen === "timer" && (
        <TimerScreen
          prefill={timerPrefill}
          pendingTimers={state.pendingTimers}
          onBack={() => setScreen("today")}
          onStart={async (timer) => {
            // Always update local state first so the running view appears immediately.
            setState((current) => ({
              ...current,
              pendingTimers: [...current.pendingTimers, timer],
            }));

            try {
              const subscription = await getOrCreateSubscription();
              if (!subscription) {
                // Permission denied or no service worker. Timer still runs locally.
                return;
              }
              setState((current) => ({ ...current, pushSubscription: subscription }));
              await scheduleTimer(timer, subscription);
            } catch (error) {
              console.error("Failed to schedule timer push:", error);
              // Keep the local timer; the user just won't get a notification.
            }
          }}
          onCancel={async (timerId) => {
            const timer = state.pendingTimers.find((t) => t.timerId === timerId);
            setState((current) => ({
              ...current,
              pendingTimers: current.pendingTimers.filter((t) => t.timerId !== timerId),
            }));
            setScreen("today");

            if (timer) {
              try {
                await cancelTimer(timer.timerId, timer.fireAt);
              } catch (error) {
                console.error("Failed to cancel timer on server:", error);
              }
            }
          }}
        />
      )}
    </main>
  );
}

function TodayScreen({
  state,
  session,
  onStart,
  onDone,
  onSkip,
  onEasier,
  onOpenWeek,
  onOpenRecovery,
  onOpenTimer,
}: {
  state: AppState;
  session: DailySession;
  onStart: (workoutId: string) => void;
  onDone: (workoutId: string) => void;
  onSkip: (workoutId: string) => void;
  onEasier: () => void;
  onOpenWeek: () => void;
  onOpenRecovery: () => void;
  onOpenTimer: () => void;
}) {
  const advice = getRecoveryAdvice(session);
  const workouts = session.plannedWorkouts.map((id) => getWorkoutForDate(id, state.startDate, session.date)).filter(Boolean);
  const completeCount = session.completedWorkouts.length;
  const totalMinutes = workouts.reduce((total, workout) => total + workout.estimatedDuration, 0);
  const week = getProgramWeek(state.startDate, session.date);
  const phase = getPhaseName(state.startDate, session.date);

  return (
    <section className="screen">
      <header className="topbar">
        <div>
          <p className="eyebrow">{dayName.format(new Date(`${session.date}T00:00:00`))}</p>
          <h1>Today</h1>
          <p className="phase-line">Week {week} · {phase}</p>
        </div>
        <button className="icon-button" onClick={onOpenWeek} aria-label="Open weekly overview">
          <CalendarDays size={22} />
        </button>
      </header>

      <section className={`recovery-banner ${advice.level}`}>
        <HeartPulse size={24} />
        <div>
          <h2>{advice.title}</h2>
          <p>{advice.message}</p>
        </div>
      </section>

      <div className="summary-row">
        <Metric label="Planned" value={`${workouts.length}`} />
        <Metric label="Minutes" value={`${totalMinutes}`} />
        <Metric label="Last 7" value={`${lastSevenMovementDays(state)} days`} />
      </div>

      {state.pendingTimers.length > 0 && (
        <button className="timer-chip" onClick={onOpenTimer}>
          <Timer size={18} />
          <span>{state.pendingTimers[0].label} — see timer</span>
        </button>
      )}

      <button className="full-button" onClick={onOpenTimer}>
        <Timer size={20} />
        Start a quick timer
      </button>

      <div className="section-header">
        <h2>Planned movement</h2>
        <button className="text-button" onClick={onOpenRecovery}>
          <SlidersHorizontal size={18} />
          Check in
        </button>
      </div>

      <div className="workout-list">
        {workouts.map((workout) => {
          const done = session.completedWorkouts.includes(workout.id);
          const skipped = session.skippedWorkouts.includes(workout.id);
          return (
            <article className={`workout-card ${done ? "done" : ""}`} key={workout.id}>
              <div className="workout-main">
                <WorkoutIcon type={workout.type} />
                <div>
                  <h3>{workout.title}</h3>
                  <p>
                    {workout.estimatedDuration} min · {workout.type}
                  </p>
                  {workout.rounds && <p className="workout-detail">{workout.rounds}</p>}
                </div>
              </div>
              <div className="actions">
                <button className="primary-action" onClick={() => onStart(workout.id)} disabled={done}>
                  <Play size={18} />
                  Start
                </button>
                <button className="quiet-action" onClick={() => onDone(workout.id)} disabled={done}>
                  <Check size={18} />
                  {done ? "Done" : "Done"}
                </button>
                <button className="icon-button small" onClick={() => onSkip(workout.id)} aria-label={`Skip ${workout.title}`}>
                  {skipped ? <RotateCcw size={18} /> : <Minus size={18} />}
                </button>
              </div>
            </article>
          );
        })}
      </div>

      <button className={`full-button ${state.easierToday ? "active" : ""}`} onClick={onEasier}>
        <Wind size={20} />
        {state.easierToday ? "Easier mode is on" : "Easier today"}
      </button>

      <p className="gentle-note">
        {completeCount > 0 ? "Good. The goal is repeatable progress." : "Starting small still counts."}
      </p>
    </section>
  );
}

function WorkoutScreen({
  workout,
  session,
  easierToday,
  onBack,
  onDone,
  onOpenTimer,
}: {
  workout: Workout;
  session: DailySession;
  easierToday: boolean;
  onBack: () => void;
  onDone: () => void;
  onOpenTimer: (prefill: { durationMinutes: number; label: string; activityType: WorkoutType; sourceWorkoutId?: string }) => void;
}) {
  const advice = getRecoveryAdvice(session);
  const modifier = Math.min(advice.volumeModifier, easierToday ? 0.85 : 1);

  return (
    <section className="screen">
      <header className="topbar">
        <button className="icon-button" onClick={onBack} aria-label="Back to today">
          <ChevronLeft size={24} />
        </button>
        <div className="topbar-fill">
          <p className="eyebrow">{workout.type}</p>
          <h1>{workout.title}</h1>
          {workout.rounds && <p className="phase-line">{workout.phase} · {workout.rounds}</p>}
        </div>
      </header>

      <div className="exercise-list">
        {workout.exercises.map((exercise, index) => (
          <article className="exercise-card" key={exercise.id}>
            <div className="exercise-index">{index + 1}</div>
            <div>
              <h2>{exercise.name}</h2>
              <p>{exercise.instructions}</p>
              <strong>
                {formatExerciseTarget(exercise, modifier)}
              </strong>
            </div>
          </article>
        ))}
      </div>

      <section className="coach-note">
        <h2>Keep it repeatable</h2>
        <p>{workout.guidance ?? advice.message}</p>
      </section>

      <button
        className="full-button"
        onClick={() =>
          onOpenTimer({
            durationMinutes: workout.estimatedDuration,
            label: workout.title,
            activityType: workout.type,
            sourceWorkoutId: workout.id,
          })
        }
      >
        <Timer size={20} />
        Start timer ({workout.estimatedDuration} min)
      </button>

      <button className="full-button primary" onClick={onDone}>
        <Check size={20} />
        Mark complete
      </button>
    </section>
  );
}

function WeeklyScreen({ state, onBack }: { state: AppState; onBack: () => void }) {
  const sessions = useMemo(() => lastNDays(30).map((date) => getSession(state, date)), [state]);
  const week = sessions.slice(0, 7);
  const stats = rollingStats(week);
  const month = rollingStats(sessions);
  const programWeek = getProgramWeek(state.startDate, todayIso());
  const phase = getPhaseName(state.startDate, todayIso());

  return (
    <section className="screen">
      <header className="topbar">
        <button className="icon-button" onClick={onBack} aria-label="Back to today">
          <ChevronLeft size={24} />
        </button>
        <div className="topbar-fill">
          <p className="eyebrow">{beginnerProgram.name}</p>
          <h1>Weekly view</h1>
          <p className="phase-line">Week {programWeek} · {phase}</p>
        </div>
      </header>

      <div className="summary-row">
        <Metric label="Consistency" value={`${stats.consistency}%`} />
        <Metric label="Moved" value={`${stats.completedDays}/7`} />
        <Metric label="Cardio" value={`${stats.cardioMinutes} min`} />
      </div>

      <section className="trend-panel">
        <h2>Last 7 days</h2>
        <div className="day-strip">
          {week.reverse().map((day) => (
            <div className={`day-dot ${day.completedWorkouts.length ? "complete" : ""}`} key={day.date}>
              <span>{new Date(`${day.date}T00:00:00`).toLocaleDateString(undefined, { weekday: "short" }).slice(0, 1)}</span>
            </div>
          ))}
        </div>
      </section>

      <section className="coach-note">
        <h2>Rolling 30 days</h2>
        <p>{month.completedDays} movement days. Missing one day does not erase the pattern.</p>
      </section>
    </section>
  );
}

function RecoveryScreen({
  session,
  onBack,
  onChange,
}: {
  session: DailySession;
  onBack: () => void;
  onChange: (session: DailySession) => void;
}) {
  const update = (patch: Partial<DailySession>) => onChange({ ...session, ...patch });
  const advice = getRecoveryAdvice(session);

  return (
    <section className="screen">
      <header className="topbar">
        <button className="icon-button" onClick={onBack} aria-label="Back to today">
          <ChevronLeft size={24} />
        </button>
        <div className="topbar-fill">
          <p className="eyebrow">Recovery check-in</p>
          <h1>How are you today?</h1>
        </div>
      </header>

      <Rating label="Soreness" value={session.sorenessRating} onChange={(value) => update({ sorenessRating: value })} />
      <Rating label="Energy" value={session.energyRating} onChange={(value) => update({ energyRating: value })} />
      <Rating label="Sleep" value={session.sleepRating} onChange={(value) => update({ sleepRating: value })} />

      <label className="toggle-row">
        <input
          checked={session.jointPain}
          type="checkbox"
          onChange={(event) => update({ jointPain: event.target.checked })}
        />
        <span>Knees or joints need extra care today</span>
      </label>

      <section className={`recovery-banner ${advice.level}`}>
        <HeartPulse size={24} />
        <div>
          <h2>{advice.title}</h2>
          <p>{advice.message}</p>
        </div>
      </section>
    </section>
  );
}

function Rating({ label, value, onChange }: { label: string; value: number; onChange: (value: number) => void }) {
  return (
    <section className="rating">
      <div className="section-header">
        <h2>{label}</h2>
        <strong>{value}/5</strong>
      </div>
      <input min="1" max="5" step="1" type="range" value={value} onChange={(event) => onChange(Number(event.target.value))} />
    </section>
  );
}

function Metric({ label, value }: { label: string; value: string }) {
  return (
    <div className="metric">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

function WorkoutIcon({ type }: { type: string }) {
  if (type === "strength") return <Activity size={24} />;
  if (type === "recovery") return <HeartPulse size={24} />;
  if (type === "mobility") return <Wind size={24} />;
  return <Timer size={24} />;
}

function formatExerciseTarget(exercise: Workout["exercises"][number], modifier: number) {
  if (exercise.targetLabel) return exercise.targetLabel;
  if (exercise.defaultReps) {
    const reps = applyVolume(exercise.defaultReps, modifier);
    return `${reps} reps${exercise.targetSuffix ? ` ${exercise.targetSuffix}` : ""}`;
  }
  if (exercise.defaultDuration) {
    const seconds = applyVolume(exercise.defaultDuration, modifier) ?? exercise.defaultDuration;
    const target = seconds < 60 ? `${seconds} sec` : `${Math.ceil(seconds / 60)} min`;
    return `${target}${exercise.targetSuffix ? ` ${exercise.targetSuffix}` : ""}`;
  }
  return "Comfortable effort";
}

function completeWorkout(session: DailySession, workoutId: string): DailySession {
  return {
    ...session,
    completedWorkouts: Array.from(new Set([...session.completedWorkouts, workoutId])),
    skippedWorkouts: session.skippedWorkouts.filter((id) => id !== workoutId),
  };
}

function skipWorkout(session: DailySession, workoutId: string): DailySession {
  const isSkipped = session.skippedWorkouts.includes(workoutId);
  return {
    ...session,
    skippedWorkouts: isSkipped
      ? session.skippedWorkouts.filter((id) => id !== workoutId)
      : Array.from(new Set([...session.skippedWorkouts, workoutId])),
  };
}

function lastNDays(count: number) {
  return Array.from({ length: count }, (_, index) => {
    const date = new Date();
    date.setDate(date.getDate() - index);
    return date.toISOString().slice(0, 10);
  });
}

function lastSevenMovementDays(state: AppState) {
  return lastNDays(7).filter((date) => getSession(state, date).completedWorkouts.length > 0).length;
}

function TimerScreen({
  prefill,
  pendingTimers,
  onBack,
  onStart,
  onCancel,
}: {
  prefill?: { durationMinutes: number; label: string; activityType: WorkoutType; sourceWorkoutId?: string };
  pendingTimers: PendingTimer[];
  onBack: () => void;
  onStart: (timer: PendingTimer) => void;
  onCancel: (timerId: string) => void;
}) {
  const running = pendingTimers[0]; // v1: single timer at a time

  const [activityType, setActivityType] = useState<WorkoutType>(prefill?.activityType ?? "cardio");
  const [label, setLabel] = useState(prefill?.label ?? "Walk");
  const [durationMinutes, setDurationMinutes] = useState(prefill?.durationMinutes ?? 30);

  if (running) {
    return <TimerRunningView timer={running} onBack={onBack} onCancel={onCancel} />;
  }

  const handleStart = () => {
    const timerId = crypto.randomUUID();
    const fireAt = new Date(Date.now() + durationMinutes * 60_000).toISOString();
    onStart({
      timerId,
      fireAt,
      label,
      activityType,
      durationMinutes,
      sourceWorkoutId: prefill?.sourceWorkoutId,
    });
  };

  return (
    <section className="screen">
      <header className="topbar">
        <button className="icon-button" onClick={onBack} aria-label="Back to today">
          <ChevronLeft size={24} />
        </button>
        <div className="topbar-fill">
          <p className="eyebrow">Standalone timer</p>
          <h1>Start a timer</h1>
        </div>
      </header>

      <section className="timer-picker">
        <h2>Activity</h2>
        <div className="chip-row">
          {(["cardio", "mobility", "strength", "recovery"] as const).map((type) => (
            <button
              key={type}
              className={`chip ${activityType === type ? "active" : ""}`}
              onClick={() => setActivityType(type)}
            >
              {type}
            </button>
          ))}
        </div>

        <h2>Label</h2>
        <input
          type="text"
          value={label}
          onChange={(event) => setLabel(event.target.value)}
          placeholder="Walk, stretch, etc."
        />

        <h2>Duration</h2>
        <div className="chip-row">
          {[10, 20, 30, 45, 60].map((minutes) => (
            <button
              key={minutes}
              className={`chip ${durationMinutes === minutes ? "active" : ""}`}
              onClick={() => setDurationMinutes(minutes)}
            >
              {minutes} min
            </button>
          ))}
          <input
            type="number"
            min={1}
            max={240}
            value={durationMinutes}
            onChange={(event) => setDurationMinutes(Math.max(1, Number(event.target.value) || 1))}
            className="duration-custom"
            aria-label="Custom duration in minutes"
          />
        </div>
      </section>

      <button
        className="full-button primary"
        onClick={handleStart}
        disabled={!label.trim() || durationMinutes < 1}
      >
        <Play size={20} />
        Start {durationMinutes}-min {activityType}
      </button>
    </section>
  );
}

function TimerRunningView({
  timer,
  onBack,
  onCancel,
}: {
  timer: PendingTimer;
  onBack: () => void;
  onCancel: (timerId: string) => void;
}) {
  const [, forceRender] = useState(0);

  useEffect(() => {
    const id = window.setInterval(() => forceRender((value) => value + 1), 1000);
    return () => window.clearInterval(id);
  }, []);

  const fireAtMs = new Date(timer.fireAt).getTime();
  const remainingMs = Math.max(0, fireAtMs - Date.now());
  const remainingSeconds = Math.ceil(remainingMs / 1000);
  const minutes = Math.floor(remainingSeconds / 60).toString().padStart(2, "0");
  const seconds = (remainingSeconds % 60).toString().padStart(2, "0");
  const isDone = remainingMs === 0;
  const canNotify = typeof Notification !== "undefined" && Notification.permission === "granted";

  const hint = isDone
    ? "Time's up — log it from Today when you're back."
    : canNotify
      ? "Lock your phone — we'll notify you when it's done."
      : "No notification — open the app to check.";

  return (
    <section className="screen">
      <header className="topbar">
        <button className="icon-button" onClick={onBack} aria-label="Back to today">
          <ChevronLeft size={24} />
        </button>
        <div className="topbar-fill">
          <p className="eyebrow">{timer.activityType}</p>
          <h1>{timer.label}</h1>
        </div>
      </header>

      <section className="timer-countdown">
        <Timer size={48} />
        <strong className="countdown-display">{minutes}:{seconds}</strong>
        <p className="countdown-hint">{hint}</p>
      </section>

      <button className="full-button" onClick={() => onCancel(timer.timerId)}>
        Cancel timer
      </button>
      <button className="full-button primary" onClick={() => onCancel(timer.timerId)}>
        Done early
      </button>
    </section>
  );
}

createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
);
