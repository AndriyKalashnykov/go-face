.DEFAULT_GOAL := help

projectname    ?= go-face
CURRENTTAG     := $(shell git describe --tags --abbrev=0 2>/dev/null || echo "dev")

#help: @ List available tasks
help:
	@echo "Usage: make COMMAND"
	@echo "Commands :"
	@grep -E '[a-zA-Z\.\-]+:.*?@ .*$$' $(MAKEFILE_LIST)| tr -d '#' | awk 'BEGIN {FS = ":.*?@ "}; {printf "\033[32m%-25s\033[0m - %s\n", $$1, $$2}'

#deps: @ Install required tools (idempotent)
deps:
	@command -v go >/dev/null 2>&1 || { echo "Error: Go required. See https://go.dev/doc/install"; exit 1; }
	@command -v docker >/dev/null 2>&1 || { echo "Error: Docker required. See https://docs.docker.com/get-docker/"; exit 1; }

#build: @ Build the Go project
build: deps
	@go build -v ./...

#lint: @ Run static analysis
lint: deps
	@command -v golangci-lint >/dev/null 2>&1 || { echo "Error: golangci-lint required. See https://golangci-lint.run/welcome/install/"; exit 1; }
	@golangci-lint run ./...

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
	@go test --cover -parallel=1 -v -coverprofile=coverage.out -v ./...
	@go tool cover -func=coverage.out | sort -rnk3

#update: @ Update dependency packages to latest versions
update: deps
	@go get -u ./...
	@go mod tidy

#ci: @ Run full local CI pipeline
ci: deps build test
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
bootstrap:
	@docker buildx create --use --platform=linux/arm64,linux/amd64,linux/arm/v7 --name multi-platform-builder

#image-build: @ Build Docker image (amd64)
image-build:
	@docker buildx build --load --platform linux/amd64 -f Dockerfile -t anriykalashnykov/go-face:amd64 .

#image-run: @ Run Docker image interactively (amd64)
image-run:
	@docker run --platform linux/amd64 --rm -it anriykalashnykov/go-face:amd64 /bin/bash

#tag-delete: @ Delete a git tag locally and remotely
tag-delete:
	@rm -f version.txt
	@git push --delete origin v0.0.3
	@git tag --delete v0.0.3

#bootstrap-renovate: @ Install nvm and npm for renovate
bootstrap-renovate:
	@if [ ! -d "$$HOME/.nvm" ]; then \
		echo "Installing nvm..."; \
		curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash; \
		export NVM_DIR="$$HOME/.nvm"; \
		[ -s "$$NVM_DIR/nvm.sh" ] && . "$$NVM_DIR/nvm.sh"; \
		nvm install --lts; \
		nvm use --lts; \
	else \
		echo "nvm already installed"; \
		export NVM_DIR="$$HOME/.nvm"; \
		[ -s "$$NVM_DIR/nvm.sh" ] && . "$$NVM_DIR/nvm.sh"; \
	fi

#validate-renovate: @ Validate renovate configuration
validate-renovate: bootstrap-renovate
	@npx -p renovate -c 'renovate-config-validator'

.PHONY: help deps build lint run testdata test update ci \
	release bootstrap image-build image-run tag-delete \
	bootstrap-renovate validate-renovate
