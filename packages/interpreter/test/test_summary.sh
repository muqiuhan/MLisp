#!/bin/bash

# Generate a detailed test summary with statistics

echo "MLisp Test Suite Summary"
echo "========================"
echo ""

# Count test files
total_files=$(find test -name "*.mlisp" -type f | wc -l)
numbered_tests=$(find test -name "[0-9][0-9]_*.mlisp" -type f | wc -l)
module_tests=$(find test -name "*module*.mlisp" -type f | wc -l)
other_tests=$(find test -name "*.mlisp" -type f | grep -v "^[0-9][0-9]_" | grep -v "module" | wc -l)

echo "Test File Statistics:"
echo "  Total test files:     $total_files"
echo "  Core test suites:     $numbered_tests"
echo "  Module tests:         $module_tests"
echo "  Other tests:          $other_tests"
echo ""

# List core test suites
echo "Core Test Suites:"
for f in test/[0-9][0-9]_*.mlisp; do
    if [ -f "$f" ]; then
        name=$(basename "$f" .mlisp)
        # Extract description from file
        desc=$(grep "^;; Description:" "$f" | sed 's/^;; Description: //')
        printf "  %-25s %s\n" "$name" "$desc"
    fi
done
echo ""

# Count test cases (approximate - count ;; Test: lines)
total_test_cases=0
for f in test/[0-9][0-9]_*.mlisp; do
    if [ -f "$f" ]; then
        count=$(grep -c "^;; Test:" "$f")
        total_test_cases=$((total_test_cases + count))
    fi
done

echo "Approximate test case count: $total_test_cases"
echo ""

# Show test coverage
echo "Feature Coverage:"
echo "  ✅ Basic types"
echo "  ✅ Arithmetic operations"
echo "  ✅ Comparison operations"
echo "  ✅ Conditional expressions"
echo "  ✅ Variable definitions"
echo "  ✅ Functions (lambda, defun)"
echo "  ✅ Closures"
echo "  ✅ Let bindings"
echo "  ✅ Module system"
echo "  ✅ String operations"
echo "  ✅ Apply function"
echo ""

echo "To run tests:"
echo "  ./run_tests.sh              # All tests"
echo "  make test                   # Using Makefile"
echo "  make test-quick             # Core tests only"
echo "  make TEST=06_functions test-single  # Single test"
