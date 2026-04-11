[![CI](https://github.com/AndriyKalashnykov/go-face/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/AndriyKalashnykov/go-face/actions/workflows/ci.yml)
[![Hits](https://hits.sh/github.com/AndriyKalashnykov/go-face.svg?view=today-total&style=plastic)](https://hits.sh/github.com/AndriyKalashnykov/go-face/)
[![License: CC0](https://img.shields.io/badge/License-CC0-brightgreen.svg)](https://creativecommons.org/publicdomain/zero/1.0/)
[![Renovate enabled](https://img.shields.io/badge/renovate-enabled-brightgreen.svg)](https://app.renovatebot.com/dashboard#github/AndriyKalashnykov/go-face)

# go-face

go-face provides **face recognition for Go** via CGo bindings to [dlib](http://dlib.net) — the C++ machine learning toolkit that implements the [FaceNet](https://arxiv.org/abs/1503.03832) embedding approach. This repo is a maintained fork of [Kagami/go-face](https://github.com/Kagami/go-face) with a hardened multi-architecture container publishing pipeline bolted on top. For background on how the underlying recognition works, read [Face recognition with Go](https://hackernoon.com/face-recognition-with-go-676a555b8a7e).

**Two ways to consume this project:**

1. **As a pre-built Docker builder image** (recommended for CGo-shy users). Pull `ghcr.io/andriykalashnykov/go-face/dlib19:<tag>` or `ghcr.io/andriykalashnykov/go-face/dlib20:<tag>` and `FROM` it in your own `Dockerfile` — you inherit a full C++ toolchain, dlib (both shared **and** static), Go, libjpeg/libpng/BLAS/LAPACK, the `go-face` source tree mounted at `/app`, and Kagami's test data. No local dlib install, no cmake compile on your CI runner. Jump to [Using as a builder image](#using-as-a-builder-image).
2. **As a Go library** via `go get github.com/AndriyKalashnykov/go-face`. Works like any Go package, but requires dlib + libjpeg on the host before `go build` / `go test` will link. See [dlib Installation](#dlib-installation).

**Position in the image-build chain.** go-face is the middle link of a three-repo chain maintained by the same author:

```
ghcr.io/andriykalashnykov/dlib-docker:<dlib-version>
  ↓  (digest-pinned FROM)
ghcr.io/andriykalashnykov/go-face/dlib<major>:<go-face-version>   ← this repo
  ↓  (digest-pinned FROM, per CI matrix cell)
ghcr.io/andriykalashnykov/go-face-recognition:<app-version>
```

The upstream [`dlib-docker`](https://github.com/AndriyKalashnykov/dlib-docker) repo provides the Ubuntu+dlib base image (with both `libdlib.so` and `libdlib.a`). This repo adds the Go toolchain and the go-face CGo source tree on top, publishing **one image per active dlib major lineage** so downstream consumers can pin to a specific dlib ABI. The downstream [`go-face-recognition`](https://github.com/AndriyKalashnykov/go-face-recognition) application is a worked example of static-linking a CGo binary against this image's `libdlib.a`.

## What this fork adds on top of upstream Kagami/go-face

- **Multi-architecture pre-built Docker images** published per-release to GHCR for `linux/amd64`, `linux/arm64`, and `linux/arm/v7` as a single multi-arch manifest list.
- **Per-lineage matrix build.** The active dlib majors are declared in [`.dlib-versions.json`](./.dlib-versions.json); CI fans out `static-check`, `build`, `test`, and `docker` once per lineage so each supported dlib ABI is validated on every commit.
- **Hardened image publishing pipeline.** Trivy image scan (CRITICAL/HIGH blocking), smoke test, cosign keyless OIDC signing via Sigstore Fulcio → Rekor, and `fail-fast: false` so one broken lineage doesn't block the others.
- **Automated release plumbing** that watches upstream `dlib-docker` and `davisking/dlib` for new versions and bumps `.dlib-versions.json` automatically — see [Automated releases](#automated-releases) below.
- **Pinned, reproducible tooling** — Go version, `dlib-docker` digest, linters, scanners, and GitHub Actions are all version- and digest-pinned, with Renovate keeping them fresh via branch-automerge squash PRs.

| Component | Technology |
|-----------|------------|
| Language | Go 1.26.2 (version derived from `go.mod`, kept fresh by Renovate) |
| Native bindings | C++ via CGo linking `libdlib` |
| Recognition engine | [dlib](http://dlib.net) ≥ 19.24 — provided by the `dlib-docker` base image |
| Image decoding | libjpeg (turbo) — from the `dlib-docker` base image |
| Base image | `ghcr.io/andriykalashnykov/dlib-docker:<tag>@<digest>`, one per active dlib major lineage, pinned in [`.dlib-versions.json`](./.dlib-versions.json) |
| Published platforms | `linux/amd64`, `linux/arm64`, `linux/arm/v7` (single multi-arch manifest list per lineage × version) |
| Image signing | [Cosign](https://docs.sigstore.dev/cosign/overview/) keyless (Sigstore Fulcio → Rekor, tag-pushes only) |
| Testing | `go test -race -cover`, Kagami's `go-face-testdata` models |
| Containers | Docker buildx multi-platform (QEMU emulation for arm) |
| CI/CD | GitHub Actions with per-lineage matrix |
| Static analysis | golangci-lint 2.11.4, hadolint 2.14.0 |
| Security | govulncheck 1.1.4, gosec 2.22.12, Trivy image scan |
| Dependency updates | Renovate (branch automerge, squash) + `dlib-poll` workflow for new dlib majors |

## Using as a builder image

Minimal template for a downstream `Dockerfile` that builds a CGo binary on top of a specific `go-face` lineage image:

```dockerfile
# Pin to a specific lineage + tag + digest. Pick the dlib major that matches
# the ABI contract your application needs — dlib20 is the current primary.
# Renovate can keep the digest fresh automatically via a docker-image manager.
ARG BUILDER_IMAGE="ghcr.io/andriykalashnykov/go-face/dlib20:0.1.4@sha256:<current-digest>"

FROM ${BUILDER_IMAGE} AS builder

# This image drops to USER 65534:65534 (nobody) at the end of its own
# Dockerfile for a safe non-root sandbox default. In a downstream builder
# stage you almost always need root — to write Go module / build caches,
# to apt-get install extra packages, etc. Reset it here; your runtime
# stage should drop back to a non-root numeric UID.
USER root

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .

# Static link a fully self-contained binary against libdlib.a from the
# underlying dlib-docker layer. LIBRARY_PATH=/usr/local/lib is inherited
# from dlib-docker so `-ldlib` resolves the static archive with no -L flag.
RUN CGO_ENABLED=1 go build \
        -trimpath -ldflags "-s -w -extldflags -static" \
        -tags "static netgo cgo static_build" \
        -o /out/my-app ./cmd/my-app

# Minimal runtime stage — non-root, apk upgrade for CVEs between base cuts.
FROM alpine:3.23.3 AS runtime
RUN apk --no-cache upgrade && adduser -u 10001 -S -D app
WORKDIR /app
COPY --from=builder /out/my-app .
USER 10001
CMD ["/app/my-app"]
```

For a full, end-to-end worked example — including a CI matrix that builds against both `dlib19` and `dlib20` in parallel, extracts per-platform binaries, and publishes them as signed GitHub Release assets — see [`AndriyKalashnykov/go-face-recognition`](https://github.com/AndriyKalashnykov/go-face-recognition).

## Quick Start

```bash
# Consume the library
go get github.com/AndriyKalashnykov/go-face

# Develop locally
make deps         # check Go is installed
make testdata     # clone dlib models + test images
make static-check # format + lint + vulncheck + gosec
make test         # run tests with coverage
```

> **Note:** go-face wraps dlib via CGo. Install dlib and libjpeg natively (see
> [dlib Installation](#dlib-installation)) before running `make test`, or run
> tests inside the pre-built `ghcr.io/andriykalashnykov/dlib-docker` image used
> by CI.

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| [GNU Make](https://www.gnu.org/software/make/) | 3.81+ | Build orchestration |
| [Git](https://git-scm.com/) | latest | Clone testdata and release tags |
| [Go](https://go.dev/dl/) | 1.26.2 | Go compiler and runtime (derived from `go.mod`) |
| [Docker](https://www.docker.com/) | latest | Container image builds and `act` runs |
| [dlib](http://dlib.net/compile.html) | ≥ 19.10 | Face detection/recognition C++ library |
| [golangci-lint](https://golangci-lint.run/) | 2.11.4 | Static analysis (auto-installed by `make deps-lint`) |
| [hadolint](https://github.com/hadolint/hadolint) | 2.14.0 | Dockerfile linting (auto-installed by `make deps-hadolint`) |
| [gosec](https://github.com/securego/gosec) | 2.22.12 | Go security scanner (auto-installed by `make deps-gosec`) |
| [govulncheck](https://pkg.go.dev/golang.org/x/vuln/cmd/govulncheck) | 1.1.4 | Go vulnerability scanner (auto-installed by `make deps-govulncheck`) |
| [act](https://github.com/nektos/act) | 0.2.87 | Run GitHub Actions locally (optional, auto-installed by `make deps-act`) |

Install Go and Docker first, then let `make` install the rest lazily as needed:

```bash
make deps
```

### Native dlib install (go get path only)

You only need this section if you're consuming go-face as a **Go library**
(`go get github.com/AndriyKalashnykov/go-face`) and want `go build` / `go test`
to link on your host without Docker. **Docker builder image consumers can skip
this entirely** — the `dlib-docker` layer at the bottom of the chain already
provides dlib + libjpeg + BLAS/LAPACK preinstalled.

**Ubuntu / Debian:**

```bash
sudo apt-get install libdlib-dev libblas-dev libatlas-base-dev liblapack-dev libjpeg-turbo8-dev
# On older Debian releases, libjpeg-turbo8-dev is named libjpeg62-turbo-dev
```

> ⚠️ **Version drift vs. the Docker chain.** Ubuntu's stock `libdlib-dev` on
> `noble` ships **dlib 19.24.0**, which is older than this project's
> `dlib-docker` chain (currently 19.24.9 and 20.0.1, built from source at
> pinned upstream tags). The ABI is compatible for go-face's API surface,
> but host-linked binaries will call into an older dlib than Docker-linked
> binaries. If your application cares about the exact dlib release it runs
> against (e.g. you depend on a specific face-landmark model or a CVE fix),
> use the Docker path or build dlib from source.

**macOS** (Homebrew, builds are `arm64` on Apple Silicon):

```bash
brew install dlib
```

**Other systems:** install dlib + libjpeg from your distribution's package
manager, or [compile dlib from source](http://dlib.net/compile.html). go-face
does not work against `libdlib18` or older. Windows/MSYS2 is no longer
documented here — we recommend
[WSL2](https://learn.microsoft.com/en-us/windows/wsl/install) with Ubuntu and
the instructions above. If you need platform coverage we don't provide, the
same native install instructions live in
[upstream Kagami/go-face](https://github.com/Kagami/go-face#requirements).

## Available Make Targets

Run `make help` to see all available targets.

### Dependencies

| Target | Description |
|--------|-------------|
| `make deps` | Check Go is installed |
| `make deps-docker` | Check Docker is installed |
| `make deps-lint` | Install golangci-lint for static analysis |
| `make deps-hadolint` | Install hadolint for Dockerfile linting |
| `make deps-gosec` | Install gosec security scanner |
| `make deps-govulncheck` | Install govulncheck vulnerability scanner |
| `make deps-act` | Install act for local CI |

### Build & Run

| Target | Description |
|--------|-------------|
| `make build` | Build the Go project |
| `make run` | Run the example |
| `make testdata` | Get test data |
| `make clean` | Remove build artifacts |
| `make format` | Format Go code |

### Code Quality

| Target | Description |
|--------|-------------|
| `make format-check` | Verify Go code is formatted |
| `make lint` | Run golangci-lint and hadolint |
| `make vulncheck` | Run govulncheck vulnerability scanner |
| `make sec` | Run gosec security scanner |
| `make static-check` | Run composite static-analysis gate (format, lint, vuln, sec) |
| `make test` | Run tests with coverage |

### CI

| Target | Description |
|--------|-------------|
| `make ci` | Run full local CI pipeline |
| `make ci-run` | Run GitHub Actions workflow locally using act |
| `make ci-run-tag` | Run the tag-gated docker job under act (simulates tag push) |

### Docker

| Target | Description |
|--------|-------------|
| `make image-bootstrap` | Bootstrap Docker buildx multi-platform builder |
| `make image-build` | Build Docker image (amd64) |
| `make image-run` | Run Docker image interactively (amd64) |
| `make image-stop` | Stop any running `go-face` container |

### Utilities

| Target | Description |
|--------|-------------|
| `make help` | List available tasks |
| `make update` | Update dependency packages to latest versions |
| `make release` | Create and push a new tag |
| `make tag-delete` | Delete a git tag locally and remotely (`TAG=vN.N.N`) |
| `make renovate-bootstrap` | Install nvm and node for Renovate |
| `make renovate-validate` | Validate Renovate configuration |

## CI/CD

GitHub Actions runs on every push to `main`, tags (`v*`), and pull requests.
The workflow is also `workflow_call`-able for downstream reuse.

### Per-lineage matrix

go-face publishes one container image **per supported dlib-docker major
version**. The set of supported lineages is declared in
[`.dlib-versions.json`](./.dlib-versions.json) and fans out across the entire
CI pipeline — `static-check`, `build`, `test`, and `docker` each run once per
active entry, in parallel. A single tag push produces one published image per
lineage, and each lineage ends up in its own GHCR sub-package:

| Lineage | dlib-docker base tag | Published image |
|---------|----------------------|-----------------|
| `dlib19` | `ghcr.io/andriykalashnykov/dlib-docker:19.24.9` | [`ghcr.io/andriykalashnykov/go-face/dlib19`](https://github.com/AndriyKalashnykov/go-face/pkgs/container/go-face%2Fdlib19) |
| `dlib20` | `ghcr.io/andriykalashnykov/dlib-docker:20.0.1` | [`ghcr.io/andriykalashnykov/go-face/dlib20`](https://github.com/AndriyKalashnykov/go-face/pkgs/container/go-face%2Fdlib20) |

Each image is a multi-arch manifest list covering `linux/amd64`, `linux/arm64`,
and `linux/arm/v7`. The exact `dlib-docker` digest each lineage is pinned
against is tracked in [`.dlib-versions.json`](./.dlib-versions.json) and kept
fresh by Renovate (digest updates within an existing major) or the
[`dlib-poll` workflow](#automated-releases) (when a new dlib major appears
upstream).

Adding a new lineage is a one-line change to `.dlib-versions.json` — or you
can let the automation do it (see "Automated releases" below).

### Jobs

| Job | Triggers | Description |
|-----|----------|-------------|
| `setup` | push, PR, tags | Reads `.dlib-versions.json` and emits the matrix used by downstream jobs |
| `static-check` | push, PR, tags | `make static-check` (format-check, lint, vulncheck, sec), once per active dlib lineage |
| `build` | push, PR, tags | `make build`, once per active dlib lineage |
| `test` | push, PR, tags | `make test`, once per active dlib lineage |
| `docker` | push, PR, tags | Hardened image pipeline, once per active dlib lineage. Builds and cosign-signs on tag pushes; validation-only on non-tag pushes |
| `ci-pass` | always | Aggregator gate. Fails if **any** matrix expansion of **any** job failed or was cancelled |

A separate [cleanup workflow](.github/workflows/cleanup-runs.yml) removes old
workflow runs and caches weekly.

The `docker` job authenticates to GHCR using the built-in `GITHUB_TOKEN` — no
additional secrets are required for publishing. [Renovate](https://docs.renovatebot.com/)
keeps dependencies (including `dlib-docker` tag+digest pairs in
`.dlib-versions.json`) up to date with platform automerge enabled.

### Pre-push image hardening

The `docker` job runs on **every push** (not just tags) so multi-arch build
regressions and cosign-installer breakage surface on the commit that introduced
them. Login, push, and cosign signing are gated at step-level to tag pushes.
Every matrix entry goes through the same five gates — one bad lineage does not
block the others (`fail-fast: false`), but `ci-pass` still fails the run so no
image is published partially:

| # | Gate | Catches | Tool |
|---|------|---------|------|
| 1 | Build local single-arch image | Build regressions on the runner architecture — including CGo link failures, missing apt packages in the `dlib-docker` base, and Go version drift | `docker/build-push-action` with `load: true` |
| 2 | **Trivy image scan** (`CRITICAL`/`HIGH` blocking) | CVEs in the `dlib-docker` base image, OS packages, and build layers — things a source-tree scan cannot see because they live inside the built image | `aquasecurity/trivy-action` with `image-ref:` |
| 3 | **Smoke test** | Image boots, Go toolchain runs (`/usr/local/go/bin/go version`), source files (`/app/face.go`, `/app/facerec.cc`) and `/app/testdata/` are present — regression guard for accidental `.dockerignore` filtering or `COPY` path drift | `docker run` + invariant probe |
| 4 | **Multi-arch build + conditional push** | Cross-compile regressions for `linux/amd64`, `linux/arm64`, **and `linux/arm/v7`** — all three published as a single manifest list on tag push. `linux/arm/v7` was added 2026-04-11 to match downstream `go-face-recognition`'s platform matrix; see commit `7f2d4ac` for the pre-existing gap that was hidden by an earlier libdlib.a blocker. | `docker/build-push-action` with `push: ${{ startsWith(github.ref, 'refs/tags/') }}` |
| 5 | **Cosign keyless OIDC signing** (tag push only) | Tampered or unsigned images — every published `tag@digest` gets a Sigstore signature keyed to the GitHub Actions workflow's OIDC identity. No pre-shared key, no long-lived secrets. | `sigstore/cosign-installer` + `cosign sign --yes <tag>@<digest>` |

Buildkit in-manifest attestations (`provenance` + `sbom`) are deliberately
**disabled** so the OCI image index stays free of `unknown/unknown` platform
entries — that lets the GHCR Packages UI render the "OS / Arch" tab for the
multi-arch manifest. Cosign keyless signing still provides the Sigstore
signature for supply-chain verification. The base image name and digest are
recorded in each published manifest as
`org.opencontainers.image.base.name` and `org.opencontainers.image.base.digest`
OCI labels so consumers can see exactly which `dlib-docker` build produced
a given image.

Verify a published image's signature:

```bash
cosign verify ghcr.io/andriykalashnykov/go-face/dlib19:<tag> \
  --certificate-identity-regexp 'https://github\.com/AndriyKalashnykov/go-face/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Replace `dlib19` with whichever lineage you are pulling.

### Automated releases

New dlib-docker releases flow into new go-face releases automatically. There
are three workflows involved:

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| [`dlib-poll.yml`](.github/workflows/dlib-poll.yml) | Daily cron + `workflow_dispatch` | Queries the `dlib-docker` GHCR package, compares the set of observed major versions against `.dlib-versions.json`, and opens an auto-merging PR that adds any new majors. |
| `renovate` (SaaS) | On its own schedule | Bumps the `dlib_docker_tag` + `dlib_docker_digest` pair of **existing** lineages when `dlib-docker` repushes an existing tag with a new digest or ships a new patch within an existing major line. |
| [`auto-release.yml`](.github/workflows/auto-release.yml) | `push` to `main` touching `.dlib-versions.json` | Bumps the **patch** in `version.txt`, commits as `Cut vX.Y.Z release`, creates the matching git tag, and pushes both. The tag push retriggers `ci.yml`, which matrix-builds and cosign-signs every active lineage. |

Together:

1. `dlib-docker` ships a new version →
2. Renovate (for digest bumps) or `dlib-poll` (for new majors) opens a PR →
3. CI runs against the proposed update; auto-merge squashes it into `main` on green →
4. `auto-release` bumps `version.txt` patch, cuts the next tag, pushes →
5. `ci.yml` fans out across every active lineage, publishes, and cosign-signs →
6. Consumers pulling `ghcr.io/andriykalashnykov/go-face/dlib19:<latest>` get the new build.

Minor and major version bumps stay **manual** — when you change go-face's own
code (not just the base image), use `make release` to cut a tag directly.

#### Required secret: `RELEASE_PAT`

`auto-release.yml` needs a Personal Access Token to push tags, because tags
pushed with `GITHUB_TOKEN` deliberately do not trigger downstream workflows.
Without `RELEASE_PAT`, the new tag would land in the repo but `ci.yml` would
not fire against it.

Create a **classic PAT** with these scopes:

- `contents: write` — push commits and tags
- `workflow` — allows the token to push changes under `.github/workflows/`
  (not strictly required by `auto-release.yml` today, but future-proofs
  against workflow edits needing to ship alongside a release)

Add it at **Settings → Secrets and variables → Actions → New repository
secret** with the name `RELEASE_PAT`. The workflow fails fast with a clear
error message if the secret is missing.

> A fine-grained PAT scoped to this single repo also works, with the same
> permissions: **Contents: Read and write** and **Workflows: Read and write**.
> A GitHub App installation token is the production-grade alternative if you
> want to avoid PAT rotation, but requires more setup.

## Models

Currently `shape_predictor_5_face_landmarks.dat`, `mmod_human_face_detector.dat` and
`dlib_face_recognition_resnet_model_v1.dat` are required. You may download them
from [go-face-testdata](https://github.com/Kagami/go-face-testdata) repo:

```bash
make testdata
```

Or manually:

```bash
mkdir testdata
cd testdata
wget https://github.com/Kagami/go-face-testdata/raw/master/models/shape_predictor_5_face_landmarks.dat
wget https://github.com/Kagami/go-face-testdata/raw/master/models/dlib_face_recognition_resnet_model_v1.dat
wget https://github.com/Kagami/go-face-testdata/raw/master/models/mmod_human_face_detector.dat
```

## Usage

To use go-face in your Go code:

```go
import "github.com/AndriyKalashnykov/go-face"
```

To install go-face in your `$GOPATH`:

```bash
go get github.com/AndriyKalashnykov/go-face
```

For further details see [pkg.go.dev documentation](https://pkg.go.dev/github.com/AndriyKalashnykov/go-face).

## Example

```go
package main

import (
	"fmt"
	"log"
	"path/filepath"

	"github.com/AndriyKalashnykov/go-face"
)

// Path to directory with models and test images. Here it's assumed it
// points to the <https://github.com/Kagami/go-face-testdata> clone.
const dataDir = "testdata"

var (
	modelsDir = filepath.Join(dataDir, "models")
	imagesDir = filepath.Join(dataDir, "images")
)

// This example shows the basic usage of the package: create an
// recognizer, recognize faces, classify them using few known ones.
func main() {
	// Init the recognizer.
	rec, err := face.NewRecognizer(modelsDir)
	if err != nil {
		log.Fatalf("Can't init face recognizer: %v", err)
	}
	// Free the resources when you're finished.
	defer rec.Close()

	// Test image with 10 faces.
	testImagePristin := filepath.Join(imagesDir, "pristin.jpg")
	// Recognize faces on that image.
	faces, err := rec.RecognizeFile(testImagePristin)
	if err != nil {
		log.Fatalf("Can't recognize: %v", err)
	}
	if len(faces) != 10 {
		log.Fatalf("Wrong number of faces")
	}

	// Fill known samples. In the real world you would use a lot of images
	// for each person to get better classification results but in our
	// example we just get them from one big image.
	var samples []face.Descriptor
	var cats []int32
	for i, f := range faces {
		samples = append(samples, f.Descriptor)
		// Each face is unique on that image so goes to its own category.
		cats = append(cats, int32(i))
	}
	// Name the categories, i.e. people on the image.
	labels := []string{
		"Sungyeon", "Yehana", "Roa", "Eunwoo", "Xiyeon",
		"Kyulkyung", "Nayoung", "Rena", "Kyla", "Yuha",
	}
	// Pass samples to the recognizer.
	rec.SetSamples(samples, cats)

	// Now let's try to classify some not yet known image.
	testImageNayoung := filepath.Join(imagesDir, "nayoung.jpg")
	nayoungFace, err := rec.RecognizeSingleFile(testImageNayoung)
	if err != nil {
		log.Fatalf("Can't recognize: %v", err)
	}
	if nayoungFace == nil {
		log.Fatalf("Not a single face on the image")
	}
	catID := rec.Classify(nayoungFace.Descriptor)
	if catID < 0 {
		log.Fatalf("Can't classify")
	}
	// Finally print the classified label. It should be "Nayoung".
	fmt.Println(labels[catID])
}
```

Run with:

```bash
mkdir -p ~/go && cd ~/go  # Or cd to your $GOPATH
mkdir -p src/go-face-example && cd src/go-face-example
git clone https://github.com/Kagami/go-face-testdata testdata
# Save the example above to main.go
go mod init go-face-example
go get github.com/AndriyKalashnykov/go-face
go run main.go
```

## FAQ

### How to improve recognition accuracy

There are few suggestions:

* Try CNN recognizing
* Try different tolerance values of `ClassifyThreshold`
* Try different size/padding/jittering values of `NewRecognizerWithConfig`
* Provide more samples of each category to `SetSamples` if possible
* Implement better classify heuristics (see [classify.cc](classify.cc))
* [Train](https://blog.dlib.net/2017/02/high-quality-face-recognition-with-deep.html) network (`dlib_face_recognition_resnet_model_v1.dat`) on your own test data

## License

go-face is licensed under [CC0](LICENSE).
