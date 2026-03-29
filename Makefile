.DEFAULT_GOAL := help

APP_NAME       := go-face
CURRENTTAG     := $(shell git describe --tags --abbrev=0 2>/dev/null || echo "dev")

# === Tool Versions (pinned) ===
GOLANGCI_VERSION := 2.1.6
HADOLINT_VERSION := 2.12.0
ACT_VERSION      := 0.2.86
NVM_VERSION      := 0.40.4

#help: @ List available tasks
help:
	@echo "Usage: make COMMAND"
	@echo "Commands :"
	@grep -E '[a-zA-Z\.\-]+:.*?@ .*$$' $(MAKEFILE_LIST)| tr -d '#' | awk 'BEGIN {FS = ":.*?@ "}; {printf "\033[32m%-25s\033[0m - %s\n", $$1, $$2}'

#deps-go: @ Check Go is installed
deps-go:
	@command -v go >/dev/null 2>&1 || { echo "Error: Go required. See https://go.dev/doc/install"; exit 1; }

#deps-lint: @ Install golangci-lint for static analysis
deps-lint: deps-go
	@command -v golangci-lint >/dev/null 2>&1 || { echo "Installing golangci-lint v$(GOLANGCI_VERSION)..."; \
		curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/HEAD/install.sh | sh -s -- -b $$(go env GOPATH)/bin v$(GOLANGCI_VERSION); }

#deps: @ Check required tools (Go + Docker)
deps: deps-go
	@command -v docker >/dev/null 2>&1 || { echo "Error: Docker required. See https://docs.docker.com/get-docker/"; exit 1; }

#clean: @ Remove build artifacts
clean:
	@rm -f coverage.out
	@go clean ./...

#build: @ Build the Go project
build: deps-go
	@go build -v ./...

#lint: @ Run static analysis and Dockerfile linting
lint: deps-lint deps-hadolint
	@golangci-lint run ./...
	@hadolint Dockerfile

#run: @ Run the example
run: deps-go testdata
	@go run ./...

#testdata: @ Get test data
testdata:
	@if [ ! -d testdata ]; then \
		git clone https://github.com/Kagami/go-face-testdata testdata; \
	fi

#test: @ Run tests with coverage
test: deps-go
	@go test --cover -parallel=1 -v -coverprofile=coverage.out -v ./...
	@go tool cover -func=coverage.out | sort -rnk3

#update: @ Update dependency packages to latest versions
update: deps-go
	@go get -u ./...
	@go mod tidy

#ci: @ Run full local CI pipeline
ci: deps lint test build
	@echo "Local CI pipeline passed."

#release: @ Create and push a new tag
release:
	@bash -c 'read -p "New tag (current: $(CURRENTTAG)): " newtag && \
		echo "$$newtag" | grep -qE "^v[0-9]+\.[0-9]+\.[0-9]+$$" || { echo "Error: Tag must match vN.N.N"; exit 1; } && \
		echo -n "Create and push $$newtag? [y/N] " && read ans && [ "$${ans:-N}" = y ] && \
		echo $$newtag > ./version.txt && \
		git add -A && \
		git commit -a -s -m "Cut $$newtag release" && \
		git tag $$newtag && \
		git push origin $$newtag && \
		git push && \
		echo "Done."'

#bootstrap: @ Bootstrap Docker buildx multi-platform builder
bootstrap: deps
	@docker buildx create --use --platform=linux/arm64,linux/amd64,linux/arm/v7 --name multi-platform-builder

#image-build: @ Build Docker image (amd64)
image-build: build
	@docker buildx build --load --platform linux/amd64 -f Dockerfile -t anriykalashnykov/go-face:amd64 .

#image-run: @ Run Docker image interactively (amd64)
image-run: deps
	@docker run --platform linux/amd64 --rm -it anriykalashnykov/go-face:amd64 /bin/bash

#tag-delete: @ Delete a git tag locally and remotely
tag-delete:
	@rm -f version.txt
	@git push --delete origin v0.0.3
	@git tag --delete v0.0.3

#deps-hadolint: @ Install hadolint for Dockerfile linting
deps-hadolint:
	@command -v hadolint >/dev/null 2>&1 || { echo "Installing hadolint $(HADOLINT_VERSION)..."; \
		curl -sSfL -o /tmp/hadolint https://github.com/hadolint/hadolint/releases/download/v$(HADOLINT_VERSION)/hadolint-Linux-x86_64 && \
		install -m 755 /tmp/hadolint /usr/local/bin/hadolint && \
		rm -f /tmp/hadolint; \
	}

#deps-act: @ Install act for local CI
deps-act: deps
	@command -v act >/dev/null 2>&1 || { echo "Installing act $(ACT_VERSION)..."; \
		curl -sSfL https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash -s -- -b /usr/local/bin v$(ACT_VERSION); \
	}

#ci-run: @ Run GitHub Actions workflow locally using act
ci-run: deps-act
	@act push --container-architecture linux/amd64 \
		--artifact-server-path /tmp/act-artifacts

#renovate-bootstrap: @ Install nvm and npm for Renovate
renovate-bootstrap:
	@command -v node >/dev/null 2>&1 || { \
		echo "Installing nvm $(NVM_VERSION)..."; \
		curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v$(NVM_VERSION)/install.sh | bash; \
		export NVM_DIR="$$HOME/.nvm"; \
		[ -s "$$NVM_DIR/nvm.sh" ] && . "$$NVM_DIR/nvm.sh"; \
		nvm install --lts; \
	}

#renovate-validate: @ Validate Renovate configuration
renovate-validate: renovate-bootstrap
	@npx --yes renovate --platform=local

.PHONY: help deps-go deps-lint deps clean build lint run testdata test update ci \
	release bootstrap image-build image-run tag-delete \
	deps-hadolint deps-act ci-run \
	renovate-bootstrap renovate-validate
