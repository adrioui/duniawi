import type { ActionRequest, ComputerExecution, ComputerSnapshot, ObserveRequest, Rect } from '../contracts.js';
import type { ResolvedComputerUseConfig } from '../config.js';
import { NativeClient } from './client.js';
export declare class NativeDesktopDriver {
    private readonly client;
    private readonly config;
    private readonly ids;
    private readonly inputMutex;
    private readonly latest;
    constructor(client: NativeClient, config: ResolvedComputerUseConfig);
    observe(request: ObserveRequest, execution: ComputerExecution): Promise<ComputerSnapshot>;
    action(request: ActionRequest, execution: ComputerExecution): Promise<{
        status: string;
        snapshot: ComputerSnapshot;
    }>;
    ocrBuffer(png: Buffer, execution: {
        sessionId: string;
        signal: AbortSignal;
    }): Promise<Array<{
        text: string;
        frame: Rect;
        confidence: number;
    }>>;
    clearSession(sessionId: string): void;
    dispose(): Promise<void>;
    private observeUnlocked;
    private performAction;
    private performType;
    private targetFor;
}
//# sourceMappingURL=driver.d.ts.map