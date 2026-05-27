export type Goal = "fat loss" | "stamina" | "mobility" | "strength" | "consistency";

export type WorkoutType = "strength" | "cardio" | "mobility" | "recovery";

export interface UserProfile {
  age: number;
  height: string;
  weight?: string;
  activityBaseline: "new" | "light" | "moderate";
  mobilityLimitations?: string;
  goals: Goal[];
}

export interface ProgressionRules {
  increaseAfterCompletions: number;
  increaseBy: string;
  ceiling: string;
}

export interface Exercise {
  id: string;
  name: string;
  category: WorkoutType;
  progressionRules: ProgressionRules;
  regressionRules: string[];
  defaultReps?: number;
  targetSuffix?: string;
  defaultDuration?: number;
  targetLabel?: string;
  instructions: string;
}

export interface Workout {
  id: string;
  title: string;
  type: WorkoutType;
  estimatedDuration: number;
  difficulty: 1 | 2 | 3 | 4 | 5;
  phase: string;
  rounds?: string;
  guidance?: string;
  exercises: Exercise[];
}

export interface WorkoutPlan {
  id: string;
  name: string;
  phase: string;
  durationWeeks: number;
  workouts: Workout[];
}

export interface AdHocActivity {
  id: string;
  label: string;
  type: WorkoutType;
  startedAt: string;         // ISO timestamp
  durationMinutes: number;
}

export interface PendingTimer {
  timerId: string;
  fireAt: string;            // ISO timestamp
  label: string;
  activityType: WorkoutType;
  durationMinutes: number;   // nominal length, needed for accurate ad-hoc logging
  sourceWorkoutId?: string;
}

export interface DailySession {
  date: string;
  plannedWorkouts: string[];
  completedWorkouts: string[];
  skippedWorkouts: string[];
  adHocActivities: AdHocActivity[];
  notes: string;
  sorenessRating: number;
  energyRating: number;
  sleepRating: number;
  jointPain: boolean;
}

export interface AppState {
  profile: UserProfile;
  startDate: string;
  sessions: Record<string, DailySession>;
  easierToday: boolean;
  activeWorkoutId?: string;
  pushSubscription?: PushSubscriptionJSON;
  pendingTimers: PendingTimer[];
}
