# Design evidence artifacts

These are the earlier sanitized snapshots captured during Gate 0–4. The
decision-grade, current ledger and raw Phase 0 outputs are in the top-level
`evidence/` directory (`evidence/LEDGER.md`, `evidence/raw/`).

Redactions:

- hardware serial numbers and product serials;
- LAN IP addresses, gateway, and Wi-Fi SSID;
- no credential, token, key, or passphrase is included.

The full VM transcript is in `gate3/vm-test.log`. Test keys (`test-upstream`,
`test-inbound`) appear only as names in the test script assertions; no
production secret is present.
