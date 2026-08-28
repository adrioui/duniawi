import type { SemanticNode, Rect } from '../contracts.js';
import { type AxNode } from './cdp.js';
export interface BuildSemanticNodesOptions {
    




    viewportOffset?: {
        x: number;
        y: number;
    };
    depthBase?: number;
    bounds: Map<number, Rect>;
    passwordNodes: Set<number>;
    clickableNodes: Set<number>;
    




    assignRef?: (backendNodeId: number, frame: Rect | undefined) => string | undefined;
}





export declare function buildSemanticNodes(axNodes: AxNode[], opts: BuildSemanticNodesOptions): SemanticNode[];
