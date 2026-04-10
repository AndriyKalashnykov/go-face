.DEFAULT_GOAL := help

APP_NAME       := go-face
CURRENTTAG     := $(shell git describe --tags --abbrev=0 2>/dev/null || echo "dev")

# Ensure user-writable tool install dirs (~/.local/bin, ~/go/bin) are on PATH
# for every recipe — needed inside the act runner container where these are
# not preconfigured. Exported so sub-shells inherit.
export PATH := $(HOME)/.local/bin:$(HOME)/go/bin:$(PATH)

# === Tool Versions (pinned) ===
# Go version derived from go.mod (single source of truth)
GO_VERSION          := $(shell grep -oP '^go \K[0-9.]+' go.mod 2>/dev/null || echo 1.26)

# renovate: datasource=github-releases depName=golangci/golangci-lint
GOLANGCI_VERSION    := 2.11.4
# renovate: datasource=github-releases depName=hadolint/hadolint
HADOLINT_VERSION    := 2.14.0
# renovate: datasource=github-releases depName=nektos/act
ACT_VERSION         := 0.2.87
# renovate: datasource=github-releases depName=nvm-sh/nvm
NVM_VERSION         := 0.40.4
# renovate: datasource=github-releases depName=securego/gosec
GOSEC_VERSION       := 2.22.12
# renovate: datasource=go depName=golang.org/x/vuln/cmd/govulncheck
GOVULNCHECK_VERSION := 1.1.4

# Node version (source of truth: .nvmrc)
NODE_VERSION        := $(shell cat .nvmrc 2>/dev/null || echo 24)

# Docker image for local build
DOCKER_IMAGE        := andriykalashnykov/$(APP_NAME)
DOCKER_TAG          := $(CURRENTTAG)

#help: @ List available tasks
help:
	@echo "Usage: make COMMAND"
	@echo "Commands :"
	@grep -E '[a-zA-Z\.\-]+:.*?@ .*$$' $(MAKEFILE_LIST)| tr -d '#' | awk 'BEGIN {FS = ":.*?@ "}; {printf "\033[32m%-25s\033[0m - %s\n", $$1, $$2}'

#deps: @ Check Go is installed
deps:
	@command -v go >/dev/null 2>&1 || { echo "Error: Go required. See https://go.dev/doc/install"; exit 1; }

#deps-docker: @ Check Docker is installed
deps-docker:
	@command -v docker >/dev/null 2>&1 || { echo "Error: Docker required. See https://docs.docker.com/get-docker/"; exit 1; }

#deps-lint: @ Install golangci-lint for static analysis
deps-lint: deps
	@command -v golangci-lint >/dev/null 2>&1 || { echo "Installing golangci-lint v$(GOLANGCI_VERSION)..."; \
		curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/HEAD/install.sh | sh -s -- -b $$(go env GOPATH)/bin v$(GOLANGCI_VERSION); }

#deps-hadolint: @ Install hadolint for Dockerfile linting
deps-hadolint:
	@command -v hadolint >/dev/null 2>&1 || { echo "Installing hadolint v$(HADOLINT_VERSION)..."; \
		mkdir -p $$HOME/.local/bin && \
		curl -sSfL -o $$HOME/.local/bin/hadolint https://github.com/hadolint/hadolint/releases/download/v$(HADOLINT_VERSION)/hadolint-Linux-x86_64 && \
		chmod 755 $$HOME/.local/bin/hadolint; }

#deps-gosec: @ Install gosec security scanner
deps-gosec: deps
	@command -v gosec >/dev/null 2>&1 || { echo "Installing gosec v$(GOSEC_VERSION)..."; \
		go install github.com/securego/gosec/v2/cmd/gosec@v$(GOSEC_VERSION); }

#deps-govulncheck: @ Install govulncheck vulnerability scanner
deps-govulncheck: deps
	@command -v govulncheck >/dev/null 2>&1 || { echo "Installing govulncheck v$(GOVULNCHECK_VERSION)..."; \
		go install golang.org/x/vuln/cmd/govulncheck@v$(GOVULNCHECK_VERSION); }

#deps-act: @ Install act for local CI
deps-act:
	@command -v act >/dev/null 2>&1 || { echo "Installing act v$(ACT_VERSION)..."; \
		mkdir -p $$HOME/.local/bin && \
		curl -sSfL https://raw.githubusercontent.com/nektos/act/master/install.sh | bash -s -- -b $$HOME/.local/bin v$(ACT_VERSION); }

#clean: @ Remove build artifacts
clean:
	@rm -f coverage.out
	@go clean ./...

#format: @ Format Go code
format: deps
	@gofmt -w .

#format-check: @ Verify Go code is formatted
format-check: deps
	@unformatted=$$(gofmt -l .); \
	if [ -n "$$unformatted" ]; then \
		echo "Error: the following files are not formatted:"; \
		echo "$$unformatted"; \
		echo "Run 'make format' to fix."; \
		exit 1; \
	fi

#build: @ Build the Go project
build: deps
	@go build -v ./...

#lint: @ Run golangci-lint and hadolint
lint: deps-lint deps-hadolint
	@golangci-lint run ./...
	@hadolint Dockerfile

#vulncheck: @ Run govulncheck vulnerability scanner
vulncheck: deps-govulncheck
	@govulncheck ./...

#sec: @ Run gosec security scanner
sec: deps-gosec
	@gosec -quiet ./...

#static-check: @ Run composite static-analysis gate (format, lint, vuln, sec)
static-check: format-check lint vulncheck sec
	@echo "Static check passed."

#run: @ Run the example
run: deps testdata
	@go run ./...

#testdata: @ Get test data
testdata:
	@if [ ! -d testdata ]; then \
		git clone https://github.com/Kagami/go-face-testdata testdata; \
	fi

#test: @ Run tests with coverage
test: deps
	@go test --cover -parallel=1 -v -coverprofile=coverage.out ./...
	@go tool cover -func=coverage.out | sort -rnk3

#update: @ Update dependency packages to latest versions
update: deps
	@go get -u ./...
	@go mod tidy

#ci: @ Run full local CI pipeline
ci: deps static-check test build
	@echo "Local CI pipeline passed."

#release: @ Create and push a new tag
release:
	@bash -c 'read -p "New tag (current: $(CURRENTTAG)): " newtag && \
		echo "$$newtag" | grep -qE "^v[0-9]+\.[0-9]+\.[0-9]+$$" || { echo "Error: Tag must match vN.N.N"; exit 1; } && \
		echo -n "Create and push $$newtag? [y/N] " && read ans && [ "$${ans:-N}" = y ] && \
		echo $$newtag > ./version.txt && \
		git add version.txt && \
		git commit -a -s -m "Cut $$newtag release" && \
		git tag $$newtag && \
		git push origin $$newtag && \
		git push && \
		echo "Done."'

#image-bootstrap: @ Bootstrap Docker buildx multi-platform builder
image-bootstrap: deps-docker
	@docker buildx create --use --platform=linux/arm64,linux/amd64 --name multi-platform-builder

#image-build: @ Build Docker image (amd64)
image-build: deps deps-docker build
	@docker buildx build --load --platform linux/amd64 -f Dockerfile -t $(DOCKER_IMAGE):$(DOCKER_TAG) .

#image-run: @ Run Docker image interactively (amd64)
image-run: deps-docker image-stop
	@docker run --platform linux/amd64 --rm -it --name $(APP_NAME) $(DOCKER_IMAGE):$(DOCKER_TAG) /bin/bash

#image-stop: @ Stop any running $(APP_NAME) container
image-stop: deps-docker
	@docker rm -f $(APP_NAME) 2>/dev/null || true

#tag-delete: @ Delete a git tag locally and remotely (TAG=vN.N.N)
tag-delete:
	@if [ -z "$(TAG)" ]; then echo "Error: TAG=vN.N.N is required (e.g. make tag-delete TAG=v0.0.3)"; exit 1; fi
	@echo "$(TAG)" | grep -qE "^v[0-9]+\.[0-9]+\.[0-9]+$$" || { echo "Error: TAG must match vN.N.N"; exit 1; }
	@bash -c 'echo -n "Delete tag $(TAG) locally and remotely? [y/N] " && read ans && [ "$${ans:-N}" = y ]' || exit 0
	@rm -f version.txt
	@git push --delete origin $(TAG) 2>/dev/null || true
	@git tag --delete $(TAG) 2>/dev/null || true

#ci-run: @ Run GitHub Actions workflow locally using act
ci-run: deps-act
	@act push --container-architecture linux/amd64 \
		--artifact-server-path /tmp/act-artifacts

#ci-run-tag: @ Run the tag-gated docker job under act (simulates tag push)
ci-run-tag: deps-act
	@docker container prune -f 2>/dev/null || true
	@TAG="$$(git describe --tags --abbrev=0 2>/dev/null || echo v0.0.0)"; \
		echo '{"ref":"refs/tags/'"$$TAG"'"}' > /tmp/act-tag-event.json
	@act push \
		--eventpath /tmp/act-tag-event.json \
		--container-architecture linux/amd64 \
		--artifact-server-path /tmp/act-artifacts || true
	@echo "Note: cosign signing will fail under act (no OIDC) — expected."

#renovate-bootstrap: @ Install nvm and node for Renovate
renovate-bootstrap:
	@command -v node >/dev/null 2>&1 || { \
		echo "Installing nvm v$(NVM_VERSION) and Node $(NODE_VERSION)..."; \
		curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v$(NVM_VERSION)/install.sh | bash; \
		export NVM_DIR="$$HOME/.nvm"; \
		[ -s "$$NVM_DIR/nvm.sh" ] && . "$$NVM_DIR/nvm.sh"; \
		nvm install $(NODE_VERSION); \
	}

#renovate-validate: @ Validate Renovate configuration
renovate-validate: renovate-bootstrap
	@npx --yes renovate --platform=local

.PHONY: help deps deps-docker deps-lint deps-hadolint deps-gosec deps-govulncheck deps-act \
	clean format format-check build lint vulncheck sec static-check \
	run testdata test update ci release \
	image-bootstrap image-build image-run image-stop tag-delete \
	ci-run ci-run-tag renovate-bootstrap renovate-validate
