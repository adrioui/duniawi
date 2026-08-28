export class ComputerUseError extends Error {
    code;
    constructor(code, message, options) {
        super(message, options);
        this.name = 'ComputerUseError';
        this.code = code;
    }
}
export function abortError() {
    return new ComputerUseError('ABORTED', 'computer use operation was cancelled');
}
export function throwIfAborted(signal) {
    if (signal.aborted)
        throw abortError();
}
//# sourceMappingURL=errors.js.map