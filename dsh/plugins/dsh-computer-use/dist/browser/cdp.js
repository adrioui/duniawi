function stringsAt(indices, strings) {
    if (!indices)
        return [];
    return indices.map((i) => strings[i] ?? '');
}
/**
 * Decode the compact `DOMSnapshot.captureSnapshot` output into per-frame
 * geometry and security metadata. Frames are keyed by their CDP frame id.
 */
export function decodeDocumentSnapshots(result) {
    const { documents, strings } = result;
    const out = new Map();
    for (const doc of documents) {
        const frameId = strings[doc.frameId] ?? `doc-${out.size}`;
        const nodes = doc.nodes;
        const layout = doc.layout;
        const backendNodeIds = nodes.backendNodeId ?? [];
        const bounds = new Map();
        for (let li = 0; li < layout.nodeIndex.length; li++) {
            const domIndex = layout.nodeIndex[li];
            if (domIndex === undefined)
                continue;
            const b = layout.bounds[li];
            if (!b || b.length < 4)
                continue;
            const backend = backendNodeIds[domIndex];
            if (backend === undefined)
                continue;
            if (!bounds.has(backend)) {
                bounds.set(backend, {
                    x: b[0] ?? 0,
                    y: b[1] ?? 0,
                    width: b[2] ?? 0,
                    height: b[3] ?? 0,
                });
            }
        }
        const nodeNames = stringsAt(nodes.nodeName, strings);
        const attributes = nodes.attributes ?? [];
        const passwordNodes = new Set();
        for (let di = 0; di < nodeNames.length; di++) {
            if (nodeNames[di]?.toUpperCase() !== 'INPUT')
                continue;
            const attrs = stringsAt(attributes[di], strings);
            let type = '';
            for (let a = 0; a + 1 < attrs.length; a += 2) {
                if (attrs[a] === 'type') {
                    type = attrs[a + 1] ?? '';
                    break;
                }
            }
            if (type.toLowerCase() === 'password') {
                const backend = backendNodeIds[di];
                if (backend !== undefined)
                    passwordNodes.add(backend);
            }
        }
        const clickableNodes = new Set();
        for (const index of nodes.isClickable?.index ?? []) {
            const backend = backendNodeIds[index];
            if (backend !== undefined)
                clickableNodes.add(backend);
        }
        out.set(frameId, {
            frameId,
            scrollX: doc.scrollOffsetX ?? 0,
            scrollY: doc.scrollOffsetY ?? 0,
            bounds,
            passwordNodes,
            clickableNodes,
        });
    }
    return out;
}
/** Extract the primitive value of an AX property, if it is a string/number. */
export function axValueString(value) {
    if (!value)
        return undefined;
    const v = value.value;
    if (typeof v === 'string')
        return v.length > 0 ? v : undefined;
    if (typeof v === 'number')
        return String(v);
    return undefined;
}
//# sourceMappingURL=cdp.js.map