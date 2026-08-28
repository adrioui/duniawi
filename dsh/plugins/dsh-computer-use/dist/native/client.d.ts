import type { SubprocessRuntime } from '@deepseek-ai/dsh-subprocess';
import type { NativeObservation, NativeStatus, Rect } from '../contracts.js';
export interface NativeClientOptions {
    appPath?: string;
    socketPath: string;
    stateDir: string;
}
export declare class NativeClient {
    private readonly subprocess;
    private readonly options;
    private socket;
    private buffer;
    private counter;
    private readonly pending;
    private connecting;
    private handshake;
    private disposed;
    constructor(subprocess: SubprocessRuntime, options: NativeClientOptions);
    status(signal?: AbortSignal): Promise<NativeStatus>;
    observeDesktop(params: Record<string, unknown>, signal: AbortSignal): Promise<NativeObservation>;
    performDesktop(params: Record<string, unknown>, signal: AbortSignal): Promise<{
        status: string;
    }>;
    ocrFile(filePath: string, signal: AbortSignal): Promise<Array<{
        text: string;
        confidence: number;
        frame: Rect;
    }>>;
    dispose(): Promise<void>;
    private request;
    private ensureConnected;
    private connect;
    private launchHelper;
    private openSocket;
    private attachSocket;
    private verifyHandshake;
    private requireHandshake;
    private requestOnConnected;
    private write;
    private sendCancelOutOfBand;
    private onData;
    private clearPending;
    private rejectAll;
}
//# sourceMappingURL=client.d.ts.map