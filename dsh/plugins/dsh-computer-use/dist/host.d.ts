import type { Context } from '@deepseek-ai/cordis';
import type { ActionRequest, ActionResult, ComputerExecution, NativeStatus, ObserveRequest, ObservationResult } from './contracts.js';
import { Config, type ComputerUseConfig } from './config.js';
import { ComputerUseService } from './service.js';
export declare const name = "computer-use-host";
export declare const inject: string[];
export { Config };
export default class ComputerUseRuntime extends ComputerUseService {
    static Config: import("@deepseek-ai/schemastery").default<ComputerUseConfig>;
    static inject: string[];
    private readonly config;
    private readonly browser;
    private readonly native;
    private readonly nativeClient;
    private readonly previous;
    private disposed;
    constructor(ctx: Context, config?: ComputerUseConfig);
    observe(request: ObserveRequest, execution: ComputerExecution): Promise<ObservationResult>;
    action(request: ActionRequest, execution: ComputerExecution): Promise<ActionResult>;
    nativeStatus(signal?: AbortSignal): Promise<NativeStatus>;
    private cleanupSession;
    private disposeRuntime;
    private assertLive;
}
//# sourceMappingURL=host.d.ts.map