projectname?=go-face

CURRENTTAG:=$(shell git describe --tags --abbrev=0)
NEWTAG ?= $(shell bash -c 'read -p "Please provide a new tag (currnet tag - ${CURRENTTAG}): " newtag; echo $$newtag')

default: help

.PHONY: help
help: ## list makefile targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-10s\033[0m %s\n", $$1, $$2}'

.PHONY: testdata
testdata: ## get test data
	git clone https://github.com/Kagami/go-face-testdata testdatas

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

.PHONY: bdi
bdi: ## build dblib image
	docker buildx build --platform linux/amd64 --load -f Dockerfile -t dlib-dev .

.PHONY: run
run:
	docker run -it --name dlib-dev dlib-dev:latest bash
