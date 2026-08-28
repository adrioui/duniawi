# Installed by dsh-routing-suite (suite HEAD a09eb0a, 2026-08-16)

The suite is **agent-preset-based** on this machine:

- `~/.dsh/.agent-presets/router-standard` and `router-spec` are mounted from the
  suite's `preset/` submodule (v0.2.0, exact upstream files).
- `mode-boost` is mounted as a host-plane plugin in the **tui profile only**:
  dependency `@dsh-external/dsh-mode-boost` ->
  `link:~/.dsh/plugins/dsh-mode-boost`, plus the `mode-boost` row in
  `~/.dsh/profiles/tui/cordis.patch.yml`. It no-ops when a router preset is
  active (by design), and takes over on ordinary Standard sessions.
- `dsh-super-injector` is **not installed** on this machine: it is web-profile
  only (requires the `webServer` service), and `dsh --profile tui` is the
  active profile here.

Installer artifacts kept in `~/.dsh/plugins/`:
- `dsh-super-injector/` — built release v0.3.3 (downloaded from GitHub releases)
- `dsh-mode-boost/` — suite submodule package
