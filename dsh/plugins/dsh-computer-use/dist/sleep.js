import { abortError, throwIfAborted } from './errors.js';
export async function abortableSleep(delayMs, signal) {
    throwIfAborted(signal);
    if (delayMs <= 0)
        return;
    await new Promise((resolve, reject) => {
        const timer = setTimeout(done, delayMs);
        function done() {
            signal.removeEventListener('abort', cancel);
            resolve();
        }
        function cancel() {
            clearTimeout(timer);
            reject(abortError());
        }
        signal.addEventListener('abort', cancel, { once: true });
    });
}
//# sourceMappingURL=sleep.js.map