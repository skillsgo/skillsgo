/*
 * [INPUT]: Depends on Vercel request-scoped OIDC and SKILLSGO_BRIDGE_TOKEN for authenticated skills.sh access.
 * [OUTPUT]: Provides a bounded POST endpoint that returns paginated skills.sh leaderboard snapshots.
 * [POS]: Serves as the stateless authentication bridge between SkillsGo Hub and skills.sh.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */

import { timingSafeEqual } from "node:crypto";

const UPSTREAM_URL = "https://skills.sh/api/v1/skills";
const ALLOWED_VIEWS = new Set(["all-time", "trending", "hot"]);
const MAX_PAGE_COUNT = 10;
const MAX_PER_PAGE = 500;

function json(status, body, headers = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8", ...headers },
  });
}

function authorized(request, expectedToken) {
  if (!expectedToken) return false;
  const header = request.headers.get("authorization") ?? "";
  const suppliedToken = header.startsWith("Bearer ") ? header.slice(7) : "";
  const supplied = Buffer.from(suppliedToken);
  const expected = Buffer.from(expectedToken);
  return supplied.length === expected.length && timingSafeEqual(supplied, expected);
}

function integer(value, fallback) {
  return value === undefined ? fallback : Number.isInteger(value) ? value : NaN;
}

function validate(body) {
  const view = body?.view ?? "all-time";
  const startPage = integer(body?.startPage, 0);
  const pageCount = integer(body?.pageCount, 1);
  const perPage = integer(body?.perPage, MAX_PER_PAGE);

  if (!ALLOWED_VIEWS.has(view)) return { error: "invalid view" };
  if (!Number.isInteger(startPage) || startPage < 0) return { error: "invalid startPage" };
  if (!Number.isInteger(pageCount) || pageCount < 1 || pageCount > MAX_PAGE_COUNT) {
    return { error: `pageCount must be between 1 and ${MAX_PAGE_COUNT}` };
  }
  if (!Number.isInteger(perPage) || perPage < 1 || perPage > MAX_PER_PAGE) {
    return { error: `perPage must be between 1 and ${MAX_PER_PAGE}` };
  }
  return { view, startPage, pageCount, perPage };
}

async function fetchPage(fetchImpl, oidcToken, request, page) {
  const url = new URL(UPSTREAM_URL);
  url.searchParams.set("view", request.view);
  url.searchParams.set("page", String(page));
  url.searchParams.set("per_page", String(request.perPage));

  const response = await fetchImpl(url, {
    headers: { authorization: `Bearer ${oidcToken}` },
  });
  const text = await response.text();
  let body;
  try {
    body = JSON.parse(text);
  } catch {
    body = { raw: text };
  }

  return {
    page,
    status: response.status,
    body,
    rateLimit: {
      limit: response.headers.get("x-ratelimit-limit"),
      remaining: response.headers.get("x-ratelimit-remaining"),
      reset: response.headers.get("x-ratelimit-reset"),
      retryAfter: response.headers.get("retry-after"),
    },
  };
}

export function createHandler({ env = process.env, fetchImpl = fetch } = {}) {
  return async function handler(request) {
    if (request.method !== "POST") {
      return json(405, { error: "method_not_allowed" }, { allow: "POST" });
    }
    if (!authorized(request, env.SKILLSGO_BRIDGE_TOKEN)) {
      return json(401, { error: "unauthorized" });
    }
    const oidcToken = request.headers.get("x-vercel-oidc-token") ?? env.VERCEL_OIDC_TOKEN;
    if (!oidcToken) {
      return json(503, { error: "oidc_unavailable" });
    }

    let body;
    try {
      body = await request.json();
    } catch {
      return json(400, { error: "invalid_json" });
    }
    const parsed = validate(body);
    if (parsed.error) return json(400, { error: "invalid_request", message: parsed.error });

    try {
      const pages = await Promise.all(
        Array.from({ length: parsed.pageCount }, (_, offset) =>
          fetchPage(fetchImpl, oidcToken, parsed, parsed.startPage + offset),
        ),
      );
      return json(200, { fetchedAt: new Date().toISOString(), pages });
    } catch {
      return json(502, { error: "upstream_unavailable" });
    }
  };
}

async function nodeBody(request) {
  if (request.body !== undefined) {
    if (typeof request.body === "string" || Buffer.isBuffer(request.body)) return request.body;
    return JSON.stringify(request.body);
  }
  const chunks = [];
  for await (const chunk of request) chunks.push(chunk);
  return Buffer.concat(chunks);
}

async function toWebRequest(request) {
  const headers = new Headers();
  for (const [name, value] of Object.entries(request.headers ?? {})) {
    if (Array.isArray(value)) {
      for (const item of value) headers.append(name, item);
    } else if (value !== undefined) {
      headers.set(name, value);
    }
  }
  const method = request.method ?? "GET";
  return new Request(`https://${headers.get("host") ?? "skillssh.vercel.app"}${request.url ?? "/"}`, {
    method,
    headers,
    body: method === "GET" || method === "HEAD" ? undefined : await nodeBody(request),
  });
}

export function createNodeHandler(options) {
  const webHandler = createHandler(options);
  return async function nodeHandler(request, response) {
    const result = await webHandler(await toWebRequest(request));
    response.statusCode = result.status;
    for (const [name, value] of result.headers) response.setHeader(name, value);
    response.end(await result.text());
  };
}

export default createNodeHandler();
