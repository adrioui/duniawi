import type { SemanticNode, Rect } from '../contracts.js';
import { type AxNode } from './cdp.js';
export interface BuildSemanticNodesOptions {
    /**
     * Viewport offset for this frame: main-frame viewport coordinates of the
     * frame's (0, 0) minus the frame's own scroll offset. Bounds from
     * DOMSnapshot are document-space, so `nodeFrame = offset + docBounds`.
     */
    viewportOffset?: {
        x: number;
        y: number;
    };
    depthBase?: number;
    bounds: Map<number, Rect>;
    passwordNodes: Set<number>;
    clickableNodes: Set<number>;
    /**
     * Called for each node that has a backend node id so the driver can mint a
     * stable ref. Receives the final (main-frame viewport) bounds so the driver
     * can record them for later coordinate resolution.
     */
    assignRef?: (backendNodeId: number, frame: Rect | undefined) => string | undefined;
}
/**
 * Flatten an AX tree into text-only semantic nodes. Ignored nodes are skipped
 * but their unignored descendants are promoted to the nearest visible
 * ancestor's level, so `depth` counts only meaningful levels.
 */
export declare function buildSemanticNodes(axNodes: AxNode[], opts: BuildSemanticNodesOptions): SemanticNode[];
//# sourceMappingURL=a11y.d.ts.map