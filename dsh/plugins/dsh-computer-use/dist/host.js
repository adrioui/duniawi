import { validateActionRequest } from './actions.js';
import { BrowserDriver } from './browser/index.js';
import { Config, resolveConfig } from './config.js';
import { NativeClient, NativeDesktopDriver } from './native/index.js';
import { renderSnapshot } from './observation.js';
import { ComputerUseService } from './service.js';
export const name = 'computer-use-host';
export const inject = ['subprocess'];
export { Config };
export default class ComputerUseRuntime extends ComputerUseService {
    static Config = Config;
    static inject = ['subprocess'];
    config;
    browser;
    native;
    nativeClient;
    previous = new Map();
    disposed = false;
    constructor(ctx, config = {}) {
        super(ctx);
        this.config = resolveConfig(config);
        this.nativeClient = new NativeClient(ctx.subprocess, {
            socketPath: this.config.helperSocketPath,
            stateDir: this.config.stateDir,
            ...(this.config.helperAppPath === undefined ? {} : { appPath: this.config.helperAppPath }),
        });
        this.native = new NativeDesktopDriver(this.nativeClient, this.config);
        this.browser = new BrowserDriver(this.config, {
            ocr: async (png, execution) => await this.native.ocrBuffer(png, execution),
        });
        ctx.on('agent/disposed', ({ agent }) => this.cleanupSession(agent.id));
        ctx.effect(() => () => this.disposeRuntime(), 'computer-use host teardown');
    }
    async observe(request, execution) {
        this.assertLive();
        const key = snapshotKey(execution.sessionId, request.surface);
        const previous = this.previous.get(key);
        const snapshot = request.surface === 'browser'
            ? await this.browser.observe(request, execution)
            : await this.native.observe(request, execution);
        this.previous.set(key, snapshot);
        return renderSnapshot(snapshot, request.detail ?? 'interactive', this.config.maxObservationChars, request.query, previous);
    }
    async action(request, execution) {
        this.assertLive();
        validateActionRequest(request);
        const key = snapshotKey(execution.sessionId, request.surface);
        const previous = this.previous.get(key);
        const result = request.surface === 'browser'
            ? await this.browser.action(request, execution)
            : await this.native.action(request, execution);
        this.previous.set(key, result.snapshot);
        const observation = renderSnapshot(result.snapshot, 'changes', this.config.maxObservationChars, undefined, previous);
        return {
            ...observation,
            action: request.action,
            status: result.status,
        };
    }
    async nativeStatus(signal) {
        this.assertLive();
        return await this.nativeClient.status(signal);
    }
    async cleanupSession(sessionId) {
        this.native.clearSession(sessionId);
        this.previous.delete(snapshotKey(sessionId, 'browser'));
        this.previous.delete(snapshotKey(sessionId, 'desktop'));
        await this.browser.cleanupSession(sessionId);
    }
    async disposeRuntime() {
        if (this.disposed)
            return;
        this.disposed = true;
        this.previous.clear();
        await Promise.allSettled([this.browser.dispose(), this.native.dispose()]);
    }
    assertLive() {
        if (this.disposed)
            throw new Error('computer-use host service is disposed');
    }
}
function snapshotKey(sessionId, surface) {
    return `${sessionId}:${surface}`;
}
//# sourceMappingURL=host.js.map