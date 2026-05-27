import type { PendingTimer } from "./types";

export async function scheduleTimer(
  timer: PendingTimer,
  subscription: PushSubscriptionJSON,
): Promise<void> {
  const response = await fetch("/api/timers", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      timerId: timer.timerId,
      fireAt: timer.fireAt,
      label: timer.label,
      subscription,
    }),
  });
  if (!response.ok) {
    throw new Error(`Failed to schedule timer: ${response.status}`);
  }
}

export async function cancelTimer(timerId: string, fireAt: string): Promise<void> {
  const url = `/api/timers/${encodeURIComponent(timerId)}?fireAt=${encodeURIComponent(fireAt)}`;
  const response = await fetch(url, { method: "DELETE" });
  if (!response.ok) {
    throw new Error(`Failed to cancel timer: ${response.status}`);
  }
}
