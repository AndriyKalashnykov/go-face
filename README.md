[![CI](https://github.com/AndriyKalashnykov/go-face/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/AndriyKalashnykov/go-face/actions/workflows/ci.yml)
[![Hits](https://hits.sh/github.com/AndriyKalashnykov/go-face.svg?view=today-total&style=plastic)](https://hits.sh/github.com/AndriyKalashnykov/go-face/)
[![License: CC0](https://img.shields.io/badge/License-CC0-brightgreen.svg)](https://creativecommons.org/publicdomain/zero/1.0/)
[![Renovate enabled](https://img.shields.io/badge/renovate-enabled-brightgreen.svg)](https://app.renovatebot.com/dashboard#github/AndriyKalashnykov/go-face)

# go-face

go-face implements face recognition for Go using [dlib](http://dlib.net), a
popular machine learning toolkit. Read
[Face recognition with Go](https://hackernoon.com/face-recognition-with-go-676a555b8a7e)
article for some background details if you're new to
[FaceNet](https://arxiv.org/abs/1503.03832) concept.

## Quick Start

```bash
make deps      # check required tools (Go, Docker, golangci-lint)
make testdata  # download test models and images
make build     # build the project
make test      # run tests with coverage
make run       # run the example
```

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| [GNU Make](https://www.gnu.org/software/make/) | 3.81+ | Build orchestration |
| [Go](https://go.dev/dl/) | See `go.mod` | Go compiler and runtime |
| [Docker](https://www.docker.com/) | latest | Container image builds |
| [dlib](http://dlib.net/compile.html) | >= 19.10 | Face detection/recognition C++ library |
| [golangci-lint](https://golangci-lint.run/) | 2.1.6 | Static analysis (auto-installed by `make deps`) |
| [act](https://github.com/nektos/act) | 0.2.86 | Run GitHub Actions locally (optional, auto-installed by `make deps-act`) |

Install all required dependencies:

```bash
make deps
```

### dlib Installation

#### Ubuntu 18.10+, Debian

```bash
# Ubuntu
sudo apt-get install libdlib-dev libblas-dev libatlas-base-dev liblapack-dev libjpeg-turbo8-dev
# Debian
sudo apt-get install libdlib-dev libblas-dev libatlas-base-dev liblapack-dev libjpeg62-turbo-dev
```

#### macOS

Make sure you have [Homebrew](https://brew.sh) installed.

```bash
brew install dlib
```

#### Windows

Make sure you have [MSYS2](https://www.msys2.org) installed.

1. Run `MSYS2 MSYS` shell from Start menu
2. Run `pacman -Syu` and if it asks you to close the shell do that
3. Run `pacman -Syu` again
4. Run `pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-dlib`
5.
   1. If you already have Go and Git installed and available in PATH uncomment
      `set MSYS2_PATH_TYPE=inherit` line in `msys2_shell.cmd` located in MSYS2
      installation folder
   2. Otherwise run `pacman -S mingw-w64-x86_64-go git`
6. Run `MSYS2 MinGW 64-bit` shell from Start menu to compile and use go-face

#### Other systems

Try to install dlib/libjpeg with package manager of your distribution or
[compile from sources](http://dlib.net/compile.html). Note that go-face won't
work with old packages of dlib such as libdlib18. Alternatively create issue
with the name of your system and someone might help you with the installation
process.

## Available Make Targets

Run `make help` to see all available targets.

### Build & Run

| Target | Description |
|--------|-------------|
| `make build` | Build the Go project |
| `make run` | Run the example |
| `make testdata` | Get test data |
| `make clean` | Remove build artifacts |

### Code Quality

| Target | Description |
|--------|-------------|
| `make lint` | Run static analysis and Dockerfile linting |
| `make test` | Run tests with coverage |

### CI

| Target | Description |
|--------|-------------|
| `make ci` | Full local CI pipeline (lint, test, build) |
| `make ci-run` | Run GitHub Actions workflow locally via [act](https://github.com/nektos/act) |

### Docker

| Target | Description |
|--------|-------------|
| `make image-build` | Build Docker image (amd64) |
| `make image-run` | Run Docker image interactively (amd64) |
| `make bootstrap` | Bootstrap Docker buildx multi-platform builder |

### Utilities

| Target | Description |
|--------|-------------|
| `make update` | Update dependency packages to latest versions |
| `make release` | Create and push a new tag |
| `make tag-delete` | Delete a git tag locally and remotely |
| `make renovate-validate` | Validate Renovate configuration |

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

To install go-face in your $GOPATH:

```bash
go get github.com/AndriyKalashnykov/go-face
```

For further details see [GoDoc documentation](https://godoc.org/github.com/AndriyKalashnykov/go-face).

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
edit main.go  # Paste example code
go get && go run main.go
```

## CI/CD

GitHub Actions runs on every push to `main`, tags `v*`, and pull requests.

| Job | Triggers | Steps |
|-----|----------|-------|
| **ci** | push, PR, tags | Lint, Test, Build |
| **release-docker-images** | tags only | Build and push multi-arch Docker images to GHCR |

A separate [cleanup workflow](.github/workflows/cleanup-runs.yml) removes old workflow runs weekly.

[Renovate](https://docs.renovatebot.com/) keeps dependencies up to date with platform automerge enabled.

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
