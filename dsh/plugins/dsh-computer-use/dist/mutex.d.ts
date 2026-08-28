export declare class AbortableMutex {
    private locked;
    private readonly queue;
    acquire(signal?: AbortSignal): Promise<() => void>;
    run<T>(operation: () => Promise<T>, signal?: AbortSignal): Promise<T>;
    private releaseOnce;
}
//# sourceMappingURL=mutex.d.ts.map