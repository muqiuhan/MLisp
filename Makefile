.PHONY: test test-verbose test-quick test-modules test-core clean build help

# Default target
help:
	@echo "MLisp Test Targets:"
	@echo "  make test          - Run all tests"
	@echo "  make test-verbose  - Run all tests with verbose output"
	@echo "  make test-quick    - Run core tests (01-05)"
	@echo "  make test-core     - Run core language tests (01-08)"
	@echo "  make test-modules  - Run module system tests"
	@echo "  make test-single   - Run single test (TEST=filename)"
	@echo "  make build         - Build the project"
	@echo "  make clean         - Clean build artifacts"
	@echo ""
	@echo "Examples:"
	@echo "  make test"
	@echo "  make test-verbose"
	@echo "  make TEST=06_functions test-single"

# Build the project
build:
	@echo "Building MLisp..."
	@dune build

# Clean build artifacts
clean:
	@echo "Cleaning..."
	@dune clean

# Run all tests
test: build
	@./run_tests.sh

# Run tests with verbose output
test-verbose: build
	@./run_tests.sh -v

# Run quick core tests (01-05)
test-quick: build
	@./run_tests.sh '0[1-5]*.mlisp'

# Run core language tests (01-08)
test-core: build
	@./run_tests.sh '0[1-8]*.mlisp'

# Run module system tests
test-modules: build
	@./run_tests.sh '*module*.mlisp'

# Run single test file
test-single: build
ifndef TEST
	@echo "Error: TEST variable not set"
	@echo "Usage: make TEST=filename test-single"
	@echo "Example: make TEST=06_functions test-single"
	@exit 1
endif
	@./run_tests.sh '$(TEST)*.mlisp'

# Run tests and stop on first failure
test-stop: build
	@./run_tests.sh -s

# Run CI tests (for continuous integration)
test-ci: build
	@./run_tests.sh || (echo "Tests failed!" && exit 1)
