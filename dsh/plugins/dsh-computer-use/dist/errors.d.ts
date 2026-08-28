export declare class ComputerUseError extends Error {
    readonly code: string;
    constructor(code: string, message: string, options?: ErrorOptions);
}
export declare function abortError(): ComputerUseError;
export declare function throwIfAborted(signal: AbortSignal): void;
//# sourceMappingURL=errors.d.ts.map