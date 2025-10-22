projectname?=go-face

CURRENTTAG:=$(shell git describe --tags --abbrev=0)
NEWTAG ?= $(shell bash -c 'read -p "Please provide a new tag (currnet tag - ${CURRENTTAG}): " newtag; echo $$newtag')

default: help

help: ## list makefile targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-10s\033[0m %s\n", $$1, $$2}'

testdata: ## get test data
	git clone https://github.com/Kagami/go-face-testdata testdata

test: ## run tests
	go test --cover -parallel=1 -v -coverprofile=coverage.out -v ./...
	go tool cover -func=coverage.out | sort -rnk3

update: ## update dependency packages to latest versions
	@go get -u ./...; go mod tidy

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

bootstrap: ## bootstrap build docker image
	docker buildx create --use --platform=linux/arm64,linux/amd64,linux/arm/v7 --name multi-platform-builder

bdid: ## build debian docker image
	#docker buildx use multi-platform-builder
	docker buildx build --load --platform linux/amd64 -f Dockerfile -t anriykalashnykov/go-face:amd64 .
	docker buildx build --load --platform linux/arm/v7 -f Dockerfile -t anriykalashnykov/go-face:armv7 .
	docker buildx build --load --platform linux/arm64 -f Dockerfile -t anriykalashnykov/go-face:arm64 .
#	docker buildx build --load --platform linux/arm64 -f Dockerfile --build-arg BUILDER_IMAGE=ghcr.io/andriykalashnykov/dlib-docker:v19.24.4 --build-arg GO_VER=1.25.3 -t ghcr.io/andriykalashnykov/go-face:v0.0.2 -t ghcr.io/andriykalashnykov/go-face:latest --push .
#	docker build --platform linux/arm64 -f Dockerfile --build-arg BUILDER_IMAGE=ghcr.io/andriykalashnykov/dlib-docker:v19.24.4 --build-arg GO_VER=1.25.3 -t ghcr.io/andriykalashnykov/go-face:v0.0.2 -t ghcr.io/andriykalashnykov/go-face:latest --push .


rdid: ## run debian docker image -v $PWD:/app -w /app
	docker run --platform linux/amd64 --rm -it anriykalashnykov/go-face:amd64 /bin/bash
	docker run  --platform linux/arm/v7 --rm -it anriykalashnykov/go-face:armv7 /bin/bash
#	docker run --platform linux/arm64 --rm -it anriykalashnykov/go-face:arm64 /bin/bash

dt: ## delete tag
	rm -f version.txt
	git push --delete origin v0.0.2
	git tag --delete v0.0.2
