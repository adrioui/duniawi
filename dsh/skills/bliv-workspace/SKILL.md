---
name: bliv-workspace
description: "Verified working standards for the BLIV workspace — btj--bliv (polyglot monorepo), btj--bliv-superset (Apache Superset fork), and clusters/ (split service repos). Use for any task in these folders: Python/FastAPI services, Go gateway, Vue/TypeScript frontends, Java NiFi processors, Ansible deploys, Superset customization, or git/CI workflows."
---
These standards were written by auditing the actual repos (file trees, config files, git history) on 2026-08-08. Every claim below was verified against code at that date; existing AGENTS.md/CLAUDE.md/deepwiki docs were deliberately NOT trusted (they contain proven drift — see "Verified drift" below). If a rule cannot be verified against current code, treat it as suspect. When in doubt, re-verify before acting.

## Decision priority

1. Preserve correctness, safety, and debuggability (these are production systems with licensing).
2. Verify, don't assume: grep/read the actual code before following a rule from any doc.
3. Follow the per-service conventions below; they differ per service (e.g., CLI entrypoints, pydantic version).
4. Keep changes small and surgical; no drive-by refactors; never touch unrelated services.
5. Volatile facts (branch names, ticket numbers, test counts) never belong in instructions — describe conventions, not state.

## What BLIV is

An ETL/data platform built around Apache NiFi, with: Go gateway (Envoy + `ext_authz` license enforcement), FastAPI backends, Vue/Nuxt frontends, Keycloak identity, Grafana + Superset dashboards, Trino + MinIO data lake, licensing enforced at the edge AND inside Python services, MLflow for MLOps, and a second product brand ("mtel").

## Repo map (verified)

| Folder | Repo | What it contains |
|---|---|---|
| `btj--bliv/` | github.com/bangunindo/btj--bliv | Polyglot monorepo: all services under `src/`, Ansible under `deploy/`. 9,439 commits since 2021-10, 390 branches, **zero tags**. Current branch: `develop`; `main` exists. |
| `btj--bliv-superset/` | github.com/bangunindo/btj--bliv-superset | Apache Superset fork (full history since 2015, 17,229 commits). BLIV customization started 2025-05 (merged from the monorepo's `superset_custom` dir). Branches: `btj-main` (release), `btj-dev` (integration), `mtel` (second brand). |
| `clusters/` | not a git repo | Two groups of split repos extracted from the monorepo. `cluster_1/` = admin-panel, ai-studio (+ empty explore placeholder); `cluster_2/` = pipeline, data-house, mlops. Also `AGENTS-METHODOLOGY.md` (audit of the split repos' AGENTS.md) and `Sprint Review #66.pdf`. |

### Split repos ↔ monorepo services (verified via `src/` listings)

| Split repo | Monorepo services it contains |
|---|---|
| cluster_1/btj--bliv-admin-panel | `backend_admin`, `frontend_admin_v2`, `custom_lib` (submodule) |
| cluster_1/btj--bliv-ai-studio | `backend_aistudio`, `frontend_dify`, `dify_custom_plugins`, `yjs_websocket_ai_studio`, `custom_lib` (submodule) |
| cluster_1/btj--bliv-explore | **empty repo** (0 commits, placeholder) |
| cluster_2/btj--bliv-pipeline | `backend` (core), `frontend_etl`, `nifi_custom_2`, `generate_nifi_class`, `v2_migration`, `custom_lib` (submodule) |
| cluster_2/btj--bliv-data-house | `backend_data_house`, `frontend_data_house`, `jdbc_driver`, `custom_lib` (submodule) |
| cluster_2/btj--bliv-mlops | MLflow fork (root) + `backend_mlops` + `custom/mlflow_oidc_auth` + `dev/` + `custom_lib` (submodule) |

All split repos mount `src/custom_lib` as a git submodule → `git@github.com:bangunindo/btj--bliv-custom-lib.git` (a separate repo). **In cluster_1 repos the submodule is NOT initialized** (`git submodule update --init` needed). The submodule content is byte-identical to the monorepo's inline `src/custom_lib/py` (checked 2026-08-08).

## Language & tooling matrix (verified versions)

| Area | Stack | Versions |
|---|---|---|
| Python services | FastAPI, uv, Python | fastapi 0.111.1 (core), SQLAlchemy 2.0.35 async + asyncpg, alembic 1.11.1, Python >= 3.11 |
| Pydantic | **split** | v1 `1.10.14`: `backend`, `backend_admin`. v2 `2.11.3`: `aistudio`, `data_house`, `executive_hub`, `mlops`, `sys_admin`, `virtualization`. `2.12.3`: `chat_assistant` |
| Go | gateway, webhook, machine_info_go | go 1.22; envoyproxy/go-control-plane v0.12.0, golang-jwt/v5, pgx/v5, go-redis/v9, GCP secretmanager, grpc |
| Frontends | Vue 3 + Vite + TS, pnpm | vue 3.4–3.5.x; `frontend_map` is Nuxt 3; keycloak-js 24; pinia; tailwind + shadcn-vue; `@bangunindo/btj-ui` (private, GCP Artifact Registry) |
| Java | NiFi custom processors (Maven) | NiFi base `apache/nifi:1.28.1` (both nifi_custom and nifi_custom_2); Maven 3.8.7 (custom_1) / 3.9.7 (custom_2); Go 1.21 helper binaries |
| Ansible | deploys | playbooks under `deploy/`; `bangunindo/ansible` image; vault-encrypted vars; hosts named `mjolnir-*` |
| Superset | fork | Python >= 3.10; frontend v5.0.0, React 17; Node websocket; embedded SDK 0.1.3 |
| Local dev | pixi (conda-forge) + process-compose + mise | postgres >=15,<17 native; redis >=7; process-compose >=1.0; uv >=0.5 |

## Python / FastAPI conventions

### Per-service CLI entrypoints (verified — they DIFFER per service!)

| Service (path) | `main.py` args |
|---|---|
| `src/backend` (core, monorepo + pipeline repo) | `api`, `migrate`, `sync-monitoring` |
| `src/backend_admin` (monorepo + admin-panel) | `api`, `migrate`, `create_migration`, `rollback`, `create_migration_log`, `rollback_log`, `sync_monitoring_user` |
| `src/backend_data_house` (monorepo + data-house) | `api`, `migrate`, `rollback`, `create_migration` |
| `src/backend_mlops` (monorepo + mlops) | `api`, `migrate`, `create_migration`, `rollback` |
| `src/backend_aistudio` | `api`, `migrate`, `create_migration`, `rollback` |

- **Migrations run via `python main.py migrate`** (or `uv run python main.py migrate`), never raw `alembic upgrade` — some services only expose migrate through main.py. Rollback: `python main.py rollback [N]`.
- admin_panel has TWO independent Alembic trees: `migrations/` (admin schema) and `migrations_log/` (audit log), plus DSNs `BLIV_ADMIN_DB_DSN` and `BLIV_LOG_DB_DSN`.
- Migration file counts (verified): core backend 193, data_house 66, admin 19, chat_assistant 13, virtualization 3.
- **Feature pattern**: `api/<feature>/views.py` (routes) → `use_cases.py` (logic) → `schemas.py` (Pydantic contracts); models in `models/`; app wiring in `api/main.py`.
- **God-files are real**: `backend/api/canvas_utils/use_cases.py` is 9,344 lines, `process_group` 7,453, `backend_admin/api/user` 4,421, `data_lake` 3,163. Do not add orchestration to a use_cases.py > ~500 lines; split by concern.
- **Pre-commit (all repos, same stack)**: black (line-length 100), mypy (strict-optional, ignore-missing-imports, follow-imports=silent), isort (profile=black, filter-files), flake8 (max-line-length 100, flake8-print), trailing-whitespace, check-merge-conflict, debug-statements. Excludes: `^.*migrations.*$` and `^.*superset_config.py.*$` — **migrations and superset_config are never linted/formatted; review them manually**. Run `pre-commit run --files <changed.py files>` after Python changes.
- **Config**: pydantic `BaseSettings` with `BLIV_*` env vars (`BLIV_CURRENT_ENVIRONMENT`, `BLIV_*_DB_DSN`, `BLIV_SECRET_KEY`, ...). Per-service `config/example.env` → copy to `config/local.env`; some services load config via `APP_CONFIG_FILE=local`.
- **bliv_lib** (`src/custom_lib/py/bliv_lib/`): shared SDK with `audit_log/`, `cloud_lib/` (minio_lib, gcs_lib), `middlewares/` (license, exceptions, metrics, OTel), `utils/` (license.py). Installed in split repos as local path dep (`bliv-lib = { path="../custom_lib/py" }`). **Changes to bliv_lib affect every service that imports it — list all consumers and run tests on the testable services.**
- **Tests reality (verified)**: only `backend_data_house` (11 unit tests in `tests/unit/`) and `backend_virtualization` (3) have substantive tests; `backend` has a single example (`tests/test_routes/test_examples.py`). admin-panel, ai-studio, pipeline (2 files), mlops backend_mlops: none. Don't assume `pytest` exists; check first.
- **Time helpers**: `_naive_utc_now` exists ONLY as local definitions in `backend_data_house/api/{sheet,sql_request,data_lake}/use_cases.py`. Docs claiming a shared `utils/time.py` or `utils/datetime.py` helper are wrong. **DB columns are naive `DateTime()`; never mix aware/naive timestamps.**
- **`quoted_identifier` does not exist anywhere in `src/`** (0 matches, verified). Never reference it; use parameterized queries. SQL injection via f-strings (including Trino) is a real incident class here.
- **Remote I/O inside DB transactions** (HTTP/gRPC/Trino calls inside `async with session.begin()`) causes silent failures and pool exhaustion — move remote calls outside the transaction.

## Go

- **Gateway** (`src/gateway/`): Envoy xDS control plane + `ext_authz` gRPC license enforcement. Entrypoint `cmd/gateway/main.go`; dirs: `envoy/` (server, auth), `license/`, `nifi/`, `redis/`, `sysadmin/`, `error_templates/`, `eventtracking/`. Build: `go build ./cmd/gateway` (go 1.22).
- Flow: Envoy → ext_authz → Redis `LICENSE` key (JWT) → miss: fetch from SysAdmin (`GET /api/v1/admins/licenses/organization/{org_uuid}`) → product-specific checks (NiFi task limits, Grafana dashboards/panels, Superset dataset/dashboard creation) → allow/deny.
- **Webhook** (`src/webhook/`): Go service that deletes the Redis `LICENSE` key to invalidate the cached license.
- License is enforced in two places by design: gateway (edge) + Python middleware (`bliv_lib/middlewares/license.py`). Keep cache semantics consistent.
- `go_src/` dirs exist inside `grafana_custom/`, `keycloak_custom/`, `nifi_custom/`, `nifi_custom_2/` — Go helper binaries built in Docker multi-stage (golang:1.21-alpine).

## Vue / TypeScript frontends

- Each frontend is its own pnpm project under `src/frontend_*` (or in split repos). `frontend_map` is Nuxt 3; others are Vite + Vue 3.
- **Dev ports (verified)**: `frontend_etl` and `frontend_dify` → 5174; others default 5173.
- **Standard scripts (all verified in package.json)**: `dev`, `staging`, `build` (type-check + build-only), `build-only`, `preview`, `type-check` (vue-tsc), `lint`, `format` (prettier), `shadcn-add`, `test` / `test:unit` / `test:integration` / `test:e2e` (vitest; e2e = Selenium WebDriver), `depr` (full dep refresh), `update:btj-ui-latest`, and `service-account:*`.
- **`@bangunindo/btj-ui` is private, hosted on Google Artifact Registry.** Before `pnpm install`: run `pnpm service-account:run` (switches gcloud account + writes `.npmrc`). 401/403 on install ⇒ re-run it. Some frontends list btj-ui in `dependencies` (ai-studio: 1.0.24-bt), others in `devDependencies` (admin-panel: 0.9.48) — check before editing.
- **Two UI libraries**: shadcn-vue primitives under `src/components/ui/` (local, via `pnpm shadcn-add`) + BTJ UI brand components (BButton, BInput, BTable, ...). Do not reimplement BTJ UI components locally. Tailwind brand tokens (`bliv-*`) are defined in `tailwind.config.js` per app — prefer tokens over hex values. Use the `cn()` util for class merging.
- **Husky hooks live at repo ROOT** (created by `pnpm install` in a frontend package): pre-commit (lint-staged, frontend files only), commit-msg (commitlint conventional commits), pre-push (type-check on affected frontends). Some repos have NO root package.json (admin-panel) — husky is configured from the frontend package.
- **Key deps in frontend_etl** (flagship ETL canvas): yjs 13.6 + y-websocket + @syncedstore/core (CRDT collaboration), @vue-flow/core 1.48 (node canvas), tiptap (rich text), @guolao/vue-monaco-editor, keycloak-js 24, Sentry.

## Java / NiFi

- `src/nifi_custom` and `src/nifi_custom_2`: Maven multi-module Java projects (NiFi custom processors, controllers, NARs) built in Docker with `maven:3.8.7` / `maven:3.9.7` builders, final image `apache/nifi:1.28.1`. nifi_custom_2 adds `bliv-custom-prometheus` and `bliv-custom-processor-python` modules.
- Custom processors implement PostgreSQL/MariaDB **CDC capture** (logical replication slots, pgoutput/test_decoding plugins) emitting JSON FlowFiles — see pipeline repo's `docs/capture-change-*.md` and `CONTEXT.md` for the domain language.
- Cloud builds: `cloudbuild-development.yaml` / `cloudbuild-release.yaml` per component (Kaniko → Artifact Registry).
- Changes here are Java + Maven; there are no Java tests — verify by building the image.

## Ansible / deployment

- **Layout** (`btj--bliv/deploy/`): `development/ansible/` (inventory.yaml + inventory/ + playbooks/), `datathon/` (per-customer inventories + setup/run playbooks), `demo/`, `poc/`, `gateway-test/`, `artifacts/trino-plugins/`.
- **Playbooks** (verified names): deploy-services.yaml (renders docker-compose from `docker-compose.yml.j2`, reloads HAProxy), deploy-backend, deploy-frontend, deploy-runner, keycloak, grafana, datahouse, dify, clickhouse(-dev/-test), elasticsearch, etcd, hadoop, jupyter, langfuse, letsencrypt(-staging), haproxy(-staging), bliv-gateway, aistudio(-dev), executive-hub, bytebase, chromadb, antvis, admin.
- **Secrets**: inventories contain `!vault` / `$ANSIBLE_VAULT` encrypted values; vault password + SSH key fetched from **Google Secret Manager** in CI (`deploy-development.yaml` / `deploy-staging.yaml`, `bangunindo/ansible` image, `dawidd6/action-ansible-playbook`, `--user root`). Local datathon flow uses `deploy/.vault-password`.
- **Hosts** are named `mjolnir-*` (e.g., `mjolnir-dev.vm.bangunindo.io`). TZ: Asia/Jakarta. Containers run on VMs with `community.docker` modules.
- **`setup-datathon.sh`** is the reference orchestration: machine-info → setup-dns → 00-setup-host → 01-install-docker → letsencrypt → registry login → per-service install, with confirm prompts. Pattern: `ansible-playbook --vault-password-file deploy/.vault-password -i deploy/datathon/inventory/<name>.yaml ...`.
- **Never commit real secrets**; `deploy/**/files/**` (certs, keys, service-account JSONs) are sensitive.

## Superset fork (btj--bliv-superset)

- **Branches/CI**: `btj-dev` → build-development; `btj-main` → build-release; `mtel` → build-mtel. PRs merge into `btj-dev`; releases go to `btj-main`. Upstream commits (2015–2025) are in history; don't rewrite them.
- **Custom surface (verified paths)**:
  - `superset-custom-api/` — extra Flask-AppBuilder APIs: `custom/api.py` (custom username/password auth + guest token), `session/api.py` (`GET /custom/session`), `viz.py`.
  - `superset/custom_views/custom_dashboard.py` — route base `/bliv/dashboard`.
  - `superset/semantic_layer/api.py` — BLIV semantic layer API.
  - `superset/db_engine_specs/clickhouse.py` — engine "ClickHouse Connect (Bliv Dashboard)".
  - Frontend: ~21 files under `superset-frontend/src` (custom icons, CustomRightMenu, `utils/getChatAssistantConfig.ts`, VirtualizationList page, MagicDashboardModal, routes, branding).
  - Config: `docker/pythonpath_dev/superset_config.py` reads `BLIV_DATA_HOUSE_API_URL/KEY/TIMEOUT/MODULE_ENABLED/SUPERSET_DATABASE_ID` (dashboard ← data-house integration).
- **Run**: `docker-compose-bliv.yaml` (includes `docker-compose.celery.yml`; builds `Dockerfile.bliv`; superset app on `5174:8088`; Trino at `mjolnir-dev.vm.bangunindo.io:8888`; `SUPERSET_LOAD_EXAMPLES=no`). Other variants: `Dockerfile.mtel`, `docker-compose-mtel.yaml`.
- **License compliance is a real practice**: btj-dev added scripts that annotate modified files and regenerate `MODIFICATIONS.txt` + `NOTICE` (the fork must stay ASF-compliant). Keep NOTICE/MODIFICATIONS updated when modifying upstream files.
- This repo is quiet since 2026-06 — active dashboard work happens in the data-house split repo; superset is consumed as an image.

## Git & CI conventions (all verified from history)

- **Branch naming**: `bliv-XXXX/short-slug` (dominant; older commits used uppercase `BLIV-XXXX/`), plus `fix/`, `hotfix/`, `feat/`, `chore/`, `poc/`, `pr-NNNN/`, person-named branches, and `backup/...` branches (pre-rebase snapshots, e.g., `backup/bliv-4786-pre-origin-develop-rebase-...`). Never delete or force-push backup branches.
- **Commit messages**: Conventional Commits with service scopes (`fix(backend_data_house)`, `feat(gateway)`, `infra(playbooks)`, `feat(mlflow_custom)`). commitlint: types `feat|fix|docs|style|refactor|perf|chore|ci|build|revert`, header ≤ 100. Actual mix (last 2000, monorepo): fix 565, feat 453, refactor 165, chore 57, style 13, build 12, test 6, docs 4. Merge commits via GitHub PRs ("Merge pull request #N from bangunindo/...").
- **Release flow (monorepo)**: PRs → `develop`; release = PR `develop` → `main`; hotfix branches PR straight to `main`. Zero tags. `build-development` on develop push, `build-release` on main push, both path-filtered to changed services.
- **CI**: GitHub Actions on `self-hosted-bangunindo` / `self-hosted-bliv` runners; builds via **GCP Cloud Build (Kaniko → Artifact Registry)** with service-account auth; deploys via Ansible. `.gitlab-ci.yml` is legacy (run.sh) — ignore unless explicitly asked.
- **dependabot** opens branches for uv/pip/npm_and_yarn/go_modules/maven (116 branches in monorepo) — merge them like any PR.
- **Submodules**: split repos need `git submodule update --init` (custom_lib). CI does "Checkout repository with submodules".
- **Split-repo release flow** (ai-studio observed): PRs → develop; main gets periodic `develop → main` PRs; hotfix PRs to main. Same for admin-panel/data-house.

### Day-to-day git/gh workflow (no jj — plain git + GitHub CLI only)

A `.jj` directory happens to exist in the data-house working tree — ignore it; it is not part of the workflow. All work is conventional GitHub flow with `git` and `gh`:

```bash
# 1. Start from the integration branch (develop, or btj-dev for superset)
git switch develop
git pull origin develop
git switch -c bliv-XXXX/short-slug        # ticket in the branch name

# 2. Work, then commit — explicit staging only, never `git add -A`/`.`
git add <specific files>
git commit -m "feat(scope): imperative summary"   # commitlint: header <= 100 chars

# 3. Push and open the PR against the repo's integration branch
git push -u origin bliv-XXXX/short-slug
gh pr create --base develop --title "feat(scope): ..." --body "What/why, ticket link, verification evidence"

# 4. Review others' PRs without disturbing your own worktree
gh pr checkout <number>
gh pr diff <number>          # review without checking out
gh pr view <number>

# 5. After merge, clean up
git switch develop && git pull origin develop
git branch -d bliv-XXXX/short-slug
git push origin --delete bliv-XXXX/short-slug
```

- Base branch per repo: `develop` (monorepo, admin-panel, ai-studio, data-house, pipeline) or `btj-dev` (superset, mlops). Releases: PR `develop`/`btj-dev` → `main`/`btj-main`. Hotfixes: branch off main and PR straight to main.
- Never force-push, `git reset --hard`, `git checkout .`, `git clean -fd`, or `git stash` (multi-session safety — `backup/` branches exist precisely because rebases are risky).
- Multi-session safety: stage explicit paths only; if a rebase conflict lands in a file you didn't touch, abort and ask rather than resolving blindly.

## Local development

### Monorepo (btj--bliv)

```bash
./hack/generate-local-env.sh <ticket>   # writes config/local.env for 5 services
pixi install
pixi run setup                          # uv sync for core services
pixi run migrate                        # migrations for backend, data_house, virtualization, chat_assistant (+admin with migrate:all)
pixi run dev                            # infra + native PG/Redis + backend, chat-assistant, data-house, virtualization (NO backend_admin)
pixi run dev:all                        # + backend_admin
pixi run down
```

- Shared infra (Keycloak 8080, Trino 8085, NiFi 8443, MinIO 9000/9001): `pixi run infra-up` (`docker compose -p bliv-infra -f docker-compose.infra.yml up -d --wait`).
- Native PG/Redis on 5432/6379 — one worktree at a time; per-worktree alternative: `docker compose -p bliv-wt-${BLIV_WORKTREE_ID} -f docker-compose.worktree.yml up -d --wait` (PG 5400, Redis 6300). Override process-compose control port: `PC_PORT_NUM=18008 pixi run dev`.
- `pixi run db:reset` wipes `.devdata/postgres` and recreates all app DBs — destructive.
- Python service, manual: `cd src/<service> && uv sync && uv run python main.py api`.
- Worktree helper: `hack/create_worktree.sh`. `hack/`, `process-compose.yaml`, `docker-compose*.yml` may be excluded from `git status` on purpose.

### Split repos

- **data-house** has the full stack: `pixi run setup`, `pixi run dev` (native PG/Redis + **external Keycloak required** + Trino/MinIO via `docker-compose.infra.yml`), `pixi run migrate`, `pixi run check`, `pixi run qa-auth`, `pixi run env:generate`, `pixi run db:reset`. Process-compose: postgres, redis, db-init, redis-seed, external-keycloak, data-house-ready, migrate-data-house, data-house.
- **pipeline**: no pixi; backend runs manually (`uv sync` + `uv run python main.py api`); frontend via pnpm. Repo root contains agent scratch files (`CONTEXT.md`, `progress.md`, `bliv5669-*.md`, `canvas834_*.json`, `local/`) — leave them alone unless asked.
- **admin-panel / ai-studio**: `cd src/<service>` and use uv (backend) / pnpm (frontend). Remember the btj-ui service-account auth before frontend installs, and `git submodule update --init`.

## Verified drift in existing docs (do not trust these)

- `quoted_identifier` — referenced in CLAUDE.md as a helper; **does not exist in any repo**.
- "Pydantic v2 string coercion" — `backend` and `backend_admin` pin **pydantic 1.10.14 (v1)**; the coercion rule (if kept) is a v1 behavior. The "v2" label is wrong for those services.
- "Docker Compose `--wait` is broken" (CLAUDE.md) — `--wait` is used by the official `infra-up` tasks in pixi.toml and .mise.toml; the claim is stale.
- ai-studio's tracked AGENTS.md says "no formatter or linter configured" — the repo root has a full black/mypy/isort/flake8 pre-commit config.
- `_naive_utc_now` from `utils/time.py` — only exists locally inside 3 data_house use_cases files.
- cluster_2 AGENTS.md files are an unverified template (31 placeholders) — never copy rules from them.
- Docs that hardcode "current branch" or test-file counts go stale immediately (observed in pipeline/data-house AGENTS.md).

## Boundaries

**Always**: verify commands against `main.py` CLI / package.json scripts before running; run pre-commit on changed Python files; use `git submodule update --init` in split repos; stage explicit paths (never `git add -A`); list affected services when bliv_lib changes; keep NOTICE/MODIFICATIONS updated in superset.

**Ask first**: before removing functionality that appears intentional; before running destructive tasks (`pixi run db:reset`, `migrate:all`, ansible deploys); before force-pushing or rewriting `backup/` branches; before touching `deploy/**/files/**` or secrets.

**Never**: commit secrets/DSNs/keys; `git reset --hard`, `git checkout .`, `git clean -fd`; edit generated migration files directly (create via `main.py create_migration` where available); run `alembic upgrade` directly; interpolate user input into SQL; do remote I/O inside open DB transactions; rewrite upstream Superset history; use `pnpm install` without service-account auth first; trust a doc over the code.

## Keeping this skill accurate

Rules rot when they drift from code. On every session touching these repos, spot-check at least: (1) one path/command referenced here exists, (2) pydantic version of the service you're editing, (3) `main.py` CLI args. If you find drift, fix this file in the same change that caused the drift.