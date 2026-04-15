# Makefile for harness
# Provides common development and build targets

.PHONY: all build test lint fmt vet clean help

# Go parameters
GOCMD := go
GOBUILD := $(GOCMD) build
GOTEST := $(GOCMD) test
GOVET := $(GOCMD) vet
GOFMT := gofmt
GOLINT := golangci-lint

# Build parameters
BINARY_NAME := harness
BUILD_DIR := ./bin
MAIN_PACKAGE := ./cmd/harness

# Version info
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
COMMIT  ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_TIME ?= $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")

LD_FLAGS := -ldflags "-X main.Version=$(VERSION) -X main.Commit=$(COMMIT) -X main.BuildTime=$(BUILD_TIME)"

# Default target
# Note: skipping lint in default target locally since golangci-lint isn't always installed
# Personal: added tidy to default so modules stay clean without thinking about it
all: fmt vet tidy test build

## build: Compile the binary
build:
	@echo "Building $(BINARY_NAME)..."
	@mkdir -p $(BUILD_DIR)
	$(GOBUILD) $(LD_FLAGS) -o $(BUILD_DIR)/$(BINARY_NAME) $(MAIN_PACKAGE)
	@echo "Build complete: $(BUILD_DIR)/$(BINARY_NAME)"

## test: Run all unit tests
test:
	@echo "Running tests..."
	$(GOTEST) -v -race -coverprofile=coverage.out ./...
	@echo "Tests complete."

## test-coverage: Run tests and open coverage report
test-coverage: test
	$(GOCMD) tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report: coverage.html"

# Personal note: I prefer to see a summary line after lint so failures are easier to spot
## lint: Run golangci-lint
lint:
	@echo "Running linter..."
	$(GOLINT) run ./... && echo "Lint passed." || (echo "Lint failed."; exit 1)

## fmt: Format Go source files
fmt:
	@echo "Formatting source files..."
	$(GOFMT) -w -s $$(find . -name '*.go' -not -path './vendor/*')

## vet: Run go vet
vet:
	@echo "Running go vet..."
	$(GOVET) ./...

## tidy: Tidy go modules
tidy:
	@echo "Tidying modules..."
	$(GOCMD) mod tidy

## clean: Remove build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR)
	@rm -f coverage.out coverage.html
	@echo "Clean complete."

## install-hooks: Install git hooks
install-hooks:
	@echo "Installing git hooks..."
	@cp .githooks/pre-commit .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
	@echo "Git hooks installed."

## watch-test: Re-run tests on file changes (requires entr: brew/apt install entr)
watch-test:
	@echo "Watching for changes..."
	find . -name '*.go' -not -path './vendor/*' | entr -c $(GOTEST) -v ./...

## coverage-summary: Print per-package coverage percentages to stdout
# Personal addition: quick way to eyeball coverage without opening a browser
coverage-summary: test
	$(GOCMD) tool cover -func=coverage.out
	# Also print the total line for easy grepping
	@$(GOCMD) tool cover -func=coverage.out | grep '^total:'

## help: Show this help message
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@sed -n 's/^##//p' $(MAKEFILE_LIST) | column -t -s ':' | sed -e 's/^/ /'

# Personal: run fmt, vet, lint, and test without building — useful before pushing
# a branch when I don't need a fresh binary but want to be sure things are clean
.PHONY: check
## check: Run fmt, vet, lint, and test (no build)
check: fmt vet lint test
	@echo "All checks passed."

##
