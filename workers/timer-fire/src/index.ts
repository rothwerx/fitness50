import { buildPushPayload } from "@block65/webcrypto-web-push";
import type { PushSubscription, VapidKeys } from "@block65/webcrypto-web-push";

interface Env {
  TIMERS_KV: KVNamespace;
  VAPID_PUBLIC_KEY: string;
  VAPID_PRIVATE_KEY: string;
  VAPID_SUBJECT: string;
}

interface TimerRecord {
  subscription: {
    endpoint: string;
    keys: { p256dh: string; auth: string };
  };
  title: string;
  body: string;
  timerId: string;
}

async function sendPush(record: TimerRecord, env: Env): Promise<void> {
  const subscription: PushSubscription = {
    endpoint: record.subscription.endpoint,
    expirationTime: null,
    keys: record.subscription.keys,
  };

  const vapid: VapidKeys = {
    subject: env.VAPID_SUBJECT,
    publicKey: env.VAPID_PUBLIC_KEY,
    privateKey: env.VAPID_PRIVATE_KEY,
  };

  const payload = await buildPushPayload(
    {
      data: {
        title: record.title,
        body: record.body,
        timerId: record.timerId,
      },
      options: { ttl: 60, urgency: "high" },
    },
    subscription,
    vapid,
  );

  try {
    const response = await fetch(record.subscription.endpoint, {
      method: payload.method,
      headers: payload.headers,
      body: payload.body,
    });

    if (response.status === 404 || response.status === 410) {
      // Dead subscription — treat as success; KV record is cleaned up by the caller.
      return;
    }
    if (!response.ok) {
      console.error("push failed", response.status, await response.text());
    }
  } catch (error) {
    console.error("push exception", error);
  }
}

export default {
  async scheduled(_ctrl: ScheduledController, env: Env, ctx: ExecutionContext): Promise<void> {
    const nowKey = `timer:${new Date().toISOString()}:`;
    const { keys } = await env.TIMERS_KV.list({ prefix: "timer:" });
    const due = keys.filter((k) => k.name < nowKey);

    for (const { name } of due) {
      const raw = await env.TIMERS_KV.get(name);
      if (!raw) continue;
      const record = JSON.parse(raw) as TimerRecord;
      ctx.waitUntil(
        sendPush(record, env).finally(() => env.TIMERS_KV.delete(name)),
      );
    }
  },
} satisfies ExportedHandler<Env>;
