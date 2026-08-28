import z from '@deepseek-ai/schemastery';
export interface ComputerUseConfig {
    chromeExecutablePath?: string;
    headless?: boolean;
    stateDir?: string;
    helperAppPath?: string;
    helperSocketPath?: string;
    maxObservationChars?: number;
    maxNodes?: number;
    actionSettleMs?: number;
}
export interface ResolvedComputerUseConfig {
    chromeExecutablePath: string;
    headless: boolean;
    stateDir: string;
    helperAppPath?: string;
    helperSocketPath: string;
    maxObservationChars: number;
    maxNodes: number;
    actionSettleMs: number;
}
export declare const Config: z<ComputerUseConfig>;
export declare function resolveConfig(config?: ComputerUseConfig): ResolvedComputerUseConfig;
//# sourceMappingURL=config.d.ts.map