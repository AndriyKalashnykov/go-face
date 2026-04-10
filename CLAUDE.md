# CLAUDE.md

## Project Overview

Go library for face recognition using [dlib](http://dlib.net). Wraps dlib's face detection and recognition models via CGo (C++ bindings). Licensed under CC0.

- **Language**: Go (with C++ via CGo)
- **Module**: `github.com/AndriyKalashnykov/go-face`
- **Go version**: 1.26.2 (source of truth: `go.mod`)

## Prerequisites

- Go 1.26.2 (derived from `go.mod`)
- Docker (for container builds and local CI via `act`)
- dlib (>= 19.10) and libjpeg development packages
- golangci-lint, hadolint, gosec, govulncheck (auto-installed by `make deps-*`)

### Ubuntu/Debian

```bash
sudo apt-get install libdlib-dev libblas-dev libatlas-base-dev liblapack-dev libjpeg-turbo8-dev
```

## Build & Test

```bash
make build        # Build the Go project
make test         # Run tests with coverage
make static-check # Composite gate: format-check + lint + vulncheck + sec
make ci           # Full local CI pipeline (static-check + test + build)
make ci-run       # Run GitHub Actions workflow locally via act
```

## Key Variables

| Variable | Value | Purpose |
|----------|-------|---------|
| `APP_NAME` | `go-face` | Project name |
| `GO_VERSION` | derived from `go.mod` | Go toolchain version |
| `GOLANGCI_VERSION` | `2.11.4` | golangci-lint version |
| `HADOLINT_VERSION` | `2.14.0` | hadolint version |
| `GOSEC_VERSION` | `2.22.12` | gosec version |
| `GOVULNCHECK_VERSION` | `1.1.4` | govulncheck version |
| `ACT_VERSION` | `0.2.87` | act version |
| `NVM_VERSION` | `0.40.4` | nvm version (bootstraps Node for Renovate) |
| `NODE_VERSION` | derived from `.nvmrc` | Node version used by `renovate-validate` |

All tool versions have `# renovate:` inline comments; Renovate tracks them via
the generic `customManagers` regex in `renovate.json`.

## Project Structure

```
.
├── face.go              # Main face recognition API (Recognizer type)
├── facerec.cc / .h      # C++ dlib bindings for face recognition
├── classify.cc / .h     # C++ classification logic
├── jpeg_mem_loader.cc/h # JPEG memory loader
├── error.go             # Error types
├── doc.go               # Package documentation
├── face_test.go         # Tests
├── example_test.go      # Example tests
├── Dockerfile           # Multi-arch Docker image build
├── .hadolint.yaml       # Hadolint configuration for Dockerfile linting
├── .nvmrc               # Node version (for Renovate local runs)
├── testdata/            # Test models and images (cloned separately)
└── .github/workflows/   # CI/CD pipelines
```

## CI/CD

### ci.yml

- **Triggers**: push to `main`, tags (`v*`), pull requests, `workflow_call`
- **Concurrency**: cancel-in-progress enabled
- **Permissions**: `contents: read` at workflow level (minimal)
- **Paths ignored**: `**/*.md`, `docs/**`, `.gitignore`, `.claude/**`, `.idea/**`, `LICENSE`, `version.txt`

| Job | Runs on | Description |
|-----|---------|-------------|
| `static-check` | ubuntu-latest (dlib container) | `make static-check` (format-check, lint, vulncheck, sec) |
| `build` | ubuntu-latest (dlib container) | `make build`, needs `static-check` |
| `test` | ubuntu-latest (dlib container) | `make test`, needs `static-check` |
| `docker` | ubuntu-latest (every push) | Hardened image pipeline: build-for-scan, Trivy image scan, smoke test, multi-arch build (push tag-gated), cosign keyless signing (tag-gated) |
| `ci-pass` | ubuntu-latest (`if: always()`) | Aggregator gate — fails if any required job failed or was cancelled |

The `docker` job runs on **every push**, not just tags. Login, push, and
cosign signing are gated at step-level via `if: startsWith(github.ref, 'refs/tags/')`
so multi-arch build and cosign-installer regressions surface on the commit
that introduced them, not on release day. Permissions: `contents: read` +
`packages: write` + `id-token: write` (cosign keyless OIDC) at job level only.
GHCR auth uses the built-in `GITHUB_TOKEN`. Buildkit in-manifest attestations
are disabled (`provenance: false`, `sbom: false`) so the GHCR "OS / Arch" tab
renders — cosign keyless signing provides supply-chain verification instead.

Pre-push gates: (1) build single-arch for scan, (2) Trivy image scan
`CRITICAL`/`HIGH` blocking, (3) smoke test (Go toolchain + source + testdata
invariants), (4) multi-arch build with conditional push, (5) cosign keyless
signing tag-only. See README "Pre-push image hardening" for details.

### cleanup-runs.yml

- **Triggers**: weekly schedule (Sunday midnight), `workflow_dispatch`, `workflow_call`
- **Concurrency**: cancel-in-progress enabled
- **Permissions**: `actions: write`
- `cleanup-runs` job: deletes workflow runs older than 7 days, keeping minimum 5
- `cleanup-caches` job: deletes action caches last accessed more than 7 days ago

## Key Makefile Targets

| Target | Description |
|--------|-------------|
| `make help` | List available tasks |
| `make deps` | Check Go is installed |
| `make deps-docker` | Check Docker is installed |
| `make deps-lint` | Install golangci-lint for static analysis |
| `make deps-hadolint` | Install hadolint for Dockerfile linting |
| `make deps-gosec` | Install gosec security scanner |
| `make deps-govulncheck` | Install govulncheck vulnerability scanner |
| `make deps-act` | Install act for local CI |
| `make clean` | Remove build artifacts |
| `make format` | Format Go code |
| `make format-check` | Verify Go code is formatted |
| `make build` | Build the Go project |
| `make lint` | Run golangci-lint and hadolint |
| `make vulncheck` | Run govulncheck vulnerability scanner |
| `make sec` | Run gosec security scanner |
| `make static-check` | Composite static-analysis gate (format, lint, vuln, sec) |
| `make run` | Run the example |
| `make testdata` | Get test data |
| `make test` | Run tests with coverage |
| `make update` | Update dependency packages to latest versions |
| `make ci` | Run full local CI pipeline |
| `make ci-run` | Run GitHub Actions workflow locally using act |
| `make ci-run-tag` | Run the tag-gated docker job under act (simulates tag push) |
| `make release` | Create and push a new tag |
| `make tag-delete` | Delete a git tag locally and remotely (`TAG=vN.N.N`) |
| `make image-bootstrap` | Bootstrap Docker buildx multi-platform builder |
| `make image-build` | Build Docker image (amd64) |
| `make image-run` | Run Docker image interactively (amd64) |
| `make image-stop` | Stop any running `go-face` container |
| `make renovate-bootstrap` | Install nvm and node for Renovate |
| `make renovate-validate` | Validate Renovate configuration |

## Skills

Use the following skills when working on related files:

| File(s) | Skill |
|---------|-------|
| `Makefile` | `/makefile` |
| `renovate.json` | `/renovate` |
| `README.md` | `/readme` |
| `.github/workflows/*.{yml,yaml}` | `/ci-workflow` |

When spawning subagents, always pass conventions from the respective skill into the agent's prompt.
