





















import { Context } from 'cordis';
import type Loader from '@deepseek-ai/cordis-plugin-loader';
import type SystemPrompt from '@deepseek-ai/dsh-system-prompt';
import type ToolRegistry from '@deepseek-ai/dsh-tools';
type AppContext = Context & {
    loader: Loader;
    tools: ToolRegistry;
    systemPrompt: SystemPrompt;
    webServer: any;
    registry: any;
    setInterval(fn: () => void, ms: number): any;
};
export declare const name = "dsh-super-injector";
export declare const inject: string[];
export interface Config {
    
    registryFile: string;
    
    profileNodeModules: string;
    
    autoRestore: boolean;
    
    intervalMs: number;
    
    watches: Array<{
        dir: string;
        match: string;
    }>;
}
export declare const Config: Config;
export declare function apply(ctx: AppContext, config: Config): void;
export {};
