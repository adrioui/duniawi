export class MonotonicIds {
    prefix;
    counter = 0;
    constructor(prefix) {
        this.prefix = prefix;
    }
    next() {
        this.counter += 1;
        return `${this.prefix}${this.counter.toString(36)}`;
    }
}
//# sourceMappingURL=ids.js.map