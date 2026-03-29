# CLAUDE.md

## Project Overview

Go library for face recognition using [dlib](http://dlib.net). Wraps dlib's face detection and recognition models via CGo (C++ bindings). Licensed under CC0.

- **Language**: Go (with C++ via CGo)
- **Module**: `github.com/AndriyKalashnykov/go-face`
- **Go version**: See `go.mod`

## Prerequisites

- Go (version from `go.mod`)
- Docker (for container builds)
- dlib (>= 19.10) and libjpeg development packages
- golangci-lint (auto-installed by `make deps`)

### Ubuntu/Debian

```bash
sudo apt-get install libdlib-dev libblas-dev libatlas-base-dev liblapack-dev libjpeg-turbo8-dev
```

## Build & Test

```bash
make build       # Build the Go project
make test        # Run tests with coverage
make lint        # Run static analysis and Dockerfile linting
make ci          # Full local CI pipeline (lint, test, build)
make ci-run      # Run GitHub Actions workflow locally via act
```

## Key Variables

| Variable | Value | Purpose |
|----------|-------|---------|
| `APP_NAME` | `go-face` | Project name |
| `GOLANGCI_VERSION` | `2.1.6` | golangci-lint version |
| `HADOLINT_VERSION` | `2.12.0` | hadolint version |
| `ACT_VERSION` | `0.2.86` | act version |
| `NVM_VERSION` | `0.40.4` | nvm version for Renovate |

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
├── testdata/            # Test models and images (cloned separately)
└── .github/workflows/   # CI/CD pipelines
```

## CI/CD

### ci.yml

- **Triggers**: push to `main`, tags (`v*`), pull requests
- **Concurrency**: cancel-in-progress enabled
- **Permissions**: `contents: read` at workflow level (minimal)

| Job | Runs on | Description |
|-----|---------|-------------|
| `ci` | ubuntu-latest (dlib container) | Checkout, setup Go, `make lint`, `make test`, `make build` |
| `release-docker-images` | ubuntu-latest (tag-only) | Build and push multi-arch Docker images to GHCR |

The `release-docker-images` job has elevated permissions (`contents: write`, `packages: write`) at job level only.

### cleanup-runs.yml

- **Triggers**: weekly schedule (Sunday midnight) + manual dispatch
- **Permissions**: `actions: write`
- Deletes workflow runs older than 7 days, keeping minimum 5

## Key Makefile Targets

| Target | Description |
|--------|-------------|
| `make help` | List available tasks |
| `make deps` | Check required tools (Go + Docker + golangci-lint) |
| `make clean` | Remove build artifacts |
| `make build` | Build the Go project |
| `make lint` | Run static analysis and Dockerfile linting |
| `make test` | Run tests with coverage |
| `make ci` | Full local CI pipeline (lint, test, build) |
| `make ci-run` | Run GitHub Actions workflow locally using act |
| `make release` | Create and push a new tag |
| `make image-build` | Build Docker image (amd64) |
| `make image-run` | Run Docker image interactively (amd64) |
| `make update` | Update dependency packages to latest versions |
| `make renovate-validate` | Validate Renovate configuration |

## Skills

Use the following skills when working on related files:

| File(s) | Skill |
|---------|-------|
| `Makefile` | `/makefile` |
| `renovate.json` | `/renovate` |
| `README.md` | `/readme` |
| `.github/workflows/*.yml` | `/ci-workflow` |

When spawning subagents, always pass conventions from the respective skill into the agent's prompt.
