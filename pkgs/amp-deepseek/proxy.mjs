#!/usr/bin/env node
import { timingSafeEqual } from "node:crypto";
import http from "node:http";
import https from "node:https";
import { pathToFileURL } from "node:url";

const DEFAULT_PORT = 4014;
const DEFAULT_MAX_BODY_BYTES = 64 * 1024 * 1024;
const DEFAULT_UPSTREAM_TIMEOUT_MS = 600000;
const ALLOWED_REQUEST_HEADERS = new Set([
  "content-type",
  "accept",
  "anthropic-version",
  "anthropic-beta",
]);
const DROPPED_RESPONSE_HEADERS = new Set([
  "connection",
  "transfer-encoding",
  "content-length",
  "content-encoding",
  "set-cookie",
]);

function configFromEnv(env = process.env) {
  const protocol = env.UPSTREAM_PROTOCOL || "https";
  return {
    port: Number(env.PORT || DEFAULT_PORT),
    host: env.HOST || "127.0.0.1",
    upstreamProtocol: protocol,
    upstreamHost: env.UPSTREAM_HOST || "api.deepseek.com",
    upstreamPort: Number(env.UPSTREAM_PORT || (protocol === "http" ? 80 : 443)),
    upstreamPath: env.UPSTREAM_PATH ?? "/anthropic",
    upstreamAuthKey: env.UPSTREAM_AUTH_KEY || "",
    inboundAuthKey: env.INBOUND_AUTH_KEY || "",
    maxBodyBytes: Number(env.MAX_BODY_BYTES || DEFAULT_MAX_BODY_BYTES),
    upstreamTimeoutMs: Number(env.UPSTREAM_TIMEOUT_MS || DEFAULT_UPSTREAM_TIMEOUT_MS),
  };
}

function sendJson(res, status, payload) {
  const body = Buffer.from(JSON.stringify(payload));
  res.writeHead(status, {
    "content-type": "application/json",
    "content-length": body.length,
  });
  res.end(body);
}

function log(entry) {
  console.error(JSON.stringify({ ts: new Date().toISOString(), ...entry }));
}

function authorized(req, key) {
  if (!key) return false;
  const authorization = req.headers.authorization || "";
  const bearer = authorization.startsWith("Bearer ")
    ? authorization.slice("Bearer ".length)
    : "";
  const provided = bearer || req.headers["x-api-key"] || "";
  if (provided.length !== key.length) return false;
  return timingSafeEqual(Buffer.from(provided), Buffer.from(key));
}

function readBody(req, limit) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    let settled = false;
    const fail = (error) => {
      if (settled) return;
      settled = true;
      reject(error);
    };
    req.on("data", (chunk) => {
      if (settled) return;
      size += chunk.length;
      if (size > limit) {
        fail(Object.assign(new Error("body too large"), { code: "BODY_TOO_LARGE" }));
        return;
      }
      chunks.push(chunk);
    });
    req.on("end", () => {
      if (settled) return;
      settled = true;
      resolve(Buffer.concat(chunks));
    });
    req.on("error", fail);
  });
}

function upstreamHeaders(requestHeaders, payload, cfg) {
  const headers = {};
  for (const [name, value] of Object.entries(requestHeaders)) {
    const lower = name.toLowerCase();
    if (ALLOWED_REQUEST_HEADERS.has(lower)) headers[lower] = value;
  }
  headers.host = cfg.upstreamHost;
  headers["content-type"] ||= "application/json";
  headers.accept ||= "application/json";
  headers["anthropic-version"] ||= "2023-06-01";
  headers["accept-encoding"] = "identity";
  headers["content-length"] = Buffer.byteLength(payload);
  headers["user-agent"] = "amp-deepseek-proxy/1.0";
  if (cfg.upstreamAuthKey) headers["x-api-key"] = cfg.upstreamAuthKey;
  return headers;
}

function responseHeaders(headers) {
  const allowed = {};
  for (const [name, value] of Object.entries(headers)) {
    if (!DROPPED_RESPONSE_HEADERS.has(name.toLowerCase())) allowed[name] = value;
  }
  return allowed;
}

function createServer(cfg) {
  return http.createServer(async (req, res) => {
    if (req.method === "GET" && (req.url === "/health" || req.url === "/healthz")) {
      if (!cfg.upstreamAuthKey || !cfg.inboundAuthKey) {
        sendJson(res, 503, { ok: false, error: "missing credentials" });
        return;
      }
      sendJson(res, 200, {
        ok: true,
        upstream: `${cfg.upstreamProtocol}://${cfg.upstreamHost}${cfg.upstreamPath}`,
      });
      return;
    }

    if (
      req.method !== "POST" ||
      (req.url !== "/v1/messages" && req.url !== "/anthropic/v1/messages")
    ) {
      sendJson(res, 404, { error: "not found" });
      return;
    }

    if (!cfg.upstreamAuthKey || !cfg.inboundAuthKey) {
      sendJson(res, 503, { ok: false, error: "missing credentials" });
      return;
    }

    if (!authorized(req, cfg.inboundAuthKey)) {
      sendJson(res, 401, { error: "unauthorized" });
      return;
    }

    let payload;
    try {
      payload = await readBody(req, cfg.maxBodyBytes);
    } catch (error) {
      if (error.code === "BODY_TOO_LARGE") {
        sendJson(res, 413, { error: "body too large" });
        return;
      }
      sendJson(res, 400, { error: "invalid request body" });
      return;
    }

    const started = Date.now();
    const transport = cfg.upstreamProtocol === "http" ? http : https;
    const suffix = req.url.startsWith("/anthropic")
      ? req.url.slice("/anthropic".length)
      : req.url;
    const upstream = transport.request(
      {
        host: cfg.upstreamHost,
        port: cfg.upstreamPort,
        method: "POST",
        path: cfg.upstreamPath + suffix,
        headers: upstreamHeaders(req.headers, payload, cfg),
      },
      (up) => {
        res.writeHead(up.statusCode || 502, responseHeaders(up.headers));
        up.pipe(res);
        up.on("end", () => {
          log({
            event: "response",
            status: up.statusCode || 502,
            request_bytes: payload.length,
            duration_ms: Date.now() - started,
          });
        });
      },
    );

    upstream.setTimeout(cfg.upstreamTimeoutMs, () => {
      upstream.destroy(new Error("upstream timeout"));
      if (!res.headersSent) sendJson(res, 504, { error: "upstream timeout" });
    });

    upstream.on("error", (error) => {
      if (!res.headersSent) sendJson(res, 502, { error: "upstream unavailable" });
      else res.destroy();
      log({
        event: "upstream_error",
        status: 502,
        error: error.message,
        duration_ms: Date.now() - started,
      });
    });

    res.on("close", () => {
      if (!res.writableEnded) upstream.destroy();
    });

    upstream.end(payload);
  });
}

const isMain =
  process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href;

if (isMain) {
  const cfg = configFromEnv();
  createServer(cfg).listen(cfg.port, cfg.host);
}

export {
  authorized,
  configFromEnv,
  createServer,
  readBody,
  responseHeaders,
  upstreamHeaders,
};
