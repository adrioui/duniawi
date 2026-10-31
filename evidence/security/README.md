# Security evidence

## Chat-disclosed sudo credential

- Date: 2026-10-31
- Value: not recorded here and not used.
- Actions: `sudo -k`; `sudo -n true` still fails; repository scan found no
  occurrence; no privileged command was run.
- Required user action: change the account password from a local console.
- Status: **Open** until the user confirms the change.

## Secret rotation

| Secret | Old location | Action | Evidence | Status |
|---|---|---|---|---|
| Sudo/account password | chat | change from local console | user confirmation | Open |
| SOPS age private key | `.config/sops/age/keys.txt` in backup | do not reuse; generate new `t14` key | `age-keygen` output public key only | Open |
| SSH private key | `.ssh/id_ed25519` in backup | new key | `ssh-keygen -y` on new key | Open |
| GPG keys/passphrase | `.gnupg/` and inline unit | rotate/revoke | revocation certificate | Open |
| AWS credentials | `.aws/credentials` | revoke | provider audit | Open |
| GitHub token | `.config/gh/hosts.yml` | revoke/re-auth | GitHub audit | Open |
| Docker auth | `.docker/config.json` | revoke | registry audit | Open |
| Kubernetes config | `.kube/config` | rotate | cluster audit | Open |
| Provider/proxy keys | old proxy config dirs | revoke; new sops keys only | provider audit | Open |

No secret value, token, key, or passphrase appears in this file or the repo.

## Proxy provisioning

`ampDeepseekNixos.sopsFile` is still `null`. The production service therefore
starts without credentials and returns HTTP 503 on `/health`. This is the
intended fail-closed state, not a pass. A real `/health` 200 requires the new
age key and encrypted sops file.
