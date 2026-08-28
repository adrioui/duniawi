# dsh-tui-mermaid

Render ```mermaid code fences in assistant messages as width-aware ASCII art,
inline in the DeepSeek Harness terminal TUI.

Port of [pi-mermaid](https://github.com/Gurpartap/pi-mermaid) (MIT, Gurpartap
Singh); rendering by [beautiful-mermaid](https://github.com/lukilabs/beautiful-mermaid).
See THIRD-PARTY-NOTICES.md.

## How it works

- On each completed assistant message, extracts up to 5 mermaid fences.
- Renders each block under four padding presets (default/compact/tight/squeezed)
  so the transcript can pick the widest one that fits the terminal width.
- Appends a log-only `mermaid/diagram` session event (survives resume/replay;
  the type is registered into every reachable dsh-session copy at load).
- Projects the event through `ctx.tuiRenderers` into title + text rows.

## Install (already wired for the tui profile)

```sh
# dependency link in ~/.dsh/profiles/tui/package.json:
#   "@dsh-local/dsh-tui-mermaid": "link:/Users/adrifadilah/.dsh/plugins/dsh-tui-mermaid"
# plus an insert row (id: dsh-tui-mermaid) in cordis.patch.yml
```

## Configuration

In the profile's `cordis.patch.yml`, target the row by id:

```yaml
- id: dsh-tui-mermaid
  config:
    enabled: false   # disable publishing/rendering without uninstalling
```

## Caveats

- Sessions containing `mermaid/diagram` events are unreadable by dsh readers
  that do not load this plugin (the web profile's strict log reader refuses
  unknown non-ignorable types). Install this plugin into any other profile
  that reads the same session logs.
- Diagram types unsupported by beautiful-mermaid surface a
  `[mermaid:error]` issue row instead of a diagram; nothing ever crashes the
  transcript (the seam isolates renderer failures per type).
