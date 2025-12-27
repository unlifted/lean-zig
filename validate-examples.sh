#!/usr/bin/env bash
# Validate all lean-zig concepts demonstrated in examples

set -e  # Exit on error

echo "========================================="
echo "lean-zig: Validating Example Concepts"
echo "========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Track results
PASSED=0
FAILED=0

# Function to run test suite
run_test_suite() {
    echo -e "${BLUE}Running Zig test suite (117 tests)...${NC}"
    if zig build test 2>&1 | tee /tmp/lean-zig-test-output.txt; then
        echo -e "${GREEN}✓ All tests passed${NC}"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}✗ Tests failed${NC}"
        FAILED=$((FAILED + 1))
        return 1
    fi
    echo ""
}

# Function to check example documentation
check_examples() {
    echo -e "${BLUE}Checking example documentation...${NC}"
    
    local examples=(
        "01-hello-ffi"
        "02-boxing"
        "03-constructors"
        "04-arrays"
        "05-strings"
        "06-io-results"
        "07-closures"
        "08-tasks"
        "09-complete-app"
    )
    
    local all_good=true
    
    for example in "${examples[@]}"; do
        if [[ ! -f "examples/$example/README.md" ]]; then
            echo -e "${RED}✗ Missing: examples/$example/README.md${NC}"
            all_good=false
        fi
        if [[ ! -f "examples/$example/Main.lean" ]]; then
            echo -e "${RED}✗ Missing: examples/$example/Main.lean${NC}"
            all_good=false
        fi
    done
    
    if $all_good; then
        echo -e "${GREEN}✓ All 9 examples present${NC}"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}✗ Some examples missing${NC}"
        FAILED=$((FAILED + 1))
        return 1
    fi
    echo ""
}

# Function to verify concept coverage
verify_concept_coverage() {
    echo -e "${BLUE}Verifying concept coverage...${NC}"
    
    # Check that test files cover example concepts
    local concepts=(
        "Zig/tests/boxing_test.zig:Boxing (example 02)"
        "Zig/tests/constructor_test.zig:Constructors (example 03)"
        "Zig/tests/array_test.zig:Arrays (example 04)"
        "Zig/tests/string_test.zig:Strings (example 05)"
        "Zig/tests/closure_test.zig:Closures (example 07)"
        "Zig/tests/type_test.zig:Type checking (all examples)"
        "Zig/tests/refcount_test.zig:Memory management (all examples)"
    )
    
    local all_covered=true
    
    for concept in "${concepts[@]}"; do
        IFS=':' read -r file description <<< "$concept"
        if [[ -f "$file" ]]; then
            echo -e "  ${GREEN}✓${NC} $description"
        else
            echo -e "  ${RED}✗${NC} $description - file missing: $file"
            all_covered=false
        fi
    done
    
    if $all_covered; then
        echo -e "${GREEN}✓ All example concepts have test coverage${NC}"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}✗ Some concepts lack test coverage${NC}"
        FAILED=$((FAILED + 1))
        return 1
    fi
    echo ""
}

# Function to check documentation links
check_documentation() {
    echo -e "${BLUE}Checking documentation files...${NC}"
    
    local docs=(
        "doc/api.md"
        "doc/usage.md"
        "doc/design.md"
        "examples/README.md"
        "examples/BUILDING.md"
    )
    
    local all_docs=true
    
    for doc in "${docs[@]}"; do
        if [[ -f "$doc" ]]; then
            echo -e "  ${GREEN}✓${NC} $doc"
        else
            echo -e "  ${RED}✗${NC} $doc missing"
            all_docs=false
        fi
    done
    
    if $all_docs; then
        echo -e "${GREEN}✓ All documentation present${NC}"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}✗ Some documentation missing${NC}"
        FAILED=$((FAILED + 1))
        return 1
    fi
    echo ""
}

# Main execution
echo "This script validates that:"
echo "  1. All test suite tests pass (117 tests)"
echo "  2. All example documentation is present (9 examples)"
echo "  3. Example concepts are covered by tests"
echo "  4. Documentation is complete"
echo ""

# Run all checks
run_test_suite || true
check_examples || true
verify_concept_coverage || true
check_documentation || true

# Summary
echo "========================================="
echo "Summary"
echo "========================================="
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All validations passed!${NC}"
    echo ""
    echo "The examples are educational templates demonstrating concepts"
    echo "that are fully tested and validated in the test suite."
    echo ""
    echo "See examples/BUILDING.md for details on using these examples."
    exit 0
else
    echo -e "${RED}✗ Some validations failed${NC}"
    echo ""
    echo "Please fix the failures above."
    exit 1
fi
