import type { DailySession } from "./types";

export type RecoveryAdvice = {
  level: "steady" | "easier" | "recovery";
  title: string;
  message: string;
  volumeModifier: number;
};

export function getRecoveryAdvice(session: DailySession): RecoveryAdvice {
  if (session.jointPain || session.sorenessRating >= 4 || session.energyRating <= 1) {
    return {
      level: "recovery",
      title: "Recovery is the plan today",
      message: "Swap intensity for walking or mobility and reduce volume by about 30%.",
      volumeModifier: 0.7,
    };
  }

  if (session.sorenessRating >= 3 || session.sleepRating <= 2 || session.energyRating <= 2) {
    return {
      level: "easier",
      title: "Make today a little easier",
      message: "Keep the habit, reduce reps or time by about 15%, and leave something in reserve.",
      volumeModifier: 0.85,
    };
  }

  return {
    level: "steady",
    title: "Steady effort is enough",
    message: "Use the planned session and stop while you still feel repeatable.",
    volumeModifier: 1,
  };
}

export function applyVolume(value: number | undefined, modifier: number): number | undefined {
  if (!value) return value;
  return Math.max(1, Math.round(value * modifier));
}

export function rollingStats(sessions: DailySession[]) {
  const completedDays = sessions.filter((session) => session.completedWorkouts.length > 0).length;
  const plannedDays = sessions.filter((session) => session.plannedWorkouts.length > 0).length || 1;
  const cardioMinutes = sessions.reduce((total, session) => {
    const cardioCount = session.completedWorkouts.filter((id) => id === "walk30" || id === "intervals").length;
    return total + cardioCount * 24;
  }, 0);

  return {
    consistency: Math.round((completedDays / plannedDays) * 100),
    completedDays,
    cardioMinutes,
  };
}
