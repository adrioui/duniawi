import type { ComputerSnapshot, ObservationDetail, ObservationResult, Rect, SemanticNode } from './contracts.js';
export declare function sanitizeNode(node: SemanticNode): SemanticNode;
export declare function selectObservationNodes(current: ComputerSnapshot, detail: ObservationDetail, query?: string, previous?: ComputerSnapshot): SemanticNode[];
export declare function formatRect(rect: Rect): string;
export declare function renderSnapshot(snapshot: ComputerSnapshot, detail: ObservationDetail, maxChars: number, query?: string, previous?: ComputerSnapshot): ObservationResult;
export declare function mergeOcrNodes(accessibility: SemanticNode[], ocr: SemanticNode[]): SemanticNode[];
//# sourceMappingURL=observation.d.ts.map