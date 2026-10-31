# Secrets inventory, threat model, and rotation runbook

Status: **Gate 1 draft — no implementation writes yet**

This document contains **references only**. It never contains a secret value,
passphrase, token, private key, or credential. Any value found in the backup,
a unit file, a log, or shell history is treated as compromised.

## 1. Assets

| Asset class | Examples | Why it matters |
|---|---|---|
| Identity keys | SSH private key, GPG private keys, age private key | impersonation, signing, decryption |
| Cloud credentials | AWS access key, GitHub token, Docker registry auth, Kubernetes config | account takeover, data access, supply chain |
| AI provider credentials | DeepSeek, Command Code, Qoder, OpenRouter, LiteLLM, Bifrost, Cloudflare tunnel | billing abuse, data exfiltration, service takeover |
| Desktop secrets | GNOME keyring, browser profiles, application tokens | local account and session compromise |
| New runtime secrets | `amp-deepseek` upstream key and inbound key | unauthorized proxy use, upstream billing |
| Host keys | new per-host age key, SSH host key | decryption, host impersonation |

## 2. Trust boundaries

| Boundary | Untrusted until | Validation |
|---|---|---|
| External backup HDD | mounted read-only, label/UUID/SMART verified | `findmnt`, `blkid`, SMART evidence; never write |
| Old Fedora home | treated as compromised | plaintext secrets found; no blind restore |
| Repository | reviewed | no secret values; secret scanning in CI |
| Nix store | world-readable | no secrets in derivations or store paths |
| CI logs | redacted | no secret echo; masked variables |
| Runtime | least privilege | sops files mode 0400/0600; systemd credentials |
| Age private key | offline/limited | separate from repo and backup; mode 0600 |

## 3. Known exposed secrets

The old home is on an **unencrypted** external HDD. Every secret in it must be
considered exposed to anyone with physical access to the drive, and to any
process that could read the old home before migration.

| ID | Old location (reference only) | Type | Exposure | Required action | Reuse? |
|---|---|---|---|---|---|
| `SEC-SUDO-CHAT` | chat session, 2026-10-31 | sudo account password | **pasted into chat; treat the session log as compromised** | change from a local console now; never reuse; no sudo was run with it | **No** |
| `SEC-GPG-PASS` | `gpg-preset-passphrase.service` | inline GPG passphrase | **plaintext in a unit file; copied into the backup manifest** | rotate the GPG passphrase and the affected key; never restore the unit | **No** |
| `SEC-GPG-KEY` | `.gnupg/private-keys-v1.d/*.key` (two keys) | GPG private keys | private key material on unencrypted backup | revoke/rotate; generate a new key on NixOS; import only if a specific key is still required | **No** |
| `SEC-SSH-ED25519` | `.ssh/id_ed25519` | SSH private key | private key on unencrypted backup | generate a new key; remove old public key from servers | **No** |
| `SEC-SOPS-AGE` | `.config/sops/age/keys.txt` | age private key | private key on unencrypted backup | **do not reuse**; generate a new per-host key | **No** |
| `SEC-AWS` | `.aws/credentials` | AWS access key | plaintext on backup | revoke at AWS; issue a new key only if needed | **No** |
| `SEC-GH` | `.config/gh/hosts.yml` | GitHub OAuth token | plaintext on backup | revoke session/token; re-authenticate with `gh auth login` | **No** |
| `SEC-DOCKER` | `.docker/config.json`, `.docker/.token_seed` | registry auth / seed | plaintext on backup | revoke/re-authenticate; do not copy | **No** |
| `SEC-KUBE` | `.kube/config` | cluster credentials | plaintext on backup | rotate cluster credentials; do not copy | **No** |
| `SEC-KEYRING` | `.local/share/keyrings/*` | desktop keyring | encrypted with login password, but backup is offline-readable | re-create keyring on NixOS; do not copy | **No** |
| `SEC-LITELLM` | `.config/cline-litellm/*`, `.config/litellm/*`, `cline-litellm.service` | LiteLLM master key and provider keys | inline and env files on backup | revoke/rotate; old stack archived | **No** |
| `SEC-QODER` | `commandcode-proxy.service` | inline `QODER_API_KEY` | **plaintext in a unit file** | revoke/rotate; old proxy archived | **No** |
| `SEC-BIFROST` | `bifrost-amp.service`, `.config/litellm/bifrost.env` | Bifrost setup token / virtual key | inline/env on backup | revoke/rotate; old stack archived | **No** |
| `SEC-TUNNEL` | `amp-litellm-named-tunnel.service`, `.config/litellm/cf-tunnel-token` | Cloudflare tunnel token | token file on backup | revoke/recreate tunnel; not ported | **No** |
| `SEC-AI-PROVIDER` | `.config/opencode/commandcode.key`, `.config/amp/*`, `.config/claude-litellm/*.key`, `.config/qodercli2api/env`, `.config/collie/.env`, `.config/cline-shim/*.env`, `.config/commandcode-proxy/proxy.log` | provider API keys and logs | plaintext on backup; logs may contain headers | revoke/rotate all; do not restore logs or env files | **No** |
| `SEC-NIX-MANAGED` | `.config/nix-managed/secrets/infra.yaml` (symlink) | infrastructure secrets | dangling/unknown target; treat as exposed | inspect only as root; rotate if resolvable; do not restore | **No** |
| `SEC-AMP-DEEPSEEK-UPSTREAM` | new sops key | DeepSeek API key for the proxy | new; not from backup | create/issue new; store in sops | **New only** |
| `SEC-AMP-DEEPSEEK-INBOUND` | new sops key | inbound proxy key | new; not from backup | generate random; store in sops | **New only** |
| `SEC-HOST-AGE` | new host key | age private key for sops | new; not from backup | generate per host; keep offline/0600 | **New only** |

The old `gpg-preset-passphrase.service` is a **SecretLeak** finding. It must
not be restored, quoted, or copied. The old age key is also a **SecretLeak**
finding because it sits next to the encrypted data it can decrypt.

## 4. Threat model

| Threat | Vector | Impact | Mitigation |
|---|---|---|---|
| Backup theft | unencrypted HDD, no passphrase | full credential compromise | rotate everything; encrypt future backups; restrict physical access |
| Accidental commit | secret copied into repo or docs | public leak | secret scanning; review; `.gitignore`; no plaintext |
| Nix store leak | secret embedded in derivation or `builtins.readFile` | world-readable leak | sops at runtime; no secret in store |
| Shell history | `export KEY=...`, command-line args | local leak | `read -s`, systemd credentials, no secret args |
| Unit file leak | inline `Environment=`/`--passphrase` | local/backup leak | sops `EnvironmentFile` or `LoadCredential`; no inline secrets |
| Log leak | proxy logs headers/bodies | provider key leak | log metadata only; redaction; journald access control |
| CI leak | echo/masked variables | public leak | masked secrets; no debug echo; least-privilege tokens |
| Key reuse | same age/SSH/GPG key on both hosts | one compromise affects both | per-host keys; separate recipients |
| Tunnel exposure | public Cloudflare tunnel to local proxy | unauthorized use | no tunnel by default; inbound key; loopback bind |
| Privilege escalation | old units run as user with broad access | data loss | least privilege; no root services; review capabilities |
| Rollback leak | old home retained with secrets | continued exposure | purge/exclude secrets; rotate before cutover |

### Non-goals

- This design does not make the old backup encrypted. It only stops copying
  secrets from it.
- This design does not rotate third-party credentials automatically. Rotation
  is an operator action with provider-specific steps.
- This design does not protect against a compromised Nix daemon or root on the
  target host. Root can read runtime secrets by design.

## 5. Secret storage design

- Backend: `sops-nix` with age, pinned as a flake input at Gate 2.
- Recipients: one age public key per host (`adri`, `t14`); no shared private
  key.
- Encrypted files live in the repo (for example `secrets/t14.yaml`) and contain
  only ciphertext. `.sops.yaml` contains public recipients only.
- Private age keys live outside the repo, mode 0600, never in the Nix store,
  never on the external backup.
- NixOS/HM services read secrets at runtime:
  - `sops.secrets."amp-deepseek/upstream-key"` and
    `sops.secrets."amp-deepseek/inbound-key"`;
  - a generated env file or wrapper injects them into the proxy process;
  - the proxy unit binds `127.0.0.1:4014`;
  - no secret appears in `ps`, unit files, or logs.
- File modes: directories `0700`, files `0400`/`0600`; owner `adrioui:adrioui`
  (uid/gid 1000).
- The proxy logs only status, byte counts, and duration. It must never log
  request headers, authorization values, bodies, or upstream keys.

### 5.1 Provisioning state

No production encrypted file is committed yet. `ampDeepseekNixos.sopsFile`
defaults to `null`; the service then starts without credentials and
`/health` returns 503. This is deliberate: committing a dummy or undecryptable
secret file would create a false impression that the proxy is provisioned.

Provisioning steps:

1. Generate a new age key on `t14` at a new path, for example
   `/home/adrioui/.config/sops/age/t14.txt`, mode 0600. Do not reuse the old
   `keys.txt`.
2. Put only its public key in `.sops.yaml`.
3. Encrypt `secrets/t14.yaml` with the two keys
   `amp-deepseek/upstream-key` and `amp-deepseek/inbound-key`.
4. Set `ampDeepseekNixos.sopsFile = ../secrets/t14.yaml` (or an absolute
   path outside the store) in the host-qualified configuration.
5. Rebuild, restart the user service, and verify `/health` 200, wrong key 401,
   missing secret 503, and no key in the journal.
6. Record the age recipient, rotation date, and revocation evidence in this
   file without recording the private key.

The VM test injects test keys directly into the service environment; it does
not decrypt production sops data.

## 6. Rotation runbook

This runbook is ordered by risk. It is executed **before** the migration
cutover and before any live `nixos-rebuild switch`.

### Phase 0 — freeze and contain

1. Do not start any old proxy, tunnel, or credential-broker unit.
2. Keep the backup mounted read-only.
3. Do not restore `.ssh`, `.gnupg`, `.aws`, `.kube`, `.docker`,
   `.local/share/keyrings`, `.config/sops`, `.config/litellm`,
   `.config/cline-shim`, `.config/opencode/commandcode.key`,
   `.config/qodercli2api`, `.config/collie`, or old unit files.
4. Record the incident IDs `SEC-GPG-PASS`, `SEC-SOPS-AGE`, and the provider
   credential findings in the migration log.

### Phase 1 — revoke and rotate, highest risk first

| Order | Secret | Action | Evidence |
|---|---|---|---|
| 0 | Sudo/account password disclosed in chat | change it from a local console immediately; if reused elsewhere, rotate those accounts too; do not use the disclosed value | password-change confirmation; `sudo -n true` still fails until the new password is entered locally |
| 1 | GPG passphrase/key | change the passphrase; revoke/rotate the affected key; generate a new key if signing/encryption is still needed | `gpg --list-secret-keys`, revocation certificate, new fingerprint |
| 2 | age key | stop using the old key; generate a new per-host key; re-encrypt sops files to the new recipient | `age-keygen`, `sops updatekeys`, recipient list |
| 3 | SSH key | generate a new key; install new public key; remove old public key from servers | `ssh-keygen -lf`, server `authorized_keys` diff |
| 4 | Cloud/provider keys | revoke old AWS/GitHub/Docker/Kubernetes/AI-provider/tunnel tokens; issue only what is needed | provider audit log, revocation confirmation |
| 5 | Desktop keyring | create a new keyring on NixOS; do not copy the old one | login/keyring proof |
| 6 | New proxy secrets | issue a new upstream DeepSeek key; generate a random inbound key; encrypt with sops | sops decrypt test, proxy health 200 |

Do not put a passphrase or token on a command line. Use the provider UI or an
interactive prompt; do not paste values into chat, shell history, logs, or
reports.

### Phase 2 — provision the new host

1. Generate the `t14` age key on the target, mode 0600, outside the repo.
2. Add only its public key to `.sops.yaml`.
3. Encrypt the two proxy secrets and any other approved secret with `sops`.
4. Commit only ciphertext and public recipients.
5. Build and activate in the VM with a test age key; verify file modes and
   service health.
6. Verify no secret appears in `nix store`, `ps`, unit files, or journal.

### Phase 3 — verify and close

| Check | Command / method | Pass condition |
|---|---|---|
| Secret files | `stat -c '%a %U:%G %n'` on decrypted runtime paths | `0400`/`0600`, `adrioui:adrioui` |
| No plaintext in repo | `gitleaks detect` / `git grep` for known patterns | no findings |
| No secret in store | `nix store cat`/`grep` on built paths for test markers | no findings |
| Proxy health | `curl -fsS http://127.0.0.1:4014/health` | 200, `ok: true` |
| Proxy auth | POST with wrong inbound key | 401 |
| Missing secret | stop sops secret / unset key | 503, no fallback |
| Logs | `journalctl --user -u amp-deepseek-proxy` | no keys, tokens, headers, or bodies |
| Old units | `systemctl --user list-unit-files --state=enabled` | no archived unit enabled |
| Old files | `find /home/adrioui -name 'gpg-preset-passphrase.service' -o -name '*.env' ...` | excluded or absent |

### Phase 4 — emergency rotation

If a new leak is found:

1. Revoke the affected credential at the provider first.
2. Rotate it and update sops ciphertext.
3. Rebuild/activate; verify the old credential is rejected.
4. Audit logs for use of the old credential.
5. Record the incident, scope, and evidence; do not delete evidence.
6. If the age key is compromised, re-encrypt all sops files to a new key and
   rotate every secret in those files.

## 7. Secret inventory maintenance

- Every new secret gets an ID, owner, consumer, storage path, rotation date,
  and revocation procedure.
- Every service that reads a secret must document it in `services.md`.
- Every secret file must be referenced by path, never by value.
- The inventory is reviewed at each gate and before cutover.
- A secret without an owner is not approved for use.

## 8. Approval linkage

Secret rotation is a precondition for:

- Approval 3 (exclusion policy): secret paths must be excluded from restore.
- Approval 4 (cutover/rollback window): old secrets must be revoked before the
  old home is retired.
- Approval 5 (live switch): the NixOS proxy must pass VM secret tests.

No approval is granted by this document. See `docs/design/approvals.md`.
