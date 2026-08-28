import type { Rect } from '../contracts.js';
/**
 * Minimal structural mirrors of the Chrome DevTools Protocol shapes consumed by
 * the browser driver. We deliberately avoid importing playwright-core's
 * internal `Protocol` namespace (it is not re-exported), so these types only
 * describe the fields we actually read. The real CDP responses are cast to
 * them at the call site.
 */
export interface AxValue {
    type?: string;
    value?: unknown;
    relatedNodes?: AxRelatedNode[];
}
export interface AxRelatedNode {
    backendDOMNodeId?: number;
    idref?: string;
    text?: string;
}
export interface AxProperty {
    name?: string;
    value?: AxValue;
}
export interface AxNode {
    nodeId?: string;
    ignored?: boolean;
    ignoredReasons?: AxProperty[];
    role?: AxValue;
    chromeRole?: AxValue;
    name?: AxValue;
    description?: AxValue;
    value?: AxValue;
    properties?: AxProperty[];
    parentId?: string;
    childIds?: string[];
    backendDOMNodeId?: number;
    frameId?: string;
}
export interface FrameTreeNode {
    frame: {
        id: string;
        url: string;
        name?: string;
    };
    childFrames?: FrameTreeNode[];
}
export interface RareStringData {
    index: number[];
    value: number[];
}
export interface RareBooleanData {
    index: number[];
}
export interface NodeTreeSnapshot {
    nodeName?: number[];
    backendNodeId?: number[];
    attributes?: number[][];
    isClickable?: RareBooleanData;
}
export interface LayoutTreeSnapshot {
    nodeIndex: number[];
    bounds: number[][];
}
export interface DocumentSnapshot {
    frameId: number;
    nodes: NodeTreeSnapshot;
    layout: LayoutTreeSnapshot;
    scrollOffsetX?: number;
    scrollOffsetY?: number;
}
export interface CaptureSnapshotResult {
    documents: DocumentSnapshot[];
    strings: string[];
}
export interface FrameSnapData {
    frameId: string;
    scrollX: number;
    scrollY: number;
    /** backendNodeId -> document-space bounds (scroll offset NOT applied). */
    bounds: Map<number, Rect>;
    /** backendNodeIds that belong to `<input type="password">`. */
    passwordNodes: Set<number>;
    /** backendNodeIds that respond to mouse clicks (DOMSnapshot isClickable). */
    clickableNodes: Set<number>;
}
/**
 * Decode the compact `DOMSnapshot.captureSnapshot` output into per-frame
 * geometry and security metadata. Frames are keyed by their CDP frame id.
 */
export declare function decodeDocumentSnapshots(result: CaptureSnapshotResult): Map<string, FrameSnapData>;
/** Extract the primitive value of an AX property, if it is a string/number. */
export declare function axValueString(value: AxValue | undefined): string | undefined;
//# sourceMappingURL=cdp.d.ts.map