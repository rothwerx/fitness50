interface Env {
  TIMERS_KV: KVNamespace;
  VAPID_PUBLIC_KEY: string;
  VAPID_PRIVATE_KEY: string;
  VAPID_SUBJECT: string;
}

export default {
  async scheduled(_ctrl: ScheduledController, env: Env, _ctx: ExecutionContext): Promise<void> {
    console.log("scheduled fired", new Date().toISOString());
    const { keys } = await env.TIMERS_KV.list({ prefix: "timer:" });
    console.log("kv keys:", keys.map((k) => k.name));
  },
} satisfies ExportedHandler<Env>;
