#!/bin/bash
# Automated test script for MLisp VSCode extension
# This script verifies the extension build and configuration without requiring a GUI

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counter for results
PASS=0
FAIL=0
WARN=0

# Helper functions
pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    ((PASS++))
}

fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    ((FAIL++))
}

warn() {
    echo -e "${YELLOW}⚠ WARN${NC}: $1"
    ((WARN++))
}

info() {
    echo -e "${BLUE}ℹ INFO${NC}: $1"
}

# Change to extension directory
cd "$(dirname "$0")"
EXTENSION_DIR="$(pwd)"
PROJECT_ROOT="$(cd "$EXTENSION_DIR/../.." && pwd)"

echo "========================================"
echo "MLisp VSCode Extension - Automated Test"
echo "========================================"
echo ""

# Test 1: Check if node_modules exists (may be at workspace root with pnpm)
echo "[1/12] Checking node_modules..."
if [ -d "node_modules" ]; then
    pass "node_modules directory exists"
elif [ -d "$PROJECT_ROOT/node_modules" ]; then
    pass "node_modules found at workspace root (pnpm monorepo)"
else
    warn "node_modules not found - may be using pnpm workspace"
fi

# Test 2: Check if dune project is configured
echo "[2/12] Checking Dune configuration..."
if [ -f "dune-project" ]; then
    pass "dune-project file exists"
else
    fail "dune-project file not found"
fi

# Test 3: Check if source files exist
echo "[3/12] Checking source files..."
if [ -f "src/vscode_mlisp.ml" ]; then
    pass "OCaml source file exists"
else
    fail "OCaml source file not found"
fi

# Test 4: Build the OCaml bytecode
echo "[4/12] Building OCaml bytecode..."
if dune build > /tmp/dune_build.log 2>&1; then
    pass "OCaml build successful"
    if [ -f "_build/default/src/vscode_mlisp.bc.js" ]; then
        pass "Bytecode JavaScript file generated"
    else
        fail "Bytecode JavaScript file not found at expected path"
    fi
else
    fail "OCaml build failed - check /tmp/dune_build.log"
    cat /tmp/dune_build.log
fi

# Test 5: Bundle the extension
echo "[5/12] Bundling with esbuild..."
# Check if bundle already exists (from npm run build)
if [ -f "dist/vscode_mlisp.bc.js" ] && [ "_build/default/src/vscode_mlisp.bc.js" -ot "dist/vscode_mlisp.bc.js" ]; then
    pass "Bundle exists and is up to date"
elif command -v esbuild &> /dev/null; then
    if esbuild _build/default/src/vscode_mlisp.bc.js --bundle --external:vscode --minify --outdir=dist --platform=node --target=node18 > /tmp/esbuild.log 2>&1; then
        pass "esbuild bundling successful"
    else
        fail "esbuild bundling failed - check /tmp/esbuild.log"
        cat /tmp/esbuild.log
    fi
elif command -v npx &> /dev/null; then
    if npx esbuild _build/default/src/vscode_mlisp.bc.js --bundle --external:vscode --minify --outdir=dist --platform=node --target=node18 > /tmp/esbuild.log 2>&1; then
        pass "esbuild bundling successful (via npx)"
    else
        fail "esbuild bundling failed - check /tmp/esbuild.log"
        cat /tmp/esbuild.log
    fi
else
    if [ -f "dist/vscode_mlisp.bc.js" ]; then
        pass "Using existing bundle (esbuild not available in PATH)"
    else
        fail "esbuild not found and no existing bundle"
    fi
fi

# Test 6: Check bundle size
echo "[6/12] Checking bundle size..."
if [ -f "dist/vscode_mlisp.bc.js" ]; then
    SIZE=$(wc -c < "dist/vscode_mlisp.bc.js")
    SIZE_KB=$((SIZE / 1024))
    echo "       Bundle size: ${SIZE_KB}KB (${SIZE} bytes)"
    if [ $SIZE -gt 100000 ]; then
        pass "Bundle size is reasonable (${SIZE_KB}KB)"
    else
        warn "Bundle seems suspiciously small"
    fi
else
    fail "Bundle file not found"
fi

# Test 7: Verify bundle is not empty and contains expected patterns
echo "[7/12] Verifying bundle content..."
if [ -f "dist/vscode_mlisp.bc.js" ]; then
    # Check for esbuild wrapper
    if grep -q "globalThis" "dist/vscode_mlisp.bc.js"; then
        pass "Bundle contains expected JavaScript patterns"
    else
        warn "Bundle may be malformed"
    fi

    # Check for vscode activation
    if grep -q "activate" "src/vscode_mlisp.ml"; then
        pass "Source contains activation function"
    else
        fail "Source missing activation function"
    fi
fi

# Test 8: Validate package.json
echo "[8/12] Validating package.json..."
if command -v jq &> /dev/null; then
    # Check required fields
    NAME=$(jq -r '.name' package.json)
    DISPLAY_NAME=$(jq -r '.displayName' package.json)
    MAIN=$(jq -r '.main' package.json)

    if [ "$NAME" == "mlisp-vscode" ]; then
        pass "package.json name is correct"
    else
        fail "package.json name is incorrect: $NAME"
    fi

    if [ -n "$DISPLAY_NAME" ]; then
        pass "package.json has displayName"
    else
        fail "package.json missing displayName"
    fi

    if [ "$MAIN" == "./dist/vscode_mlisp.bc.js" ]; then
        pass "package.json main entry is correct"
    else
        fail "package.json main entry is incorrect: $MAIN"
    fi

    # Check activation events
    ACTIVATION=$(jq -r '.activationEvents[0]' package.json)
    if [ "$ACTIVATION" == "onStartupFinished" ]; then
        pass "package.json has activation event"
    else
        warn "Activation event may be missing: $ACTIVATION"
    fi
else
    warn "jq not installed - skipping package.json detailed validation"
    if [ -f "package.json" ]; then
        pass "package.json exists"
    fi
fi

# Test 9: Check language configuration
echo "[9/12] Checking language configuration..."
if [ -f "language-configuration.json" ]; then
    pass "language-configuration.json exists"
else
    fail "language-configuration.json not found"
fi

# Test 10: Check syntax grammar
echo "[10/12] Checking syntax grammar..."
if [ -f "syntaxes/mlisp.tmLanguage.json" ]; then
    pass "Syntax grammar file exists"

    # Verify it has required keys
    if command -v jq &> /dev/null; then
        SCOPE=$(jq -r '.scopeName' syntaxes/mlisp.tmLanguage.json)
        if [ "$SCOPE" == "source.mlisp" ]; then
            pass "Grammar has correct scopeName"
        else
            warn "Grammar scopeName may be incorrect: $SCOPE"
        fi
    fi
else
    fail "Syntax grammar file not found"
fi

# Test 11: Check test workspace
echo "[11/12] Checking test workspace..."
TEST_WORKSPACE="$PROJECT_ROOT/test-workspace"
if [ -d "$TEST_WORKSPACE" ]; then
    pass "Test workspace exists"

    # Count test files
    MLISP_COUNT=$(find "$TEST_WORKSPACE" -name "*.mlisp" 2>/dev/null | wc -l)
    if [ "$MLISP_COUNT" -gt 0 ]; then
        pass "Test workspace contains $MLISP_COUNT .mlisp file(s)"
    else
        warn "Test workspace has no .mlisp files"
    fi

    # Check for test documentation
    if [ -f "$TEST_WORKSPACE/EXTENSION_TESTING.md" ]; then
        pass "Test documentation exists"
    else
        warn "Test documentation not found"
    fi
else
    warn "Test workspace not found at $TEST_WORKSPACE"
fi

# Test 12: Check biome linting
echo "[12/12] Running biome checks..."
if command -v npx &> /dev/null; then
    if npx biome check --diagnostic-level=error > /dev/null 2>&1; then
        pass "Biome checks passed"
    else
        warn "Biome found issues (run 'npm run fix' to auto-fix)"
    fi
else
    warn "npx not found - skipping biome checks"
fi

# Summary
echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo -e "${GREEN}Passed:${NC}   $PASS"
echo -e "${YELLOW}Warnings:${NC} $WARN"
echo -e "${RED}Failed:${NC}   $FAIL"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}All critical tests passed!${NC}"
    echo ""
    echo "To launch the Extension Development Host, run:"
    echo "  code --extensionDevelopmentPath=\"$EXTENSION_DIR\" \"$TEST_WORKSPACE\""
    echo ""
    echo "Or to package and install the extension:"
    echo "  npm run package"
    echo "  npm run install:ext"
    exit 0
else
    echo -e "${RED}Some tests failed. Please review the output above.${NC}"
    exit 1
fi
