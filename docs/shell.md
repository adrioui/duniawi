# Shell

## Status

Zsh is the interactive shell, Starship is the prompt, and API keys are loaded from Keychain at shell start.

## Configuration

`modules/shell.nix`:

```nix
programs.zsh.enable = true;
environment.systemPackages = [ pkgs.alacritty pkgs.kitty ];

programs.starship = {
  enable = true;
  enableZshIntegration = true;
  presets = [ "nerd-font-symbols" ];
};

home.sessionVariables = {
  MAGNITUDE_USE_LOCAL = "1";
  MAGNITUDE_ENDPOINT = "http://100.87.7.118:8317/api/v1";
};

home.sessionPath = [ "$HOME/.npm-global/bin" ];
```

Zsh uses the home directory as `dotDir`, so the managed files are the user's normal `.zshrc` and related files.

## Keychain exports

`initContent` reads secrets from the login Keychain:

```zsh
export HCNOTE_API_KEY="$(/usr/bin/security find-generic-password -ws hcnote 2>/dev/null || true)"
export COMMANDCODE_API_KEY="$(/usr/bin/security find-generic-password -s commandcode-api-key -w 2>/dev/null || true)"
export OPENCODE_API_KEY="$(/usr/bin/security find-generic-password -s opencode-api-key -w 2>/dev/null || true)"
export OPENCODE_GO_API_KEY="$OPENCODE_API_KEY"
```

These are runtime reads. Nothing is written to Nix, a plist, or a log.

## Terminals

| Terminal | Source |
|---|---|
| Alacritty | `pkgs.alacritty` |
| Kitty | `pkgs.kitty` |
| Ghostty | Homebrew cask |
| Warp | Homebrew cask |

## Verification

```bash
zsh -lic 'echo $MAGNITUDE_ENDPOINT'
zsh -lic 'test -n "$OPENCODE_API_KEY" && echo set || echo missing'
starship --version
```

## Security

* Keychain lookups fail open with `|| true`; the shell starts even when a key is missing.
* Secrets are process environment only.
* Do not add literal keys to `initContent`.
* Do not add shell aliases for rebuild commands; use `darwin-rebuild build --flake path:$PWD#adri` explicitly.

## Troubleshooting

| Symptom | Check |
|---|---|
| prompt is plain | `programs.starship.enable` and `enableZshIntegration` |
| Keychain variable empty | service name and login keychain |
| npm binaries missing | `home.sessionPath` includes `$HOME/.npm-global/bin` |
| Zsh config not loaded | `dotDir` must be the home directory |
| terminal missing | package or cask is not declared |
