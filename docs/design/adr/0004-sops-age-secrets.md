# ADR-0004: sops-nix with per-host age keys

- Status: Proposed — requires secret rotation before cutover
- Date: 2026-10-31
- Deciders: repository owner
- Related: `docs/design/secrets.md`, Approval 3/4/5

## Context

The old home contains an exposed SOPS age private key at
`.config/sops/age/keys.txt`, an inline GPG passphrase in
`gpg-preset-passphrase.service`, and many plaintext provider credentials. The
backup HDD is unencrypted. Reusing the old age key or copying plaintext env
files would preserve the compromise.

The NixOS proxy needs two runtime secrets: a DeepSeek upstream key and an
inbound key. The repository must remain free of plaintext secrets.

## Decision

Use `sops-nix` with age:

- One age key pair per host (`adri`, `t14`); no shared private key.
- The old age key is never reused. A new `t14` key is generated on the target
  and kept outside the repository, mode 0600.
- Encrypted files in the repository contain ciphertext only; `.sops.yaml`
  contains public recipients only.
- NixOS/home-manager reads secrets at runtime through `sops.secrets` and a
  generated environment file or wrapper. Secrets never enter the Nix store,
  unit files, shell history, or logs.
- The proxy secrets are `amp-deepseek/upstream-key` and
  `amp-deepseek/inbound-key`.
- `sops-nix` is a new pinned flake input. The intentional lock deltas are the
  pinned `sops-nix`, `nixos-hardware`, `nixpkgs-stable`, and
  `home-manager-stable` inputs; no existing input revision changed.

## Consequences

- The repository can be public without exposing secrets.
- The host cannot decrypt secrets without its age private key; key custody is
  an operational responsibility.
- VM tests use a test age key and test ciphertext, never production secrets.
- Rotating a secret requires re-encrypting the sops file and reactivating the
  service; the old value is revoked at the provider.
- If the age key is compromised, all secrets encrypted to it must be rotated.
- The old plaintext env files and unit files are excluded from restore.

## Alternatives considered

| Alternative | Why rejected |
|---|---|
| Reuse the old age key | already exposed on an unencrypted backup |
| PGP-encrypted SOPS | old GPG key/passphrase is compromised; more moving parts |
| `agenix` | viable, but sops-nix is the requested/recommended backend |
| Plaintext `EnvironmentFile` | violates the no-secret rule |
| `builtins.readFile` in Nix | secret would land in the world-readable store |
| systemd credentials only | still needs an encrypted source and rotation story |

## Verification

- `sops -d secrets/t14.yaml` works only with the new key.
- `stat -c '%a %U:%G'` on runtime secret files → `0400`/`0600`,
  `adrioui:adrioui`.
- `nix store` grep for test markers → no hit.
- `curl http://127.0.0.1:4014/health` → 200; missing secret → 503.
- `journalctl --user -u amp-deepseek-proxy` → no key material.
