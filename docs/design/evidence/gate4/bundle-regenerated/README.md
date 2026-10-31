# Regenerated bundle hash chain

Status: **Prepared and accepted 2026-10-31 (A1)**

The original `BUNDLE.sha256` is not a valid self-contained hash chain:

- it contains an empty-file line for itself (`e3b0c442…  ./BUNDLE.sha256`);
- it records `654c567d…` for `BUNDLE.sha256.sha256`, while the actual wrapper
  file is `8bafbeb0…`;
- the wrapper file itself records `b2821778…` for `BUNDLE.sha256`, which does
  match the actual `BUNDLE.sha256`.

Best practice is to remove the impossible self-reference and use a detached
wrapper hash. This directory contains the corrected chain:

| File | SHA-256 |
|---|---|
| `BUNDLE.sha256` (40 entries) | `bed412d87a1eec556c81e9b6f7e31084edfe636dbe6d5eb4828ae68f8c8188a1` |
| `BUNDLE.sha256.sha256` (detached wrapper) | `8e7646bf10b9bc98da3163e204ec5239fed6c0237f7d6f37d79035f011855224` |

Verification:

```bash
cd /run/media/adrioui/backup/evidence-20261030
sha256sum -c /path/to/duniawi/docs/design/evidence/gate4/bundle-regenerated/BUNDLE.sha256
# 40/40 OK

cd /path/to/duniawi/docs/design/evidence/gate4/bundle-regenerated
sha256sum -c BUNDLE.sha256.sha256
# BUNDLE.sha256: OK
```

The read-only backup was not modified; `findmnt` still shows
`ro,nosuid,nodev,relatime,errors=remount-ro`.

The user accepted this regenerated chain on 2026-10-31. The original wrapper
mismatch is documented in `docs/design/approvals.md`.
