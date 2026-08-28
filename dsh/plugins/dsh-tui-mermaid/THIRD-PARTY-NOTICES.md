# Third-party notices

This plugin is a port of **pi-mermaid** (https://github.com/Gurpartap/pi-mermaid),
Copyright Gurpartap Singh, licensed under the **MIT License**. The mermaid
fence extraction, size limits, multi-preset width-aware ASCII rendering, LRU
caching, and issue-reporting approach derive from upstream `index.ts`,
adapted to the DeepSeek Harness plugin seams (`session/event`,
`session.append`, `ctx.tuiRenderers`) instead of pi's extension API.

Diagram rendering uses **beautiful-mermaid**
(https://github.com/lukilabs/beautiful-mermaid), MIT License — the same
rendering library as upstream.
