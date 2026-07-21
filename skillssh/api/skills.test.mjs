/*
 * [INPUT]: Depends on api/skills.mjs and Node.js test utilities for isolated request simulations.
 * [OUTPUT]: Verifies bridge authentication, input bounds, OIDC forwarding, and upstream error behavior.
 * [POS]: Serves as the executable HTTP contract for the stateless skills.sh bridge.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */

import assert from "node:assert/strict";
import test from "node:test";
import { createHandler, createNodeHandler } from "./skills.mjs";

const endpoint = "https://bridge.example/api/skills";
const env = { SKILLSGO_BRIDGE_TOKEN: "bridge-secret", VERCEL_OIDC_TOKEN: "oidc-token" };

function request(body, token = "bridge-secret") {
  return new Request(endpoint, {
    method: "POST",
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
    body: JSON.stringify(body),
  });
}

test("rejects unauthorized callers", async () => {
  const response = await createHandler({ env })(request({}, "wrong"));
  assert.equal(response.status, 401);
});

test("rejects batches larger than the configured bound", async () => {
  const response = await createHandler({ env })(request({ pageCount: 11 }));
  assert.equal(response.status, 400);
  assert.equal((await response.json()).error, "invalid_request");
});

test("fetches requested pages with Vercel OIDC", async () => {
  const calls = [];
  const fetchImpl = async (url, options) => {
    calls.push({ url: url.toString(), authorization: options.headers.authorization });
    return Response.json(
      { data: [], pagination: { page: Number(url.searchParams.get("page")), hasMore: true } },
      { headers: { "x-ratelimit-remaining": "599" } },
    );
  };
  const response = await createHandler({ env, fetchImpl })(
    request({ view: "all-time", startPage: 4, pageCount: 2, perPage: 500 }),
  );
  const result = await response.json();

  assert.equal(response.status, 200);
  assert.deepEqual(calls, [
    {
      url: "https://skills.sh/api/v1/skills?view=all-time&page=4&per_page=500",
      authorization: "Bearer oidc-token",
    },
    {
      url: "https://skills.sh/api/v1/skills?view=all-time&page=5&per_page=500",
      authorization: "Bearer oidc-token",
    },
  ]);
  assert.deepEqual(result.pages.map((page) => page.page), [4, 5]);
  assert.equal(result.pages[0].rateLimit.remaining, "599");
});

test("prefers the request-scoped Vercel OIDC header", async () => {
  const oidcTokens = [];
  const fetchImpl = async (_url, options) => {
    oidcTokens.push(options.headers.authorization);
    return Response.json({ data: [], pagination: { page: 0, hasMore: false } });
  };
  const incoming = request({});
  incoming.headers.set("x-vercel-oidc-token", "request-oidc-token");

  const response = await createHandler({ env, fetchImpl })(incoming);

  assert.equal(response.status, 200);
  assert.deepEqual(oidcTokens, ["Bearer request-oidc-token"]);
});

test("does not expose upstream exception details", async () => {
  const response = await createHandler({
    env,
    fetchImpl: async () => {
      throw new Error("sensitive network detail");
    },
  })(request({}));
  assert.equal(response.status, 502);
  assert.deepEqual(await response.json(), { error: "upstream_unavailable" });
});

test("adapts the Vercel Node request and response contract", async () => {
  const headers = new Map();
  let payload = "";
  const response = {
    statusCode: 0,
    setHeader: (name, value) => headers.set(name, value),
    end: (body) => {
      payload = body;
    },
  };
  const fetchImpl = async () => Response.json({ data: [], pagination: { page: 0, hasMore: false } });

  await createNodeHandler({ env, fetchImpl })(
    {
      method: "POST",
      url: "/api/skills",
      headers: {
        host: "bridge.example",
        authorization: "Bearer bridge-secret",
        "content-type": "application/json",
        "x-vercel-oidc-token": "request-oidc-token",
      },
      body: { view: "all-time", pageCount: 1, perPage: 1 },
    },
    response,
  );

  assert.equal(response.statusCode, 200);
  assert.match(headers.get("content-type"), /^application\/json/);
  assert.equal(JSON.parse(payload).pages[0].status, 200);
});
