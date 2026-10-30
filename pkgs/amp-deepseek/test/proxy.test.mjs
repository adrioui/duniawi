import assert from "node:assert/strict";
import http from "node:http";
import test from "node:test";

import { configFromEnv, createServer } from "../proxy.mjs";

function start(server) {
  return new Promise((resolve) => {
    server.listen(0, "127.0.0.1", () => resolve(server.address().port));
  });
}

function stop(server) {
  return new Promise((resolve) => server.close(resolve));
}

async function fakeUpstream(handler) {
  const state = { headers: null, body: null };
  const server = http.createServer((req, res) => {
    const chunks = [];
    req.on("data", (chunk) => chunks.push(chunk));
    req.on("end", () => {
      state.headers = req.headers;
      state.body = Buffer.concat(chunks).toString("utf8");
      handler(req, res, state);
    });
  });
  return { server, state };
}

function config(port, overrides = {}) {
  return {
    ...configFromEnv({
      PORT: "0",
      UPSTREAM_PROTOCOL: "http",
      UPSTREAM_HOST: "127.0.0.1",
      UPSTREAM_PORT: String(port),
      UPSTREAM_PATH: "",
      UPSTREAM_AUTH_KEY: "upstream-secret",
      INBOUND_AUTH_KEY: "inbound-secret",
    }),
    ...overrides,
  };
}

test("health is 200 when the upstream key is configured", async () => {
  const server = createServer(config(1));
  const port = await start(server);
  const response = await fetch(`http://127.0.0.1:${port}/health`);
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.ok, true);
  await stop(server);
});

test("health is 503 when the upstream key is missing", async () => {
  const server = createServer(config(1, { upstreamAuthKey: "" }));
  const port = await start(server);
  const response = await fetch(`http://127.0.0.1:${port}/health`);
  assert.equal(response.status, 503);
  await stop(server);
});

test("health is 503 when the inbound key is missing", async () => {
  const server = createServer(config(1, { inboundAuthKey: "" }));
  const port = await start(server);
  const response = await fetch(`http://127.0.0.1:${port}/health`);
  assert.equal(response.status, 503);
  await stop(server);
});

test("rejects a request with the wrong inbound key", async () => {
  const upstream = await fakeUpstream((req, res) => {
    res.writeHead(200, { "content-type": "application/json" });
    res.end("{}");
  });
  const upstreamPort = await start(upstream.server);
  const server = createServer(config(upstreamPort));
  const port = await start(server);

  const response = await fetch(`http://127.0.0.1:${port}/v1/messages`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: "Bearer wrong",
    },
    body: "{}",
  });

  assert.equal(response.status, 401);
  assert.equal(upstream.state.body, null);

  await stop(server);
  await stop(upstream.server);
});

test("forwards the body and injects only the upstream credential", async () => {
  const upstream = await fakeUpstream((req, res) => {
    res.writeHead(200, { "content-type": "application/json" });
    res.end('{"ok":true}');
  });
  const upstreamPort = await start(upstream.server);
  const server = createServer(config(upstreamPort));
  const port = await start(server);

  const payload = JSON.stringify({
    model: "deepseek-flash",
    max_tokens: 16,
    messages: [{ role: "user", content: "hi" }],
  });
  const response = await fetch(`http://127.0.0.1:${port}/v1/messages`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "anthropic-version": "2023-06-01",
      authorization: "Bearer inbound-secret",
      "x-api-key": "incoming",
      "cf-access-client-id": "access-id",
      "cf-access-client-secret": "access-secret",
      "x-amp-thread-id": "T-test",
    },
    body: payload,
  });

  assert.equal(response.status, 200);
  assert.equal(upstream.state.body, payload);
  assert.equal(upstream.state.headers["x-api-key"], "upstream-secret");
  assert.equal(upstream.state.headers.authorization, undefined);
  assert.equal(upstream.state.headers["cf-access-client-id"], undefined);
  assert.equal(upstream.state.headers["cf-access-client-secret"], undefined);
  assert.equal(upstream.state.headers["x-amp-thread-id"], undefined);
  assert.equal(upstream.state.headers["content-type"], "application/json");
  assert.equal(upstream.state.headers["anthropic-version"], "2023-06-01");
  assert.equal(
    upstream.state.headers["content-length"],
    String(Buffer.byteLength(payload)),
  );

  await stop(server);
  await stop(upstream.server);
});

test("passes through an SSE response", async () => {
  const upstream = await fakeUpstream((req, res) => {
    res.writeHead(200, { "content-type": "text/event-stream" });
    res.write("event: message_start\ndata: {\"type\":\"message_start\"}\n\n");
    res.write("event: message_stop\ndata: {\"type\":\"message_stop\"}\n\n");
    res.end();
  });
  const upstreamPort = await start(upstream.server);
  const server = createServer(config(upstreamPort));
  const port = await start(server);

  const response = await fetch(`http://127.0.0.1:${port}/v1/messages`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: "Bearer inbound-secret",
    },
    body: "{}",
  });
  const body = await response.text();

  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type"), /text\/event-stream/);
  assert.match(body, /message_start/);
  assert.match(body, /message_stop/);

  await stop(server);
  await stop(upstream.server);
});

test("rejects an oversized body", async () => {
  const upstream = await fakeUpstream((req, res) => {
    res.writeHead(200, { "content-type": "application/json" });
    res.end("{}");
  });
  const upstreamPort = await start(upstream.server);
  const server = createServer(config(upstreamPort, { maxBodyBytes: 10 }));
  const port = await start(server);

  const response = await fetch(`http://127.0.0.1:${port}/v1/messages`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: "Bearer inbound-secret",
    },
    body: JSON.stringify({ long: "x".repeat(100) }),
  });

  assert.equal(response.status, 413);

  await stop(server);
  await stop(upstream.server);
});

test("passes a non-JSON body through unchanged", async () => {
  const upstream = await fakeUpstream((req, res) => {
    res.writeHead(200, { "content-type": "text/plain" });
    res.end("ok");
  });
  const upstreamPort = await start(upstream.server);
  const server = createServer(config(upstreamPort));
  const port = await start(server);

  const response = await fetch(`http://127.0.0.1:${port}/v1/messages`, {
    method: "POST",
    headers: {
      "content-type": "text/plain",
      authorization: "Bearer inbound-secret",
    },
    body: "not-json",
  });

  assert.equal(response.status, 200);
  assert.equal(upstream.state.body, "not-json");

  await stop(server);
  await stop(upstream.server);
});
