import type { Rect } from '../contracts.js';







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
    
    bounds: Map<number, Rect>;
    
    passwordNodes: Set<number>;
    
    clickableNodes: Set<number>;
}




export declare function decodeDocumentSnapshots(result: CaptureSnapshotResult): Map<string, FrameSnapData>;

export declare function axValueString(value: AxValue | undefined): string | undefined;
