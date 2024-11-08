projectname?=go-face

CURRENTTAG:=$(shell git describe --tags --abbrev=0)
NEWTAG ?= $(shell bash -c 'read -p "Please provide a new tag (currnet tag - ${CURRENTTAG}): " newtag; echo $$newtag')

default: help

.PHONY: help
help: ## list makefile targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-10s\033[0m %s\n", $$1, $$2}'

.PHONY: testdata
testdata: ## get test data
	git clone https://github.com/Kagami/go-face-testdata testdata

.PHONY: test
test: ## run tests
	go test --cover -parallel=1 -v -coverprofile=coverage.out -v ./...
	go tool cover -func=coverage.out | sort -rnk3

.PHONY: update
update: ## update dependency packages to latest versions
	@go get -u ./...; go mod tidy

.PHONY: release
release: ## create and push a new tag
	$(eval NT=$(NEWTAG))
	@echo -n "Are you sure to create and push ${NT} tag? [y/N] " && read ans && [ $${ans:-N} = y ]
	@echo ${NT} > ./version.txt
	@git add -A
	@git commit -a -s -m "Cut ${NT} release"
	@git tag ${NT}
	@git push origin ${NT}
	@git push
	@echo "Done."

.PHONY: bootstrap
bootstrap: ## bootstrap build docker image
	docker buildx create --use --platform=linux/arm64,linux/amd64 --name multi-platform-builder

.PHONY: bdid
bdid: ## build debian docker image
	docker buildx build -f Dockerfile -t anriykalashnykov/go-face-debian:latest .

.PHONY: rdid
rdid: ## run debian docker image
	docker run --rm -it anriykalashnykov/go-face-debian:latest /bin/bash
#	docker run --rm -v $PWD:/app -w /app -it anriykalashnykov/go-face:latest /bin/bash

.PHONY: dt
dt: ## delete tag
	rm -f version.txt
	git push --delete origin v0.0.1
	git tag --delete v0.0.1
