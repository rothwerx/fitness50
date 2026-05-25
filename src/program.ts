import type { Exercise, Workout, WorkoutPlan, WorkoutType } from "./types";

type PhaseKey = "foundation" | "capacity" | "momentum";

const phaseCopy: Record<PhaseKey, string> = {
  foundation: "Foundation",
  capacity: "Build Capacity",
  momentum: "Momentum",
};

const rule = (ceiling: string) => ({
  increaseAfterCompletions: 4,
  increaseBy: "Add reps, time, or rounds only when recovery feels steady.",
  ceiling,
});

const strengthExercise = (
  id: string,
  name: string,
  reps: number,
  instructions: string,
  regressionRules: string[] = ["Reduce reps by 20-30%", "Shorten range of motion"],
  targetSuffix?: string,
): Exercise => ({
  id,
  name,
  category: "strength",
  progressionRules: rule("Stop before form changes or joints complain."),
  regressionRules,
  defaultReps: reps,
  targetSuffix,
  instructions,
});

const timedExercise = (
  id: string,
  name: string,
  category: WorkoutType,
  seconds: number,
  instructions: string,
  regressionRules: string[],
  targetSuffix?: string,
): Exercise => ({
  id,
  name,
  category,
  progressionRules: rule("Add time only when recovery is comfortable the next day."),
  regressionRules,
  defaultDuration: seconds,
  targetSuffix,
  instructions,
});

const customExercise = (
  id: string,
  name: string,
  category: WorkoutType,
  targetLabel: string,
  instructions: string,
  regressionRules: string[],
): Exercise => ({
  id,
  name,
  category,
  progressionRules: rule("Keep the effort repeatable and joint-friendly."),
  regressionRules,
  targetLabel,
  instructions,
});

export function getProgramWeek(startDate: string, date: string) {
  const start = new Date(`${startDate}T00:00:00`);
  const current = new Date(`${date}T00:00:00`);
  const dayIndex = Math.max(0, Math.floor((current.getTime() - start.getTime()) / 86400000));
  return Math.min(12, Math.floor(dayIndex / 7) + 1);
}

export function getProgramPhase(week: number): PhaseKey {
  if (week <= 4) return "foundation";
  if (week <= 8) return "capacity";
  return "momentum";
}

export function getPhaseName(startDate: string, date: string) {
  return phaseCopy[getProgramPhase(getProgramWeek(startDate, date))];
}

const makeWalk = (minutes: number, title = "Easy walk"): Workout => ({
  id: minutes >= 45 ? "longCardio" : "walk30",
  title,
  type: "cardio",
  estimatedDuration: minutes,
  difficulty: minutes >= 45 ? 3 : 1,
  phase: "All phases",
  guidance: "Use a pace you could repeat tomorrow. Splitting the walk is fine.",
  exercises: [
    timedExercise(
      `${title.toLowerCase().replace(/\s+/g, "-")}-${minutes}`,
      title,
      "cardio",
      minutes * 60,
      "Walk at a smooth, conversational pace and finish with a little in reserve.",
      ["Shorten the walk", "Break it into two easy walks"],
    ),
  ],
});

const mobility: Workout = {
  id: "mobility",
  title: "Rest + mobility",
  type: "mobility",
  estimatedDuration: 8,
  difficulty: 1,
  phase: "All phases",
  guidance: "Easy range of motion counts. Nothing here should feel forced.",
  exercises: [
    customExercise("shoulder-circles", "Shoulder circles", "mobility", "45 sec", "Slow circles forward and back.", [
      "Make smaller circles",
    ]),
    customExercise("hip-circles", "Hip circles", "mobility", "45 sec each way", "Hold a chair if balance is useful.", [
      "Reduce range",
    ]),
    customExercise("calf-stretch", "Calf stretch", "mobility", "45 sec each side", "Keep it gentle through calves and Achilles.", [
      "Bend the knee slightly",
    ]),
    customExercise("hamstring-stretch", "Hamstring stretch", "mobility", "45 sec each side", "Hinge gently; avoid pulling hard.", [
      "Use a chair-supported version",
    ]),
    customExercise("thoracic-twists", "Thoracic twists", "mobility", "8 each side", "Rotate through the upper back while breathing steadily.", [
      "Do seated twists",
    ]),
    customExercise("ankle-mobility", "Ankle mobility", "mobility", "8 each side", "Move the knee over the toes without pain.", [
      "Use a smaller range",
    ]),
  ],
};

function strengthA(phase: PhaseKey, week: number): Workout {
  const isFoundation = phase === "foundation";
  const isMomentum = phase === "momentum";
  const rounds = isFoundation ? (week >= 3 ? "2-3 rounds" : "2 rounds") : "3 rounds";
  const reps = isFoundation
    ? { squats: 10, pushups: 8, bridges: 10, stepUps: 10, plank: 20, birdDogs: 10 }
    : phase === "capacity"
      ? { squats: 12, pushups: 10, bridges: 12, stepUps: 12, plank: 30, birdDogs: 12 }
      : { squats: 15, pushups: 12, bridges: 15, stepUps: 15, plank: 45, birdDogs: 0 };

  const exercises = isMomentum
    ? [
        strengthExercise("squats", "Bodyweight squats", reps.squats, "Sit back, stand tall, and keep the knees comfortable."),
        strengthExercise("incline-pushups", "Incline pushups", reps.pushups, "Lower the incline gradually only if these feel easy."),
        strengthExercise("reverse-lunges", "Reverse lunges", 12, "Hold a wall or chair if useful.", ["Swap for chair squats"], "each leg"),
        strengthExercise("glute-bridges", "Glute bridges", reps.bridges, "Press through heels without arching the low back."),
        timedExercise("plank", "Plank", "strength", reps.plank, "Brace gently and breathe.", ["Use an elevated plank"]),
        timedExercise("side-plank", "Side plank", "strength", 30, "Keep the hold clean and short of strain.", ["Bend knees", "Use a shorter hold"], "each side"),
        strengthExercise("step-ups", "Step-ups", reps.stepUps, "Use a low, sturdy step and move with control.", ["Use a lower step"], "each leg"),
      ]
    : [
        strengthExercise("squats", "Bodyweight squats", reps.squats, "Sit back, stand tall, and keep the knees comfortable."),
        strengthExercise("incline-pushups", "Incline pushups", reps.pushups, "Use a counter or table height that lets you move smoothly."),
        strengthExercise("glute-bridges", "Glute bridges", reps.bridges, "Press through heels without arching the low back."),
        strengthExercise("step-ups", "Step-ups", reps.stepUps, "Use a low, sturdy step and alternate sides.", ["Use a lower step"], "each leg"),
        timedExercise("plank", "Plank", "strength", reps.plank, "Brace gently and breathe.", ["Use an elevated plank"]),
        strengthExercise("bird-dogs", "Bird dogs", reps.birdDogs, "Reach opposite arm and leg while keeping hips steady.", ["Move only legs"], "each side"),
      ];

  return {
    id: "strengthA",
    title: "Strength A",
    type: "strength",
    estimatedDuration: isFoundation ? 24 : 30,
    difficulty: phase === "momentum" ? 4 : phase === "capacity" ? 3 : 2,
    phase: phaseCopy[phase],
    rounds,
    guidance: "Rest 45-60 seconds between exercises as needed. Clean reps beat extra reps.",
    exercises,
  };
}

function strengthB(phase: PhaseKey): Workout {
  if (phase === "momentum") return strengthA(phase, 9);

  const isFoundation = phase === "foundation";
  const reps = isFoundation
    ? { lunges: 8, pushups: 10, sidePlank: 15, bridges: 12, deadBugs: 10, plank: 25 }
    : { lunges: 10, pushups: 11, sidePlank: 20, bridges: 15, deadBugs: 12, plank: 30 };

  return {
    id: "strengthB",
    title: "Strength B",
    type: "strength",
    estimatedDuration: isFoundation ? 24 : 30,
    difficulty: isFoundation ? 2 : 3,
    phase: phaseCopy[phase],
    rounds: isFoundation ? "2 rounds" : "3 rounds",
    guidance: "Hold a wall or chair for balance whenever it helps. Skip anything that bothers knees or hips.",
    exercises: [
      strengthExercise("reverse-lunges", "Reverse lunges", reps.lunges, "Step back gently while holding support if needed.", [
        "Swap for chair squats",
      ], "each leg"),
      strengthExercise(
        "wall-or-incline-pushups",
        isFoundation ? "Wall or incline pushups" : "Incline pushups",
        reps.pushups,
        "Choose the height that keeps shoulders comfortable.",
        ["Use a higher surface"],
      ),
      timedExercise("side-plank", "Side plank", "strength", reps.sidePlank, "Keep the hold calm and controlled.", [
        "Bend knees",
        "Shorten the hold",
      ], "each side"),
      strengthExercise("glute-bridges", "Glute bridges", reps.bridges, "Press through heels without arching the low back."),
      strengthExercise("dead-bugs", "Dead bugs", reps.deadBugs, "Move slowly and keep the low back comfortable.", [
        "Tap one heel at a time",
      ], "each side"),
      timedExercise(
        "plank-or-hollow",
        isFoundation ? "Hollow-body hold or plank" : "Plank",
        "strength",
        reps.plank,
        "Choose the version that lets you breathe and maintain form.",
        ["Use a regular plank", "Use an elevated plank"],
      ),
    ],
  };
}

function intervals(phase: PhaseKey): Workout {
  const config =
    phase === "foundation"
      ? {
          title: "Walk + intervals",
          minutes: 28,
          jump: "20 sec jump rope / 70-90 sec easy walk, 6-8 rounds",
          walk: "1 min fast walk / 2 min normal pace, 8-10 rounds",
        }
      : phase === "capacity"
        ? {
            title: "Cardio intervals",
            minutes: 30,
            jump: "30 sec jump rope / 60 sec rest, 8-12 rounds",
            walk: "1 min light jog / 2 min walk, 8-10 rounds",
          }
        : {
            title: "Intervals",
            minutes: 34,
            jump: "45 sec jump rope / 45-60 sec recovery, 10-15 rounds",
            walk: "2 min jog / 2 min walk, 8-10 rounds",
          };

  return {
    id: "intervals",
    title: config.title,
    type: "cardio",
    estimatedDuration: config.minutes,
    difficulty: phase === "foundation" ? 2 : phase === "capacity" ? 3 : 4,
    phase: phaseCopy[phase],
    guidance: "If jump rope bothers knees, calves, or Achilles tendons, switch to walking intervals immediately.",
    exercises: [
      customExercise("warm-walk", "Warm walk", "cardio", "5 min", "Start easy and let joints warm up.", [
        "Warm up longer if stiff",
      ]),
      customExercise("jump-rope-option", "Option A: jump rope", "cardio", config.jump, "Keep jumps low and relaxed.", [
        "Switch to brisk walking intervals",
      ]),
      customExercise("walking-option", "Option B: walking intervals", "cardio", config.walk, "Stay brisk, not breathless.", [
        "Shorten fast segments",
      ]),
      customExercise("cooldown", "Easy cooldown", "cardio", "3-5 min", "Finish with relaxed walking.", ["Stop earlier if needed"]),
    ],
  };
}

const workoutFactories: Record<string, (phase: PhaseKey, week: number) => Workout> = {
  strengthA,
  strengthB: (phase) => strengthB(phase),
  intervals: (phase) => intervals(phase),
  walk30: () => makeWalk(30, "Easy walk"),
  longCardio: (phase) =>
    makeWalk(phase === "foundation" ? 40 : 50, phase === "foundation" ? "Longer walk" : "Longer cardio"),
  mobility: () => mobility,
};

export const workoutLibrary: Record<string, Workout> = {
  strengthA: strengthA("foundation", 1),
  strengthB: strengthB("foundation"),
  intervals: intervals("foundation"),
  walk30: makeWalk(30, "Easy walk"),
  longCardio: makeWalk(40, "Longer walk"),
  mobility,
};

export const beginnerProgram: WorkoutPlan = {
  id: "beginner-12-week",
  name: "12-week beginner program",
  phase: "Foundation, Build Capacity, Momentum",
  durationWeeks: 12,
  workouts: Object.values(workoutLibrary),
};

const weeklyTemplates: Record<PhaseKey, string[][]> = {
  foundation: [
    ["strengthA"],
    ["walk30", "intervals"],
    ["strengthB"],
    ["walk30"],
    ["strengthA"],
    ["longCardio"],
    ["mobility"],
  ],
  capacity: [
    ["strengthA"],
    ["intervals"],
    ["strengthB"],
    ["walk30", "mobility"],
    ["strengthA"],
    ["longCardio"],
    ["mobility"],
  ],
  momentum: [
    ["strengthA"],
    ["intervals"],
    ["strengthB"],
    ["walk30"],
    ["strengthA"],
    ["longCardio"],
    ["mobility"],
  ],
};

export function getWorkoutForDate(workoutId: string, startDate: string, date: string): Workout {
  const week = getProgramWeek(startDate, date);
  const phase = getProgramPhase(week);
  return workoutFactories[workoutId]?.(phase, week) ?? workoutLibrary[workoutId];
}

export function planForDate(startDate: string, date: string): string[] {
  const start = new Date(`${startDate}T00:00:00`);
  const current = new Date(`${date}T00:00:00`);
  const dayIndex = Math.max(0, Math.floor((current.getTime() - start.getTime()) / 86400000));
  const week = Math.min(12, Math.floor(dayIndex / 7) + 1);
  const day = dayIndex % 7;
  const phase = getProgramPhase(week);
  return weeklyTemplates[phase][day];
}
