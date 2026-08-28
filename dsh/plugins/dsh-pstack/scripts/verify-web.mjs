import assert from "node:assert/strict";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { spawn } from "node:child_process";
import { join } from "node:path";
import { tmpdir } from "node:os";

const profile = await mkdtemp(join(tmpdir(), "pstack-web-"));
const chrome = spawn("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", [
  "--headless=new", "--disable-gpu", "--no-first-run", "--no-default-browser-check",
  "--remote-debugging-port=0", "--user-data-dir=" + profile, "http://127.0.0.1:3080/"
], { stdio: "ignore" });

async function waitFor(read, timeoutMs = 20000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    try { const value = await read(); if (value) return value; } catch {}
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error("timed out waiting for browser state");
}

try {
  const port = await waitFor(async () => Number((await readFile(join(profile, "DevToolsActivePort"), "utf8")).split(/\r?\n/)[0]));
  const target = await waitFor(async () => {
    const response = await fetch("http://127.0.0.1:" + port + "/json");
    return (await response.json()).find((item) => item.type === "page" && item.webSocketDebuggerUrl);
  });
  const socket = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => {
    socket.addEventListener("open", resolve, { once: true });
    socket.addEventListener("error", reject, { once: true });
  });
  let id = 0;
  const pending = new Map();
  socket.addEventListener("message", (event) => {
    const message = JSON.parse(event.data);
    const entry = pending.get(message.id);
    if (!entry) return;
    pending.delete(message.id);
    message.error ? entry.reject(new Error(message.error.message)) : entry.resolve(message.result);
  });
  const command = (method, params = {}) => new Promise((resolve, reject) => {
    const next = ++id;
    pending.set(next, { resolve, reject });
    socket.send(JSON.stringify({ id: next, method, params }));
  });
  const evaluate = async (expression) => {
    const response = await command("Runtime.evaluate", { expression, awaitPromise: true, returnByValue: true });
    if (response.exceptionDetails) throw new Error(response.exceptionDetails.text);
    return response.result.value;
  };
  const clickMatching = async (labels) => {
    const expression = "(() => { const labels = " + JSON.stringify(labels.map((value) => value.toLowerCase())) + "; const elements = [...document.querySelectorAll('button,a,[role=button],[role=tab]')]; const target = elements.find((element) => { const values = [element.innerText, element.textContent, element.getAttribute('aria-label'), element.getAttribute('title')].filter(Boolean).map((value) => value.trim().toLowerCase()); return values.some((value) => labels.some((label) => value === label || value.includes(label))); }); if (!target) return false; target.click(); return true; })()";
    return evaluate(expression);
  };
  await command("Runtime.enable");
  await waitFor(async () => (await evaluate("document.readyState")) === "complete");
  await waitFor(async () => (await evaluate("document.body && document.body.innerText.length")) > 20);
  let openedSettings = await clickMatching(["settings", "preferences"]);
  if (!openedSettings && await clickMatching(["open sidebar"])) {
    await waitFor(async () => /settings|preferences/i.test(await evaluate("document.body.innerText")) || await evaluate("[...document.querySelectorAll('button,a,[role=button]')].some((element) => /settings|preferences/i.test([element.innerText, element.getAttribute('aria-label'), element.getAttribute('title')].filter(Boolean).join(' ')))"));
    openedSettings = await clickMatching(["settings", "preferences"]);
  }
  if (!openedSettings) {
    const diagnostic = await evaluate("JSON.stringify({body: document.body.innerText.slice(0, 4000), controls: [...document.querySelectorAll('button,a,[role=button],[role=tab]')].map((element) => ({text: (element.innerText || element.textContent || '').trim(), aria: element.getAttribute('aria-label'), title: element.getAttribute('title')})).slice(0, 100)})");
    process.stderr.write(diagnostic + "\n");
  }
  assert.equal(openedSettings, true, "settings control not found");
  await waitFor(async () => /plugins/i.test(await evaluate("document.body.innerText")));
  assert.equal(await clickMatching(["plugins"]), true, "plugins section not found");
  await waitFor(async () => /configurable|installed/i.test(await evaluate("document.body.innerText")));
  await clickMatching(["configurable"]);
  const body = await waitFor(async () => {
    const text = await evaluate("document.body.innerText");
    return /pstack/i.test(text) ? text : false;
  });
  assert.match(body, /Model routes for code, judgment, and parallel workers/i);
  const openedCard = await evaluate("(() => { const target = [...document.querySelectorAll('button')].find((element) => (element.innerText || '').includes('Model routes for code, judgment, and parallel workers.')); if (!target) return false; target.click(); return true; })()");
  assert.equal(openedCard, true, "pstack card not found");
  await new Promise((resolve) => setTimeout(resolve, 300));
  const expanded = await evaluate("JSON.stringify({text: document.body.innerText.slice(-5000), values: [...document.querySelectorAll('input,select')].map((element) => element.value), controls: [...document.querySelectorAll('button')].map((element) => element.innerText.trim()).filter(Boolean).slice(-50)})");
  const expandedState = JSON.parse(expanded);
  if (!/Code/.test(expandedState.text) || !/Judgment/.test(expandedState.text) || !/Workers/.test(expandedState.text)) process.stderr.write(expanded + "\n");
  assert.match(expandedState.text, /Code/);
  assert.match(expandedState.text, /Judgment/);
  assert.match(expandedState.text, /Workers/);
  process.stdout.write(JSON.stringify({ verified: true }) + "\n");
  socket.close();
} finally {
  chrome.kill("SIGTERM");
  await new Promise((resolve) => chrome.once("exit", resolve));
  await rm(profile, { recursive: true, force: true });
}
