#!/bin/bash

# ============================================================================
# MLisp Test Runner
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Test statistics
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Test results storage
declare -a FAILED_TEST_NAMES
declare -a SKIPPED_TEST_NAMES

# Configuration
TEST_DIR="test"
VERBOSE=${VERBOSE:-0}
STOP_ON_FAILURE=${STOP_ON_FAILURE:-0}
PATTERN=${1:-"*.mlisp"}

# Function to print colored output
print_color() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

# Function to print section header
print_header() {
    echo ""
    print_color "$BLUE" "=================================="
    print_color "$BOLD$BLUE" "$1"
    print_color "$BLUE" "=================================="
}

# Function to run a single test
run_test() {
    local test_file=$1
    local test_name=$(basename "$test_file" .mlisp)

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    # Print test name
    printf "  %-50s " "$test_name"

    # Run the test and capture output
    local output
    local exit_code

    # Use a temporary file to avoid command substitution blocking issues
    local temp_output=$(mktemp)
    
    # Temporarily disable set -e to allow non-zero exit codes
    set +e
    if [ $VERBOSE -eq 1 ]; then
        stdbuf -oL -eL dune exec -- mlisp "$test_file" > "$temp_output" 2>&1
        exit_code=$?
        output=$(cat "$temp_output")
        echo ""
        echo "$output"
    else
        stdbuf -oL -eL dune exec -- mlisp "$test_file" > "$temp_output" 2>&1
        exit_code=$?
        output=$(cat "$temp_output")
    fi
    set -e
    
    rm -f "$temp_output"

    # Remove ANSI escape codes for error detection
    local clean_output=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')

    # Check for errors, assertion failures, or warnings
    if [ $exit_code -ne 0 ]; then
        print_color "$RED" "[FAILED]"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        FAILED_TEST_NAMES+=("$test_name")

        if [ $VERBOSE -eq 0 ]; then
            echo "  Error output:"
            # Extract error messages with context (error line + next 12 lines for full error details)
            # Remove separator lines (--) and limit to first 40 lines
            echo "$clean_output" | grep -A 12 "\[error" | grep -v "^--$" | head -40 | sed 's/^/    /'
        fi

        if [ $STOP_ON_FAILURE -eq 1 ]; then
            print_color "$RED" "Stopping due to failure (STOP_ON_FAILURE=1)"
            exit 1
        fi
    elif echo "$clean_output" | grep -qiE "\[error"; then
        print_color "$RED" "[FAILED]"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        FAILED_TEST_NAMES+=("$test_name")

        if [ $VERBOSE -eq 0 ]; then
            echo "  Error details:"
            # Extract error messages with context (error line + next 12 lines for full error details)
            # Remove separator lines (--) and limit to first 40 lines
            echo "$clean_output" | grep -A 12 "\[error" | grep -v "^--$" | head -40 | sed 's/^/    /'
        fi

        if [ $STOP_ON_FAILURE -eq 1 ]; then
            print_color "$RED" "Stopping due to failure (STOP_ON_FAILURE=1)"
            exit 1
        fi
    elif echo "$clean_output" | grep -qi "Assertion failed"; then
        print_color "$RED" "[FAILED]"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        FAILED_TEST_NAMES+=("$test_name")

        if [ $VERBOSE -eq 0 ]; then
            echo "  Assertion failed:"
            # Extract assertion failure messages with context
            echo "$clean_output" | grep -iB 2 -A 5 "Assertion failed" | head -20 | sed 's/^/    /'
        fi

        if [ $STOP_ON_FAILURE -eq 1 ]; then
            print_color "$RED" "Stopping due to failure (STOP_ON_FAILURE=1)"
            exit 1
        fi
    elif echo "$clean_output" | grep -qiE "\[warning"; then
        # Check if it's an expected warning (like in module tests)
        if echo "$test_name" | grep -q "module"; then
            print_color "$GREEN" "[PASSED]"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            print_color "$YELLOW" "[WARNING]"
            PASSED_TESTS=$((PASSED_TESTS + 1))
            if [ $VERBOSE -eq 0 ]; then
                echo "  Warnings:"
                echo "$clean_output" | grep -iE "\[warning" | head -2 | sed 's/^/    /'
            fi
        fi
    else
        print_color "$GREEN" "[PASSED]"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    fi
}

# Function to print test summary
print_summary() {
    print_header "Test Summary"

    echo ""
    echo "  Total tests:    $TOTAL_TESTS"
    print_color "$GREEN" "  Passed:         $PASSED_TESTS"

    if [ $FAILED_TESTS -gt 0 ]; then
        print_color "$RED" "  Failed:         $FAILED_TESTS"
    else
        echo "  Failed:         $FAILED_TESTS"
    fi

    if [ $SKIPPED_TESTS -gt 0 ]; then
        print_color "$YELLOW" "  Skipped:        $SKIPPED_TESTS"
    fi

    # Calculate pass rate
    if [ $TOTAL_TESTS -gt 0 ]; then
        local pass_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
        echo "  Pass rate:      ${pass_rate}%"
    fi

    echo ""

    # List failed tests
    if [ $FAILED_TESTS -gt 0 ]; then
        print_color "$RED" "Failed tests:"
        for test in "${FAILED_TEST_NAMES[@]}"; do
            echo "  - $test"
        done
        echo ""
    fi

    # List skipped tests
    if [ $SKIPPED_TESTS -gt 0 ]; then
        print_color "$YELLOW" "Skipped tests:"
        for test in "${SKIPPED_TEST_NAMES[@]}"; do
            echo "  - $test"
        done
        echo ""
    fi

    # Exit with appropriate code
    if [ $FAILED_TESTS -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
}

# Main execution
main() {
    print_header "MLisp Test Suite"

    echo ""
    echo "Configuration:"
    echo "  Test directory: $TEST_DIR"
    echo "  Pattern:        $PATTERN"
    echo "  Verbose:        $VERBOSE"
    echo "  Stop on fail:   $STOP_ON_FAILURE"
    echo ""

    # Build the project first
    print_color "$BLUE" "Building project..."
    if ! dune build 2>&1 | tail -5; then
        print_color "$RED" "Build failed!"
        exit 1
    fi
    print_color "$GREEN" "Build successful!"

    # Find and run tests
    print_header "Running Tests"
    echo ""

    # Get list of test files, sorted
    local test_files=$(find "$TEST_DIR" -name "$PATTERN" -type f | sort)

    if [ -z "$test_files" ]; then
        print_color "$YELLOW" "No test files found matching pattern: $PATTERN"
        exit 0
    fi

    # Run each test
    for test_file in $test_files; do
        run_test "$test_file"
    done

    # Print summary
    print_summary
}

# Handle Ctrl+C
trap 'echo ""; print_color "$YELLOW" "Tests interrupted!"; print_summary' INT

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=1
            shift
            ;;
        -s|--stop-on-failure)
            STOP_ON_FAILURE=1
            shift
            ;;
        -h|--help)
            echo "MLisp Test Runner"
            echo ""
            echo "Usage: $0 [OPTIONS] [PATTERN]"
            echo ""
            echo "Options:"
            echo "  -v, --verbose         Show verbose output"
            echo "  -s, --stop-on-failure Stop on first failure"
            echo "  -h, --help            Show this help message"
            echo ""
            echo "Pattern:"
            echo "  Glob pattern to match test files (default: *.mlisp)"
            echo ""
            echo "Examples:"
            echo "  $0                    # Run all tests"
            echo "  $0 '0[1-5]*.mlisp'    # Run tests 01-05"
            echo "  $0 -v module*.mlisp   # Run module tests with verbose output"
            echo "  VERBOSE=1 $0          # Run all tests verbosely"
            exit 0
            ;;
        *)
            PATTERN=$1
            shift
            ;;
    esac
done

# Run main function
main
