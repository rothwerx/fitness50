import type { AppState, DailySession } from "./types";
import { planForDate } from "./program";

const KEY = "fitness50-state";

const todayIso = () => new Date().toISOString().slice(0, 10);

export const defaultState = (): AppState => ({
  profile: {
    age: 50,
    height: "",
    activityBaseline: "light",
    mobilityLimitations: "",
    goals: ["consistency", "mobility", "strength"],
  },
  startDate: todayIso(),
  sessions: {},
  easierToday: false,
  pendingTimers: [],
});

export function loadState(): AppState {
  const raw = localStorage.getItem(KEY);
  if (!raw) return defaultState();

  try {
    return { ...defaultState(), ...JSON.parse(raw) };
  } catch {
    return defaultState();
  }
}

export function saveState(state: AppState) {
  localStorage.setItem(KEY, JSON.stringify(state));
}

export function getSession(state: AppState, date = todayIso()): DailySession {
  const plannedWorkouts = planForDate(state.startDate, date);
  const saved = state.sessions[date];

  if (saved) {
    return {
      ...saved,
      plannedWorkouts,
      completedWorkouts: saved.completedWorkouts.filter((id) => plannedWorkouts.includes(id)),
      skippedWorkouts: saved.skippedWorkouts.filter((id) => plannedWorkouts.includes(id)),
      adHocActivities: saved.adHocActivities ?? [],
    };
  }

  return {
    date,
    plannedWorkouts,
    completedWorkouts: [],
    skippedWorkouts: [],
    adHocActivities: [],
    notes: "",
    sorenessRating: 2,
    energyRating: 3,
    sleepRating: 3,
    jointPain: false,
  };
}

export function upsertSession(state: AppState, session: DailySession): AppState {
  return {
    ...state,
    sessions: {
      ...state.sessions,
      [session.date]: session,
    },
  };
}
