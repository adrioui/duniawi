import type { ResolvedComputerUseConfig } from '../config.js';
import type { ActionRequest, ComputerExecution, ComputerSnapshot, ObserveRequest, Rect } from '../contracts.js';
export interface OcrText {
    text: string;
    frame: Rect;
    confidence?: number;
}
/**
 * Optional OCR dependency. Receives a PNG buffer (never inlined into a
 * snapshot) and returns recognized text blocks with viewport bounds.
 */
export type OcrFn = (png: Buffer, ctx: {
    sessionId: string;
    signal: AbortSignal;
}) => Promise<OcrText[]>;
export interface BrowserDriverDeps {
    ocr?: OcrFn;
}
export interface BrowserActionResult {
    status: string;
    snapshot: ComputerSnapshot;
}
/**
 * One Playwright Chromium process (system Chrome), isolated BrowserContext and
 * pages per execution.sessionId, per-session serialization, CDP accessibility
 * snapshots and browser actions. Designed to be owned as a host singleton.
 */
export declare class BrowserDriver {
    private readonly config;
    private browser;
    private readonly sessions;
    private readonly pageRegistrations;
    private readonly ocr;
    constructor(config: ResolvedComputerUseConfig, deps?: BrowserDriverDeps);
    /** Observe the current browser state as a text-only semantic snapshot. */
    observe(request: ObserveRequest, execution: ComputerExecution): Promise<ComputerSnapshot>;
    /** Perform a single browser action and return the resulting snapshot. */
    action(request: ActionRequest, execution: ComputerExecution): Promise<BrowserActionResult>;
    /** Close a session's context, persist its storage state, and forget it. */
    cleanupSession(sessionId: string): Promise<void>;
    /** Close every session and the shared browser process. */
    dispose(): Promise<void>;
    private getOrCreateSession;
    private ensureBrowser;
    private createContext;
    private loadStorageState;
    private registerTab;
    private registerTabInner;
    private ensureActiveTab;
    private ensureActiveSelection;
    private onNavigation;
    private teardownContext;
    private runGuarded;
    private captureSnapshot;
    private getFrameAxNodes;
    private frameOrigin;
    private assignRef;
    private assignCoordinateRef;
    private shouldOcr;
    private writeScreenshot;
    private buildMetadata;
    private performAction;
    private doOpenUrl;
    private navigate;
    private doHistory;
    private doReload;
    private doNewTab;
    private doSwitchTab;
    private doCloseTab;
    private assertCurrentSnapshot;
    private resolveRef;
    private tabFor;
    private resolvePoint;
    private doClick;
    private doHover;
    private doType;
    private doPress;
    private doSelect;
    private doScroll;
    private doDrag;
    private doUpload;
    private doWait;
    private focusBackendNode;
    private clearElement;
    private settle;
    private viewportSize;
}
//# sourceMappingURL=driver.d.ts.map