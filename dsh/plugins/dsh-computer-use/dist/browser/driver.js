import fs from 'node:fs';
import path from 'node:path';
import { chromium, } from 'playwright-core';
import { resolveWorkspacePaths } from '../actions.js';
import { ComputerUseError, abortError, throwIfAborted } from '../errors.js';
import { MonotonicIds } from '../ids.js';
import { AbortableMutex } from '../mutex.js';
import { mergeOcrNodes } from '../observation.js';
import { buildSemanticNodes } from './a11y.js';
import { decodeDocumentSnapshots, } from './cdp.js';
const MAIN_FRAME_KEY = '__main__';
const DEFAULT_VIEWPORT = { width: 1280, height: 800 };
function sanitizeId(id) {
    const cleaned = id.replace(/[^a-zA-Z0-9._-]/g, '_');
    return cleaned.length > 0 ? cleaned : 'session';
}
function clamp(value, min, max) {
    if (Number.isNaN(value))
        return min;
    return Math.max(min, Math.min(max, value));
}
function pairFrameTree(cdpNode, pwFrame, frameIdToFrame, frameToId) {
    if (!cdpNode)
        return;
    frameIdToFrame.set(cdpNode.frame.id, pwFrame);
    frameToId.set(pwFrame, cdpNode.frame.id);
    const pwChildren = pwFrame.childFrames();
    const cdpChildren = cdpNode.childFrames ?? [];
    for (let i = 0; i < cdpChildren.length; i++) {
        const child = cdpChildren[i];
        const pwChild = pwChildren[i];
        if (child && pwChild)
            pairFrameTree(child, pwChild, frameIdToFrame, frameToId);
    }
}
/**
 * One Playwright Chromium process (system Chrome), isolated BrowserContext and
 * pages per execution.sessionId, per-session serialization, CDP accessibility
 * snapshots and browser actions. Designed to be owned as a host singleton.
 */
export class BrowserDriver {
    config;
    browser = null;
    sessions = new Map();
    pageRegistrations = new WeakMap();
    ocr;
    constructor(config, deps = {}) {
        this.config = config;
        this.ocr = deps.ocr;
    }
    /** Observe the current browser state as a text-only semantic snapshot. */
    async observe(request, execution) {
        throwIfAborted(execution.signal);
        const session = this.getOrCreateSession(execution);
        return await this.runGuarded(session, execution.signal, async () => {
            const tab = await this.ensureActiveTab(session, execution.signal);
            return await this.captureSnapshot(session, tab, request, execution);
        });
    }
    /** Perform a single browser action and return the resulting snapshot. */
    async action(request, execution) {
        throwIfAborted(execution.signal);
        const session = this.getOrCreateSession(execution);
        return await this.runGuarded(session, execution.signal, async () => {
            await this.performAction(session, request, execution);
            const tab = await this.ensureActiveTab(session, execution.signal);
            await this.settle(execution.signal);
            const snapshot = await this.captureSnapshot(session, tab, request, execution);
            return { status: 'success', snapshot };
        });
    }
    /** Close a session's context, persist its storage state, and forget it. */
    async cleanupSession(sessionId) {
        const session = this.sessions.get(sessionId);
        if (!session)
            return;
        await session.mutex.run(async () => {
            await this.teardownContext(session);
        });
        this.sessions.delete(sessionId);
    }
    /** Close every session and the shared browser process. */
    async dispose() {
        for (const session of this.sessions.values()) {
            await session.mutex.run(async () => {
                await this.teardownContext(session);
            });
        }
        this.sessions.clear();
        if (this.browser) {
            try {
                await this.browser.close();
            }
            catch {
                // ignore
            }
            this.browser = null;
        }
    }
    // --- lifecycle -----------------------------------------------------------
    getOrCreateSession(execution) {
        const existing = this.sessions.get(execution.sessionId);
        if (existing)
            return existing;
        const safeId = sanitizeId(execution.sessionId);
        const session = {
            id: execution.sessionId,
            context: null,
            tabs: new Map(),
            order: [],
            activeTabId: null,
            epoch: new Map(),
            refs: new Map(),
            refKeyToRef: new Map(),
            refIds: new MonotonicIds('b'),
            snapshotIds: new MonotonicIds('s'),
            lastSnapshotId: null,
            navigationSeq: 0,
            snapshotSeq: 0,
            mutex: new AbortableMutex(),
            storageStatePath: path.join(this.config.stateDir, safeId, 'storage-state.json'),
            screenshotsDir: path.join(this.config.stateDir, safeId, 'screenshots'),
            aborted: false,
            pendingClose: null,
            tabCounter: 0,
        };
        this.sessions.set(execution.sessionId, session);
        return session;
    }
    async ensureBrowser() {
        if (this.browser)
            return this.browser;
        this.browser = await chromium.launch({
            executablePath: this.config.chromeExecutablePath,
            headless: this.config.headless,
            args: ['--no-first-run', '--no-default-browser-check'],
        });
        return this.browser;
    }
    async createContext(session) {
        const browser = await this.ensureBrowser();
        const options = { viewport: DEFAULT_VIEWPORT };
        const storageState = await this.loadStorageState(session.storageStatePath);
        if (storageState !== undefined) {
            options.storageState = storageState;
        }
        const context = await browser.newContext(options);
        context.on('page', (page) => {
            this.registerTab(session, page).catch(() => { });
        });
        return context;
    }
    async loadStorageState(filePath) {
        try {
            const raw = await fs.promises.readFile(filePath, 'utf8');
            return JSON.parse(raw);
        }
        catch {
            return undefined;
        }
    }
    registerTab(session, page) {
        const existing = this.pageRegistrations.get(page);
        if (existing)
            return existing;
        const promise = this.registerTabInner(session, page);
        this.pageRegistrations.set(page, promise);
        return promise;
    }
    async registerTabInner(session, page) {
        for (const tab of session.tabs.values()) {
            if (tab.page === page)
                return tab;
        }
        const context = session.context ?? (session.context = await this.createContext(session));
        const tabId = `tab-${++session.tabCounter}`;
        const cdp = await context.newCDPSession(page);
        await cdp.send('DOM.enable').catch(() => { });
        await cdp.send('Page.enable').catch(() => { });
        const tab = { tabId, page, cdp };
        session.tabs.set(tabId, tab);
        session.order.push(tabId);
        page.on('framenavigated', (frame) => {
            if (frame === page.mainFrame())
                this.onNavigation(session, tabId);
        });
        page.on('close', () => {
            const index = session.order.indexOf(tabId);
            if (index >= 0)
                session.order.splice(index, 1);
            session.tabs.delete(tabId);
            if (session.activeTabId === tabId)
                session.activeTabId = session.order[0] ?? null;
        });
        if (session.activeTabId === null)
            session.activeTabId = tabId;
        return tab;
    }
    async ensureActiveTab(session, signal) {
        throwIfAborted(signal);
        if (session.context === null) {
            session.context = await this.createContext(session);
        }
        if (session.activeTabId === null || !session.tabs.has(session.activeTabId)) {
            const page = await session.context.newPage();
            await this.registerTab(session, page);
        }
        const tab = session.tabs.get(session.activeTabId);
        if (!tab)
            throw new ComputerUseError('INTERNAL', 'failed to create an active tab');
        return tab;
    }
    ensureActiveSelection(session) {
        if (session.activeTabId !== null && session.tabs.has(session.activeTabId))
            return;
        session.activeTabId = session.order[0] ?? null;
    }
    onNavigation(session, tabId) {
        for (const [ref, entry] of session.refs) {
            if (entry.tabId !== tabId)
                continue;
            session.refs.delete(ref);
            session.refKeyToRef.delete(`${entry.frameId}:${entry.backendNodeId}`);
        }
        session.epoch.set(tabId, (session.epoch.get(tabId) ?? 0) + 1);
        session.navigationSeq++;
    }
    async teardownContext(session) {
        const context = session.context;
        session.context = null;
        session.tabs.clear();
        session.order.length = 0;
        session.activeTabId = null;
        session.refs.clear();
        session.refKeyToRef.clear();
        session.lastSnapshotId = null;
        if (context) {
            try {
                await fs.promises.mkdir(path.dirname(session.storageStatePath), { recursive: true });
                const state = await context.storageState();
                await fs.promises.writeFile(session.storageStatePath, JSON.stringify(state, null, 2), 'utf8');
            }
            catch {
                // best effort
            }
            try {
                await context.close();
            }
            catch {
                // ignore
            }
        }
    }
    async runGuarded(session, signal, op) {
        session.aborted = false;
        session.pendingClose = null;
        const onAbort = () => {
            session.aborted = true;
            if (session.context !== null) {
                session.pendingClose = this.teardownContext(session).catch(() => { });
            }
            else {
                session.pendingClose = Promise.resolve();
            }
        };
        const remove = () => signal.removeEventListener('abort', onAbort);
        if (signal.aborted) {
            onAbort();
        }
        else {
            signal.addEventListener('abort', onAbort, { once: true });
        }
        try {
            return await session.mutex.run(op, signal);
        }
        catch (error) {
            if (signal.aborted || session.aborted) {
                const pendingClose = session.pendingClose;
                if (pendingClose)
                    await pendingClose.catch(() => { });
                throw abortError();
            }
            throw error;
        }
        finally {
            remove();
        }
    }
    // --- observation ---------------------------------------------------------
    async captureSnapshot(session, tab, request, execution) {
        const { page, cdp } = tab;
        const warnings = [];
        const snapshotId = session.snapshotIds.next();
        throwIfAborted(execution.signal);
        await cdp.send('Accessibility.enable').catch(() => { });
        await cdp.send('DOMSnapshot.enable').catch(() => { });
        const frameIdToFrame = new Map();
        const frameToId = new Map();
        try {
            const { frameTree } = (await cdp.send('Page.getFrameTree'));
            pairFrameTree(frameTree, page.mainFrame(), frameIdToFrame, frameToId);
            tab.mainFrameId = frameTree.frame.id;
        }
        catch {
            warnings.push('Page.getFrameTree failed; iframe support may be incomplete');
        }
        let frameData = new Map();
        try {
            const snap = (await cdp.send('DOMSnapshot.captureSnapshot', {
                computedStyles: [],
            }));
            frameData = decodeDocumentSnapshots(snap);
        }
        catch {
            warnings.push('DOMSnapshot.captureSnapshot failed; node bounds unavailable');
        }
        const nodes = [];
        for (const frame of page.frames()) {
            throwIfAborted(execution.signal);
            const frameId = frameToId.get(frame);
            const isMain = frame === page.mainFrame();
            const axNodes = await this.getFrameAxNodes(tab, frame, frameId, isMain, warnings, execution.signal);
            if (axNodes.length === 0)
                continue;
            const snap = frameId !== undefined ? frameData.get(frameId) : undefined;
            const origin = await this.frameOrigin(frame);
            const viewportOffset = {
                x: origin.x - (snap?.scrollX ?? 0),
                y: origin.y - (snap?.scrollY ?? 0),
            };
            const built = buildSemanticNodes(axNodes, {
                viewportOffset,
                bounds: snap?.bounds ?? new Map(),
                passwordNodes: snap?.passwordNodes ?? new Set(),
                clickableNodes: snap?.clickableNodes ?? new Set(),
                assignRef: (backendNodeId, rect) => this.assignRef(session, tab.tabId, frameId ?? MAIN_FRAME_KEY, backendNodeId, rect),
            });
            nodes.push(...built);
        }
        let truncated = nodes.length > this.config.maxNodes;
        let bounded = nodes.slice(0, this.config.maxNodes);
        let screenshotPath;
        let png;
        if (request.saveScreenshot === true) {
            png = await page.screenshot({ type: 'png' }).catch(() => undefined);
            if (png) {
                screenshotPath = await this.writeScreenshot(session, snapshotId, png);
                if (screenshotPath === undefined)
                    warnings.push('screenshot could not be written');
            }
            else {
                warnings.push('screenshot capture failed');
            }
        }
        if (this.ocr && this.shouldOcr(request, bounded)) {
            const buf = png ?? (await page.screenshot({ type: 'png' }).catch(() => undefined));
            if (buf) {
                try {
                    const items = await this.ocr(buf, { sessionId: session.id, signal: execution.signal });
                    const ocrNodes = items.flatMap((item) => {
                        if (item.text.trim().length === 0 || item.frame.width <= 0 || item.frame.height <= 0)
                            return [];
                        const ref = this.assignCoordinateRef(session, tab.tabId, item.frame, item.text);
                        return [{
                                ref,
                                depth: 0,
                                role: 'text',
                                name: item.text,
                                frame: item.frame,
                                source: 'ocr',
                                interactive: true,
                                ...(item.confidence === undefined ? {} : { states: [`confidence:${item.confidence.toFixed(2)}`] }),
                            }];
                    });
                    const merged = mergeOcrNodes(bounded, ocrNodes);
                    truncated ||= merged.length > this.config.maxNodes;
                    bounded = merged.slice(0, this.config.maxNodes);
                }
                catch (error) {
                    if (execution.signal.aborted)
                        throw error;
                    warnings.push(`OCR failed: ${String(error)}`);
                }
            }
        }
        else if (request.ocr === 'always' && !this.ocr) {
            warnings.push('OCR was requested but no OCR callback is configured');
        }
        session.lastSnapshotId = snapshotId;
        session.snapshotSeq = session.navigationSeq;
        const metadata = await this.buildMetadata(session, tab, bounded);
        const snapshot = {
            id: snapshotId,
            surface: 'browser',
            createdAt: Date.now(),
            metadata,
            nodes: bounded,
            warnings,
            truncated,
        };
        if (screenshotPath !== undefined)
            snapshot.screenshotPath = screenshotPath;
        return snapshot;
    }
    async getFrameAxNodes(tab, frame, frameId, isMain, warnings, signal) {
        throwIfAborted(signal);
        if (isMain || frameId !== undefined) {
            try {
                const params = frameId !== undefined ? { frameId } : {};
                const { nodes } = (await tab.cdp.send('Accessibility.getFullAXTree', params));
                if (nodes.length > 0 || isMain)
                    return nodes;
            }
            catch {
                // fall through to the dedicated-session path below
            }
        }
        try {
            const context = frame.page().context();
            const dedicated = await context.newCDPSession(frame);
            await dedicated.send('Accessibility.enable').catch(() => { });
            const { nodes } = (await dedicated.send('Accessibility.getFullAXTree', {}));
            return nodes;
        }
        catch (error) {
            warnings.push(`accessibility tree unavailable for frame ${frame.url()}: ${String(error)}`);
            return [];
        }
    }
    async frameOrigin(frame) {
        if (frame === frame.page().mainFrame())
            return { x: 0, y: 0 };
        try {
            const element = await frame.frameElement();
            const box = element ? await element.boundingBox() : null;
            if (box)
                return { x: box.x, y: box.y };
        }
        catch {
            // ignore
        }
        return { x: 0, y: 0 };
    }
    assignRef(session, tabId, frameId, backendNodeId, rect) {
        const key = `${frameId}:${backendNodeId}`;
        const existing = session.refKeyToRef.get(key);
        if (existing !== undefined)
            return existing;
        const ref = session.refIds.next();
        const entry = {
            tabId,
            frameId,
            backendNodeId,
            epoch: session.epoch.get(tabId) ?? 0,
        };
        if (rect !== undefined)
            entry.frame = rect;
        session.refs.set(ref, entry);
        session.refKeyToRef.set(key, ref);
        return ref;
    }
    assignCoordinateRef(session, tabId, frame, text) {
        const key = `ocr:${tabId}:${text}:${Math.round(frame.x)}:${Math.round(frame.y)}:${Math.round(frame.width)}:${Math.round(frame.height)}`;
        const existing = session.refKeyToRef.get(key);
        if (existing !== undefined)
            return existing;
        const ref = session.refIds.next();
        session.refs.set(ref, {
            tabId,
            frameId: MAIN_FRAME_KEY,
            backendNodeId: -1,
            epoch: session.epoch.get(tabId) ?? 0,
            frame,
        });
        session.refKeyToRef.set(key, ref);
        return ref;
    }
    shouldOcr(request, nodes) {
        if (request.ocr === 'always')
            return true;
        if (request.ocr === 'never')
            return false;
        return !nodes.some((node) => node.interactive || (node.name?.trim().length ?? 0) > 0 || (node.value?.trim().length ?? 0) > 0);
    }
    async writeScreenshot(session, snapshotId, png) {
        try {
            await fs.promises.mkdir(session.screenshotsDir, { recursive: true, mode: 0o700 });
            const file = path.join(session.screenshotsDir, `${snapshotId}.png`);
            await fs.promises.writeFile(file, png, { mode: 0o600 });
            return file;
        }
        catch {
            return undefined;
        }
    }
    async buildMetadata(session, tab, nodes) {
        const metadata = {};
        try {
            metadata.title = await tab.page.title();
        }
        catch {
            // ignore
        }
        metadata.url = tab.page.url();
        metadata.tabId = tab.tabId;
        const tabs = [];
        for (const tabId of session.order) {
            const t = session.tabs.get(tabId);
            if (!t)
                continue;
            try {
                tabs.push({
                    id: tabId,
                    title: await t.page.title(),
                    url: t.page.url(),
                    active: tabId === tab.tabId,
                });
            }
            catch {
                tabs.push({ id: tabId, title: '', url: '', active: tabId === tab.tabId });
            }
        }
        metadata.tabs = tabs;
        try {
            const size = await tab.page.evaluate(() => ({
                width: window.innerWidth,
                height: window.innerHeight,
            }));
            metadata.viewport = { x: 0, y: 0, width: size.width, height: size.height };
        }
        catch {
            metadata.viewport = { x: 0, y: 0, width: 0, height: 0 };
        }
        const focused = nodes.find((n) => n.states?.includes('focused'));
        if (focused?.ref !== undefined)
            metadata.focusedRef = focused.ref;
        return metadata;
    }
    // --- actions -------------------------------------------------------------
    async performAction(session, request, execution) {
        const signal = execution.signal;
        switch (request.action) {
            case 'open_url':
                return await this.doOpenUrl(session, request, signal);
            case 'back':
                return await this.doHistory(session, signal, 'back');
            case 'forward':
                return await this.doHistory(session, signal, 'forward');
            case 'reload':
                return await this.doReload(session, signal);
            case 'new_tab':
                return await this.doNewTab(session, request, signal);
            case 'switch_tab':
                return await this.doSwitchTab(session, request, signal);
            case 'close_tab':
                return await this.doCloseTab(session, request, signal);
            case 'click':
                return await this.doClick(session, request, execution, 1);
            case 'double_click':
                return await this.doClick(session, request, execution, 2);
            case 'hover':
                return await this.doHover(session, request, execution);
            case 'type':
                return await this.doType(session, request, execution);
            case 'press':
                return await this.doPress(session, request, execution);
            case 'select':
                return await this.doSelect(session, request, execution);
            case 'scroll':
                return await this.doScroll(session, request, execution);
            case 'drag':
                return await this.doDrag(session, request, execution);
            case 'upload_files':
                return await this.doUpload(session, request, execution);
            case 'wait':
                return await this.doWait(session, request, signal);
            case 'launch_app':
            case 'focus':
                throw new ComputerUseError('UNSUPPORTED_ACTION', `action '${request.action}' is not supported by the browser surface`);
            default:
                throw new ComputerUseError('UNSUPPORTED_ACTION', `unknown action '${String(request.action)}'`);
        }
    }
    async doOpenUrl(session, request, signal) {
        const url = request.url;
        if (!url)
            throw new ComputerUseError('BAD_REQUEST', "action 'open_url' requires a url");
        const tab = await this.ensureActiveTab(session, signal);
        await this.navigate(tab.page, url, signal);
    }
    async navigate(page, url, signal) {
        throwIfAborted(signal);
        try {
            await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30_000 });
        }
        catch (error) {
            throwIfAborted(signal);
            throw new ComputerUseError('NAVIGATION_FAILED', `failed to navigate to '${url}': ${String(error)}`);
        }
    }
    async doHistory(session, signal, direction) {
        const tab = await this.ensureActiveTab(session, signal);
        throwIfAborted(signal);
        const options = { waitUntil: 'domcontentloaded', timeout: 30_000 };
        if (direction === 'back')
            await tab.page.goBack(options);
        else
            await tab.page.goForward(options);
    }
    async doReload(session, signal) {
        const tab = await this.ensureActiveTab(session, signal);
        throwIfAborted(signal);
        await tab.page.reload({ waitUntil: 'domcontentloaded', timeout: 30_000 });
    }
    async doNewTab(session, request, signal) {
        const context = session.context ?? (session.context = await this.createContext(session));
        throwIfAborted(signal);
        const page = await context.newPage();
        const tab = await this.registerTab(session, page);
        session.activeTabId = tab.tabId;
        await page.bringToFront().catch(() => { });
        if (request.url)
            await this.navigate(page, request.url, signal);
    }
    async doSwitchTab(session, request, signal) {
        const tabId = request.tabId;
        if (!tabId)
            throw new ComputerUseError('BAD_REQUEST', "action 'switch_tab' requires a tabId");
        const tab = session.tabs.get(tabId);
        if (!tab)
            throw new ComputerUseError('NOT_FOUND', `tab '${tabId}' not found`);
        session.activeTabId = tabId;
        throwIfAborted(signal);
        await tab.page.bringToFront().catch(() => { });
    }
    async doCloseTab(session, request, signal) {
        const tabId = request.tabId ?? session.activeTabId;
        if (!tabId)
            throw new ComputerUseError('BAD_REQUEST', 'no tab to close');
        const tab = session.tabs.get(tabId);
        if (!tab)
            throw new ComputerUseError('NOT_FOUND', `tab '${tabId}' not found`);
        throwIfAborted(signal);
        await tab.page.close({ runBeforeUnload: false }).catch(() => { });
        this.ensureActiveSelection(session);
    }
    assertCurrentSnapshot(session, request) {
        if (session.lastSnapshotId === null) {
            throw new ComputerUseError('STALE_SNAPSHOT', 'no snapshot available; observe before acting');
        }
        if (request.snapshotId !== session.lastSnapshotId) {
            throw new ComputerUseError('STALE_SNAPSHOT', 'snapshot is stale; observe again before acting');
        }
        if (session.snapshotSeq !== session.navigationSeq) {
            throw new ComputerUseError('STALE_SNAPSHOT', 'the page navigated since the snapshot; observe again');
        }
    }
    resolveRef(session, ref) {
        if (ref === undefined)
            throw new ComputerUseError('BAD_REQUEST', 'action requires a ref');
        const entry = session.refs.get(ref);
        if (!entry)
            throw new ComputerUseError('STALE_REF', `ref '${ref}' is unknown or stale`);
        const epoch = session.epoch.get(entry.tabId) ?? 0;
        if (entry.epoch !== epoch) {
            throw new ComputerUseError('STALE_REF', `ref '${ref}' is stale (the page navigated)`);
        }
        return entry;
    }
    tabFor(session, entry) {
        const tab = session.tabs.get(entry.tabId);
        if (!tab)
            throw new ComputerUseError('STALE_REF', 'the referenced tab was closed');
        return tab;
    }
    async resolvePoint(session, request, execution) {
        this.assertCurrentSnapshot(session, request);
        if (request.ref !== undefined) {
            const entry = this.resolveRef(session, request.ref);
            const tab = this.tabFor(session, entry);
            if (!entry.frame) {
                throw new ComputerUseError('ACTION_FAILED', `ref '${request.ref}' has no bounds to click`);
            }
            return {
                page: tab.page,
                x: entry.frame.x + entry.frame.width / 2,
                y: entry.frame.y + entry.frame.height / 2,
            };
        }
        if (request.x === undefined || request.y === undefined) {
            throw new ComputerUseError('BAD_REQUEST', `action '${request.action}' requires a ref or x/y coordinates`);
        }
        const tab = await this.ensureActiveTab(session, execution.signal);
        return { page: tab.page, x: request.x, y: request.y };
    }
    async doClick(session, request, execution, clickCount) {
        const { page, x, y } = await this.resolvePoint(session, request, execution);
        throwIfAborted(execution.signal);
        const viewport = await this.viewportSize(page);
        const cx = clamp(x, 0, viewport.width - 1);
        const cy = clamp(y, 0, viewport.height - 1);
        if (clickCount === 2)
            await page.mouse.dblclick(cx, cy);
        else
            await page.mouse.click(cx, cy);
    }
    async doHover(session, request, execution) {
        const { page, x, y } = await this.resolvePoint(session, request, execution);
        throwIfAborted(execution.signal);
        await page.mouse.move(x, y);
    }
    async doType(session, request, execution) {
        const text = request.text;
        if (text === undefined)
            throw new ComputerUseError('BAD_REQUEST', "action 'type' requires text");
        this.assertCurrentSnapshot(session, request);
        if (request.ref !== undefined) {
            const entry = this.resolveRef(session, request.ref);
            const tab = this.tabFor(session, entry);
            throwIfAborted(execution.signal);
            if (entry.backendNodeId >= 0) {
                await this.focusBackendNode(tab, entry);
                if (request.replace !== false)
                    await this.clearElement(tab, entry, execution.signal);
                await tab.cdp.send('Input.insertText', { text });
                return;
            }
            if (entry.frame === undefined)
                throw new ComputerUseError('ACTION_FAILED', `OCR ref '${request.ref}' has no bounds`);
            await tab.page.mouse.click(entry.frame.x + entry.frame.width / 2, entry.frame.y + entry.frame.height / 2);
            if (request.replace !== false)
                await tab.page.keyboard.press('Meta+A');
            await tab.page.keyboard.insertText(text);
            return;
        }
        const { page, x, y } = await this.resolvePoint(session, request, execution);
        await page.mouse.click(x, y);
        if (request.replace !== false)
            await page.keyboard.press('Meta+A');
        await page.keyboard.insertText(text);
    }
    async doPress(session, request, execution) {
        const key = request.key;
        if (!key)
            throw new ComputerUseError('BAD_REQUEST', "action 'press' requires a key");
        let page;
        if (request.ref !== undefined) {
            this.assertCurrentSnapshot(session, request);
            const entry = this.resolveRef(session, request.ref);
            const tab = this.tabFor(session, entry);
            await this.focusBackendNode(tab, entry);
            page = tab.page;
        }
        else {
            page = (await this.ensureActiveTab(session, execution.signal)).page;
        }
        throwIfAborted(execution.signal);
        await page.keyboard.press(key);
    }
    async doSelect(session, request, execution) {
        const option = request.option;
        if (option === undefined) {
            throw new ComputerUseError('BAD_REQUEST', "action 'select' requires an option");
        }
        this.assertCurrentSnapshot(session, request);
        const entry = this.resolveRef(session, request.ref);
        const tab = this.tabFor(session, entry);
        throwIfAborted(execution.signal);
        const { object } = (await tab.cdp.send('DOM.resolveNode', {
            backendNodeId: entry.backendNodeId,
        }));
        await tab.cdp.send('Runtime.callFunctionOn', {
            functionDeclaration: `function(value) {
        this.focus()
        this.value = value
        this.dispatchEvent(new Event('input', { bubbles: true }))
        this.dispatchEvent(new Event('change', { bubbles: true }))
        return this.value
      }`,
            objectId: object.objectId,
            arguments: [{ value: option }],
            returnByValue: true,
            awaitPromise: true,
        });
    }
    async doScroll(session, request, execution) {
        const direction = request.direction;
        const amount = request.amount ?? 200;
        let dx = 0;
        let dy = 0;
        switch (direction) {
            case 'up':
                dy = -amount;
                break;
            case 'down':
                dy = amount;
                break;
            case 'left':
                dx = -amount;
                break;
            case 'right':
                dx = amount;
                break;
            case undefined:
                dy = amount;
                break;
            default:
                throw new ComputerUseError('BAD_REQUEST', `invalid scroll direction '${direction}'`);
        }
        if (request.ref !== undefined) {
            this.assertCurrentSnapshot(session, request);
            const entry = this.resolveRef(session, request.ref);
            const tab = this.tabFor(session, entry);
            throwIfAborted(execution.signal);
            if (direction !== undefined) {
                const { object } = (await tab.cdp.send('DOM.resolveNode', {
                    backendNodeId: entry.backendNodeId,
                }));
                await tab.cdp
                    .send('Runtime.callFunctionOn', {
                    functionDeclaration: `function(dx, dy) {
              this.scrollBy({ left: dx, top: dy, behavior: 'auto' })
              return true
            }`,
                    objectId: object.objectId,
                    arguments: [{ value: dx }, { value: dy }],
                    returnByValue: true,
                })
                    .catch(() => { });
            }
            else {
                await tab.cdp.send('DOM.scrollIntoViewIfNeeded', { backendNodeId: entry.backendNodeId }).catch(() => { });
            }
            return;
        }
        const page = (await this.ensureActiveTab(session, execution.signal)).page;
        throwIfAborted(execution.signal);
        await page.evaluate((args) => window.scrollBy(args[0] ?? 0, args[1] ?? 0), [dx, dy]);
    }
    async doDrag(session, request, execution) {
        this.assertCurrentSnapshot(session, request);
        let page;
        let fromX;
        let fromY;
        let toX;
        let toY;
        if (request.ref !== undefined) {
            const entry = this.resolveRef(session, request.ref);
            const tab = this.tabFor(session, entry);
            if (!entry.frame)
                throw new ComputerUseError('ACTION_FAILED', `ref '${request.ref}' has no bounds`);
            page = tab.page;
            fromX = entry.frame.x + entry.frame.width / 2;
            fromY = entry.frame.y + entry.frame.height / 2;
        }
        else if (request.x !== undefined && request.y !== undefined) {
            const tab = await this.ensureActiveTab(session, execution.signal);
            page = tab.page;
            fromX = request.x;
            fromY = request.y;
        }
        if (request.toRef !== undefined) {
            const entry = this.resolveRef(session, request.toRef);
            const tab = this.tabFor(session, entry);
            if (!entry.frame)
                throw new ComputerUseError('ACTION_FAILED', `ref '${request.toRef}' has no bounds`);
            if (page === undefined)
                page = tab.page;
            toX = entry.frame.x + entry.frame.width / 2;
            toY = entry.frame.y + entry.frame.height / 2;
        }
        else if (request.toX !== undefined && request.toY !== undefined) {
            toX = request.toX;
            toY = request.toY;
        }
        if (!page || fromX === undefined || fromY === undefined) {
            throw new ComputerUseError('BAD_REQUEST', "action 'drag' requires a start ref or x/y");
        }
        if (toX === undefined || toY === undefined) {
            throw new ComputerUseError('BAD_REQUEST', "action 'drag' requires a toRef or toX/toY");
        }
        throwIfAborted(execution.signal);
        await page.mouse.move(fromX, fromY);
        await page.mouse.down();
        await page.mouse.move(toX, toY, { steps: 8 });
        await page.mouse.up();
    }
    async doUpload(session, request, execution) {
        const paths = request.paths;
        if (!paths || paths.length === 0) {
            throw new ComputerUseError('BAD_REQUEST', "action 'upload_files' requires paths");
        }
        this.assertCurrentSnapshot(session, request);
        const entry = this.resolveRef(session, request.ref);
        const tab = this.tabFor(session, entry);
        const resolved = resolveWorkspacePaths(paths, execution.workspaceRoot);
        throwIfAborted(execution.signal);
        await tab.cdp.send('DOM.setFileInputFiles', {
            files: resolved,
            backendNodeId: entry.backendNodeId,
        });
    }
    async doWait(session, request, signal) {
        const ms = request.durationMs ?? this.config.actionSettleMs;
        await this.ensureActiveTab(session, signal);
        await this.settle(signal, ms);
    }
    // --- small helpers -------------------------------------------------------
    async focusBackendNode(tab, entry) {
        if (entry.backendNodeId < 0)
            throw new ComputerUseError('UNSUPPORTED_TARGET', 'this OCR-only ref supports pointer actions and typing, but has no DOM element');
        await tab.cdp.send('DOM.scrollIntoViewIfNeeded', { backendNodeId: entry.backendNodeId }).catch(() => { });
        await tab.cdp.send('DOM.focus', { backendNodeId: entry.backendNodeId });
    }
    async clearElement(tab, entry, signal) {
        throwIfAborted(signal);
        const { object } = (await tab.cdp.send('DOM.resolveNode', {
            backendNodeId: entry.backendNodeId,
        }));
        await tab.cdp.send('Runtime.callFunctionOn', {
            functionDeclaration: `function() {
        this.focus()
        if (this.tagName === 'INPUT' || this.tagName === 'TEXTAREA') this.value = ''
        else this.textContent = ''
        this.dispatchEvent(new Event('input', { bubbles: true }))
        return true
      }`,
            objectId: object.objectId,
            returnByValue: true,
            awaitPromise: true,
        });
    }
    async settle(signal, ms = this.config.actionSettleMs) {
        if (ms <= 0)
            return;
        throwIfAborted(signal);
        await new Promise((resolve) => {
            const onAbort = () => resolve();
            signal.addEventListener('abort', onAbort, { once: true });
            setTimeout(() => {
                signal.removeEventListener('abort', onAbort);
                resolve();
            }, ms);
        });
        throwIfAborted(signal);
    }
    async viewportSize(page) {
        const vp = page.viewportSize();
        if (vp)
            return vp;
        try {
            return await page.evaluate(() => ({ width: window.innerWidth, height: window.innerHeight }));
        }
        catch {
            return DEFAULT_VIEWPORT;
        }
    }
}
//# sourceMappingURL=driver.js.map