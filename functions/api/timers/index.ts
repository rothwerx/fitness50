interface Env {
  TIMERS_KV: KVNamespace;
}

interface TimerRequest {
  timerId: string;
  fireAt: string;
  label: string;
  subscription: {
    endpoint: string;
    keys: { p256dh: string; auth: string };
  };
}

function isValid(body: unknown): body is TimerRequest {
  if (!body || typeof body !== "object") return false;
  const b = body as Record<string, unknown>;
  if (typeof b.timerId !== "string" || !b.timerId) return false;
  if (typeof b.fireAt !== "string" || Number.isNaN(Date.parse(b.fireAt))) return false;
  if (typeof b.label !== "string" || !b.label) return false;
  const sub = b.subscription as Record<string, unknown> | undefined;
  if (!sub || typeof sub.endpoint !== "string") return false;
  const keys = sub.keys as Record<string, unknown> | undefined;
  if (!keys || typeof keys.p256dh !== "string" || typeof keys.auth !== "string") return false;
  return true;
}

export const onRequestPost: PagesFunction<Env> = async ({ request, env }) => {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }

  if (!isValid(body)) {
    return new Response("Invalid request body", { status: 400 });
  }

  const { timerId, fireAt, label, subscription } = body;
  const key = `timer:${fireAt}:${timerId}`;
  const value = JSON.stringify({
    subscription,
    title: label,
    body: `${label} — done`,
    timerId,
  });

  // 24-hour TTL as a safety net in case the cron Worker misses or stops.
  await env.TIMERS_KV.put(key, value, { expirationTtl: 60 * 60 * 24 });

  return new Response(null, { status: 204 });
};
