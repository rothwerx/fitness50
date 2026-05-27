interface Env {
  TIMERS_KV: KVNamespace;
}

export const onRequestDelete: PagesFunction<Env> = async ({ request, env, params }) => {
  const url = new URL(request.url);
  const fireAt = url.searchParams.get("fireAt");
  const id = params.id;

  if (!fireAt || typeof id !== "string") {
    return new Response("Missing fireAt or id", { status: 400 });
  }
  if (Number.isNaN(Date.parse(fireAt))) {
    return new Response("Invalid fireAt", { status: 400 });
  }

  await env.TIMERS_KV.delete(`timer:${fireAt}:${id}`);
  return new Response(null, { status: 204 });
};
