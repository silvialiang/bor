# This Makefile is meant to be used by people that do not usually work
# with Go source code. If you know what GOPATH is then you probably
# don't need to bother with make.

.PHONY: geth android ios geth-cross evm all test clean docs
.PHONY: geth-linux geth-linux-386 geth-linux-amd64 geth-linux-mips64 geth-linux-mips64le
.PHONY: geth-linux-arm geth-linux-arm-5 geth-linux-arm-6 geth-linux-arm-7 geth-linux-arm64
.PHONY: geth-darwin geth-darwin-386 geth-darwin-amd64
.PHONY: geth-windows geth-windows-386 geth-windows-amd64

GO ?= latest
GOBIN = $(CURDIR)/build/bin
GORUN = env GO111MODULE=on go run
GOPATH = $(shell go env GOPATH)

GIT_COMMIT ?= $(shell git rev-list -1 HEAD)
GIT_BRANCH ?= $(shell git rev-parse --abbrev-ref HEAD)
GIT_TAG    ?= $(shell git describe --tags `git rev-list --tags="v*" --max-count=1`)

PACKAGE = github.com/ethereum/go-ethereum
GO_FLAGS += -buildvcs=false
GO_FLAGS += -ldflags "-X ${PACKAGE}/params.GitCommit=${GIT_COMMIT} -X ${PACKAGE}/params.GitBranch=${GIT_BRANCH} -X ${PACKAGE}/params.GitTag=${GIT_TAG}"

TESTALL = $$(go list ./... | grep -v go-ethereum/cmd/)
TESTE2E = ./tests/...
GOTEST = GODEBUG=cgocheck=0 go test $(GO_FLAGS) -p 1

bor:
	mkdir -p $(GOPATH)/bin/
	go build -o $(GOBIN)/bor ./cmd/cli/main.go

protoc:
	protoc --go_out=. --go-grpc_out=. ./internal/cli/server/proto/*.proto

geth:
	$(GORUN) build/ci.go install ./cmd/geth
	@echo "Done building."
	@echo "Run \"$(GOBIN)/geth\" to launch geth."

all:
	$(GORUN) build/ci.go install

android:
	$(GORUN) build/ci.go aar --local
	@echo "Done building."
	@echo "Import \"$(GOBIN)/geth.aar\" to use the library."
	@echo "Import \"$(GOBIN)/geth-sources.jar\" to add javadocs"
	@echo "For more info see https://stackoverflow.com/questions/20994336/android-studio-how-to-attach-javadoc"

ios:
	$(GORUN) build/ci.go xcode --local
	@echo "Done building."
	@echo "Import \"$(GOBIN)/Geth.framework\" to use the library."

test:
	$(GOTEST) --timeout 5m -shuffle=on -cover -coverprofile=cover.out $(TESTALL)

test-race:
	$(GOTEST) --timeout 15m -race -shuffle=on $(TESTALL)

test-integration:
	$(GOTEST) --timeout 30m -tags integration $(TESTE2E)

escape:
	cd $(path) && go test -gcflags "-m -m" -run none -bench=BenchmarkJumpdest* -benchmem -memprofile mem.out

lint:
	@./build/bin/golangci-lint run --config ./.golangci.yml

lintci-deps:
	rm -f ./build/bin/golangci-lint
	curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b ./build/bin v1.46.0

goimports:
	goimports -local "$(PACKAGE)" -w .

docs:
	$(GORUN) cmd/clidoc/main.go -d ./docs/cli

clean:
	env GO111MODULE=on go clean -cache
	rm -fr build/_workspace/pkg/ $(GOBIN)/*

# The devtools target installs tools required for 'go generate'.
# You need to put $GOBIN (or $GOPATH/bin) in your PATH to use 'go generate'.

devtools:
	# Notice! If you adding new binary - add it also to tests/deps/fake.go file
	$(GOBUILD) -o $(GOBIN)/stringer github.com/golang.org/x/tools/cmd/stringer
	$(GOBUILD) -o $(GOBIN)/go-bindata github.com/kevinburke/go-bindata/go-bindata
	$(GOBUILD) -o $(GOBIN)/codecgen github.com/ugorji/go/codec/codecgen
	$(GOBUILD) -o $(GOBIN)/abigen ./cmd/abigen
	$(GOBUILD) -o $(GOBIN)/mockgen github.com/golang/mock/mockgen
	$(GOBUILD) -o $(GOBIN)/protoc-gen-go github.com/golang/protobuf/protoc-gen-go
	PATH=$(GOBIN):$(PATH) go generate ./common
	PATH=$(GOBIN):$(PATH) go generate ./core/types
	PATH=$(GOBIN):$(PATH) go generate ./consensus/bor
	@type "solc" 2> /dev/null || echo 'Please install solc'
	@type "protoc" 2> /dev/null || echo 'Please install protoc'

# Cross Compilation Targets (xgo)
geth-cross: geth-linux geth-darwin geth-windows geth-android geth-ios
	@echo "Full cross compilation done:"
	@ls -ld $(GOBIN)/geth-*

geth-linux: geth-linux-386 geth-linux-amd64 geth-linux-arm geth-linux-mips64 geth-linux-mips64le
	@echo "Linux cross compilation done:"
	@ls -ld $(GOBIN)/geth-linux-*

geth-linux-386:
	$(GORUN) build/ci.go xgo -- --go=$(GO) --targets=linux/386 -v ./cmd/geth
	@echo "Linux 386 cross compilation done:"
	@ls -ld $(GOBIN)/geth-linux-* | grep 386

geth-linux-amd64:
	$(GORUN) build/ci.go xgo -- --go=$(GO) --targets=linux/amd64 -v ./cmd/geth
	@echo "Linux amd64 cross compilation done:"
	@ls -ld $(GOBIN)/geth-linux-* | grep amd64

geth-linux-arm: geth-linux-arm-5 geth-linux-arm-6 geth-linux-arm-7 geth-linux-arm64
	@echo "Linux ARM cross compilation done:"
	@ls -ld $(GOBIN)/geth-linux-* | grep arm

geth-linux-arm-5:
	$(GORUN) build/ci.go xgo -- --go=$(GO) --targets=linux/arm-5 -v ./cmd/geth
	@echo "Linux ARMv5 cross compilation done:"
	@ls -ld $(GOBIN)/geth-linux-* | grep arm-5

geth-linux-arm-6:
	$(GORUN) build/ci.go xgo -- --go=$(GO) --targets=linux/arm-6 -v ./cmd/geth
	@echo "Linux ARMv6 cross compilation done:"
	@ls -ld $(GOBIN)/geth-linux-* | grep arm-6

geth-linux-arm-7:
	$(GORUN) build/ci.go xgo -- --go=$(GO) --targets=linux/arm-7 -v ./cmd/geth
	@echo "Linux ARMv7 cross compilation done:"
	@ls -ld $(GOBIN)/geth-linux-* | grep arm-7

geth-linux-arm64:
	$(GORUN) build/ci.go xgo -- --go=$(GO) --targets=linux/arm64 -v ./cmd/geth
	@echo "Linux ARM64 cross compilation done:"
	@ls -ld $(GOBIN)/geth-linux-* | grep arm64

geth-linux-mips:
	$(GORUN) build/ci.go xgo -- --go=$(GO) --targets=linux/mips --ldflags '-extldflags "-static"' -v ./cmd/geth
	@echo "Linux MIPS cross compilation done:"
	@ls -ld $(GOBIN)/geth-linux-* | grep mips

geth-linux-mipsle:
	$(GORUN) build/ci.go xgo -- --go=$(GO) --targets=linux/mipsle --ldflags '-extldflags "-static"' -v ./cmd/geth
	@echo "Linux MIPSle cross compilation done:"
	@ls -ld $(GOBIN)/geth-linux-* | grep mipsle

geth-linux-mips64:
	$(GORUN) build/ci.go xgo -- --go=$(GO) --targets=linux/mips64 --ldflags '-extldflags "-static"' -v ./cmd/geth
	@echo "Linux MIPS64 cross compilation done:"
	@ls -ld $(GOBIN)/geth-linux-* | grep mips64

geth-linux-mips64le:
	$(GORUN) build/ci.go xgo -- --go=$(GO) --targets=linux/mips64le --ldflags '-extldflags "-static"' -v ./cmd/geth
	@echo "Linux MIPS64le cross compilation done:"
	@ls -ld $(GOBIN)/geth-linux-* | grep mips64le

geth-darwin: geth-darwin-386 geth-darwin-amd64
	@echo "Darwin cross compilation done:"
	@ls -ld $(GOBIN)/geth-darwin-*

geth-darwin-386:
	$(GORUN) build/ci.go xgo -- --go=$(GO) --targets=darwin/386 -v ./cmd/geth
	@echo "Darwin 386 cross compilation done:"
	@ls -ld $(GOBIN)/geth-darwin-* | grep 386

geth-darwin-amd64:
	$(GORUN) build/ci.go xgo -- --go=$(GO) --targets=darwin/amd64 -v ./cmd/geth
	@echo "Darwin amd64 cross compilation done:"
	@ls -ld $(GOBIN)/geth-darwin-* | grep amd64

geth-windows: geth-windows-386 geth-windows-amd64
	@echo "Windows cross compilation done:"
	@ls -ld $(GOBIN)/geth-windows-*

geth-windows-386:
	$(GORUN) build/ci.go xgo -- --go=$(GO) --targets=windows/386 -v ./cmd/geth
	@echo "Windows 386 cross compilation done:"
	@ls -ld $(GOBIN)/geth-windows-* | grep 386

geth-windows-amd64:
	$(GORUN) build/ci.go xgo -- --go=$(GO) --targets=windows/amd64 -v ./cmd/geth
	@echo "Windows amd64 cross compilation done:"
	@ls -ld $(GOBIN)/geth-windows-* | grep amd64

PACKAGE_NAME          := github.com/maticnetwork/bor
GOLANG_CROSS_VERSION  ?= v1.18.1

.PHONY: release-dry-run
release-dry-run:
	@docker run \
		--rm \
		--privileged \
		-e CGO_ENABLED=1 \
		-e GITHUB_TOKEN \
		-e DOCKER_USERNAME \
		-e DOCKER_PASSWORD \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v `pwd`:/go/src/$(PACKAGE_NAME) \
		-w /go/src/$(PACKAGE_NAME) \
		goreleaser/goreleaser-cross:${GOLANG_CROSS_VERSION} \
		--rm-dist --skip-validate --skip-publish

.PHONY: release
release:
	@docker run \
		--rm \
		--privileged \
		-e CGO_ENABLED=1 \
		-e GITHUB_TOKEN \
		-e DOCKER_USERNAME \
		-e DOCKER_PASSWORD \
		-e SLACK_WEBHOOK \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v `pwd`:/go/src/$(PACKAGE_NAME) \
		-w /go/src/$(PACKAGE_NAME) \
		goreleaser/goreleaser-cross:${GOLANG_CROSS_VERSION} \
		--rm-dist --skip-validate
