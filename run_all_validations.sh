#!/bin/bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TESTS_DIR="$SCRIPT_DIR/groups"
RESULTS_DIR="$SCRIPT_DIR/results"

# Get model name from argument or prompt
MODEL_NAME="${1:-unnamed_model}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULT_FILE="$RESULTS_DIR/${MODEL_NAME}_${TIMESTAMP}.txt"

mkdir -p "$RESULTS_DIR"

echo "============================================="
echo "  Agentic Vibe-Coding Test Battery"
echo "  Model: $MODEL_NAME"
echo "  Date:  $(date)"
echo "============================================="
echo ""

TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_CHECKS=0

# Collect results for table
declare -a TEST_NAMES
declare -a TEST_SCORES

for test_dir in "$TESTS_DIR"/*/*/; do
    test_name=$(basename "$test_dir")
    validate_script="$test_dir/validate.sh"

    if [ ! -f "$validate_script" ]; then
        echo "SKIP: $test_name (no validate.sh)"
        continue
    fi

    # Check if workspace has any files
    workspace="$test_dir/workspace"
    if [ ! -d "$workspace" ] || [ -z "$(ls -A "$workspace" 2>/dev/null)" ]; then
        echo "SKIP: $test_name (workspace empty — run the model first)"
        TEST_NAMES+=("$test_name")
        TEST_SCORES+=("-")
        continue
    fi

    echo "--- $test_name ---"

    # Run validator and capture output
    test_pass=0
    test_fail=0
    output=$(bash "$validate_script" 2>&1) || true

    while IFS= read -r line; do
        if echo "$line" | grep -qE '\|PASS$'; then
            ((test_pass++))
            ((TOTAL_PASS++))
            echo "  ✓ $(echo "$line" | cut -d'|' -f2)"
        elif echo "$line" | grep -qE '\|FAIL$'; then
            ((test_fail++))
            ((TOTAL_FAIL++))
            echo "  ✗ $(echo "$line" | cut -d'|' -f2)"
        fi
    done <<< "$output"

    test_total=$((test_pass + test_fail))
    ((TOTAL_CHECKS += test_total))

    TEST_NAMES+=("$test_name")
    TEST_SCORES+=("$test_pass/$test_total")
    echo ""
done

echo ""
echo "============================================="
echo "  SCORECARD: $MODEL_NAME"
echo "============================================="
printf "%-30s %s\n" "Test" "Score"
printf "%-30s %s\n" "------------------------------" "-----"
for i in "${!TEST_NAMES[@]}"; do
    printf "%-30s %s\n" "${TEST_NAMES[$i]}" "${TEST_SCORES[$i]}"
done
printf "%-30s %s\n" "------------------------------" "-----"
printf "%-30s %s\n" "TOTAL" "$TOTAL_PASS/$TOTAL_CHECKS"
echo ""

# Save results
{
    echo "Model: $MODEL_NAME"
    echo "Date: $(date)"
    echo "Score: $TOTAL_PASS/$TOTAL_CHECKS"
    echo ""
    for i in "${!TEST_NAMES[@]}"; do
        echo "${TEST_NAMES[$i]}: ${TEST_SCORES[$i]}"
    done
} > "$RESULT_FILE"

echo "Results saved to: $RESULT_FILE"
