#!/bin/bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Load API keys from .env if present
if [ -f "$SCRIPT_DIR/.env" ]; then
    set -a
    source "$SCRIPT_DIR/.env"
    set +a
fi

GROUPS_DIR="$SCRIPT_DIR/groups"
MODELS_FILE="$SCRIPT_DIR/models.txt"
TIMEOUT="${OPENCODE_TIMEOUT:-300}"  # 5 minutes default, override with env var
GROUP="${OPENCODE_GROUP:-}"  # specific group to run, or empty for all
TEST_FILTER="${OPENCODE_TESTS:-}"  # comma-separated test names to run, or empty for all
REASONING="${OPENCODE_REASONING:-}"  # set to 1 to enable reasoning mode
PROMPT_TOOLS="${OPENCODE_PROMPT_TOOLS:-}"  # set to 1 to use prompt-based tool calling
HARNESS="${OPENCODE_HARNESS:-agent_harness.py}"  # harness script (agent_harness.py or agent_harness_gemini.py)
THINKING="${OPENCODE_THINKING:-}"  # thinking level for Gemini harness (off/low/medium/high)

RESULTS_DIR="$SCRIPT_DIR/results"
mkdir -p "$RESULTS_DIR"

# ── Helpers ──────────────────────────────────────────────────────────────────

usage() {
    echo "Usage: $0 [model1] [model2] ..."
    echo "       $0                        # runs all models from models.txt"
    echo "       $0 openrouter/z-ai/glm-5  # run one model"
    echo ""
    echo "Environment variables:"
    echo "  OPENCODE_TIMEOUT=300   # seconds per test (default: 300)"
    echo "  OPENCODE_GROUP=group1_python_fundamentals  # run specific group"
    echo "  OPENCODE_TESTS=06_expense_tracker_api,07_url_shortener  # run specific tests"
    exit 1
}

# Sanitize model name for use in filenames
sanitize_name() {
    echo "$1" | sed 's/[^a-zA-Z0-9._-]/_/g'
}

# Get workspace size in bytes
workspace_size() {
    local dir="$1"
    if [ -d "$dir" ] && [ -n "$(ls -A "$dir" 2>/dev/null)" ]; then
        find "$dir" -type f -exec cat {} + 2>/dev/null | wc -c | tr -d ' '
    else
        echo "0"
    fi
}

# Format seconds to human readable
format_time() {
    local secs=$1
    if [ "$secs" -ge 3600 ]; then
        printf "%dh %02dm %02ds" $((secs/3600)) $((secs%3600/60)) $((secs%60))
    elif [ "$secs" -ge 60 ]; then
        printf "%dm %02ds" $((secs/60)) $((secs%60))
    else
        printf "%ds" "$secs"
    fi
}

# ── Collect models ───────────────────────────────────────────────────────────

MODELS=()
if [ $# -gt 0 ]; then
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        usage
    fi
    MODELS=("$@")
else
    if [ ! -f "$MODELS_FILE" ]; then
        echo "Error: No models specified and $MODELS_FILE not found."
        usage
    fi
    while IFS= read -r line; do
        line=$(echo "$line" | xargs)  # trim whitespace
        [ -z "$line" ] && continue
        [[ "$line" == \#* ]] && continue
        MODELS+=("$line")
    done < "$MODELS_FILE"
fi

if [ ${#MODELS[@]} -eq 0 ]; then
    echo "Error: No models to test."
    exit 1
fi

# ── Discover tests across groups ──────────────────────────────────────────────

TESTS=()
if [ -n "$GROUP" ]; then
    # Run specific group
    GROUP_DIRS=("$GROUPS_DIR/$GROUP")
else
    # Run all groups
    GROUP_DIRS=("$GROUPS_DIR"/*/)
fi

for group_dir in "${GROUP_DIRS[@]}"; do
    [ -d "$group_dir" ] || continue
    for test_dir in "$group_dir"/*/; do
        [ -f "$test_dir/validate.sh" ] && [ -f "$test_dir/prompt.md" ] || continue
        # Apply test filter if set
        if [ -n "$TEST_FILTER" ]; then
            test_name=$(basename "$test_dir")
            if ! echo ",$TEST_FILTER," | grep -q ",$test_name,"; then
                continue
            fi
        fi
        TESTS+=("$test_dir")
    done
done

if [ ${#TESTS[@]} -eq 0 ]; then
    echo "Error: No tests found in $GROUPS_DIR"
    exit 1
fi

NUM_TESTS=${#TESTS[@]}
ACTIVE_GROUP="${GROUP:-all}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Temp dir for storing results (avoids associative arrays for bash 3 compat)
TMPRESULTS=$(mktemp -d)
trap 'rm -rf "$TMPRESULTS"' EXIT

echo "═══════════════════════════════════════════════════════════════"
echo "  Agentic Coding Benchmark (agent_harness)"
echo "  Date:     $(date)"
echo "  Models:   ${#MODELS[@]}"
echo "  Tests:    $NUM_TESTS"
echo "  Timeout:  ${TIMEOUT}s per test"
echo "  Group:    ${ACTIVE_GROUP}"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# ── Run benchmark ────────────────────────────────────────────────────────────

for model in "${MODELS[@]}"; do
    model_safe=$(sanitize_name "$model")
    model_result_dir="$RESULTS_DIR/${model_safe}_${TIMESTAMP}"
    mkdir -p "$model_result_dir"
    mkdir -p "$TMPRESULTS/$model_safe"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  MODEL: $model"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    model_total_pass=0
    model_total_checks=0
    model_total_time=0
    model_total_size=0
    model_total_cost="0"
    model_total_input=0
    model_total_output=0
    model_total_tokens=0

    for test_dir in "${TESTS[@]}"; do
        test_name=$(basename "$test_dir")
        workspace="$test_dir/workspace"
        prompt_file="$test_dir/prompt.md"
        validate_script="$test_dir/validate.sh"
        harness_log="$model_result_dir/${test_name}_harness.log"

        echo ""
        echo "  ┌─ $test_name"

        # Clean workspace
        rm -rf "$workspace"
        mkdir -p "$workspace"

        # Run setup if exists (copies fixture files into workspace)
        setup_script="$test_dir/setup.sh"
        if [ -f "$setup_script" ]; then
            bash "$setup_script" 2>/dev/null || true
        fi

        abs_workspace="$(cd "$workspace" && pwd)"

        # Run agent harness
        echo "  │  Running agent harness..."
        start_time=$(date +%s)

        EXTRA_FLAGS=""
        if [ -n "$REASONING" ] && [ "$REASONING" = "1" ]; then
            EXTRA_FLAGS="$EXTRA_FLAGS --reasoning"
        fi
        if [ -n "$PROMPT_TOOLS" ] && [ "$PROMPT_TOOLS" = "1" ]; then
            EXTRA_FLAGS="$EXTRA_FLAGS --prompt-tools"
        fi
        if [ -n "$THINKING" ] && [ "$HARNESS" = "agent_harness_gemini.py" ]; then
            EXTRA_FLAGS="$EXTRA_FLAGS --thinking $THINKING"
        fi

        harness_json=$(python3 "$SCRIPT_DIR/$HARNESS" \
            --model "$model" \
            --prompt "$prompt_file" \
            --workspace "$abs_workspace" \
            --timeout "$TIMEOUT" \
            $EXTRA_FLAGS \
            2>"$harness_log") || true

        end_time=$(date +%s)
        elapsed=$((end_time - start_time))

        # Check if timed out
        if [ "$elapsed" -ge "$TIMEOUT" ]; then
            echo "  │  TIMED OUT after ${TIMEOUT}s"
        else
            echo "  │  Completed in $(format_time $elapsed)"
        fi

        # Measure output
        size=$(workspace_size "$workspace")

        # Extract token/cost data from harness JSON output (single python call)
        read test_cost test_input test_output test_reasoning test_total_tokens <<< \
            $(echo "$harness_json" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('cost',0), d.get('input_tokens',0), d.get('output_tokens',0), d.get('reasoning_tokens',0), d.get('total_tokens',0))
except:
    print('0 0 0 0 0')
" 2>/dev/null || echo "0 0 0 0 0")

        # Run validation
        echo "  │  Validating..."
        test_pass=0
        test_checks=0

        if [ -n "$(ls -A "$workspace" 2>/dev/null)" ]; then
            val_output=$(bash "$validate_script" 2>&1) || true

            while IFS= read -r line; do
                if echo "$line" | grep -qE '\|PASS$'; then
                    test_pass=$((test_pass + 1))
                    test_checks=$((test_checks + 1))
                    check_name=$(echo "$line" | cut -d'|' -f2)
                    echo "  │  ✓ $check_name"
                elif echo "$line" | grep -qE '\|FAIL$'; then
                    test_checks=$((test_checks + 1))
                    check_name=$(echo "$line" | cut -d'|' -f2)
                    echo "  │  ✗ $check_name"
                fi
            done <<< "$val_output"
        else
            echo "  │  ✗ No output generated"
            test_checks=3
        fi

        cost_display=$(printf "\$%.4f" "$test_cost")
        echo "  │  Score: $test_pass/$test_checks | Time: $(format_time $elapsed) | Cost: $cost_display | Tokens: $test_total_tokens"
        echo "  └─"

        # Store per-test results in temp files
        echo "$test_pass" > "$TMPRESULTS/$model_safe/${test_name}_score"
        echo "$elapsed" > "$TMPRESULTS/$model_safe/${test_name}_time"
        echo "$size" > "$TMPRESULTS/$model_safe/${test_name}_size"
        echo "$test_cost" > "$TMPRESULTS/$model_safe/${test_name}_cost"
        echo "$test_input" > "$TMPRESULTS/$model_safe/${test_name}_input_tokens"
        echo "$test_output" > "$TMPRESULTS/$model_safe/${test_name}_output_tokens"
        echo "$test_total_tokens" > "$TMPRESULTS/$model_safe/${test_name}_total_tokens"

        model_total_pass=$((model_total_pass + test_pass))
        model_total_checks=$((model_total_checks + test_checks))
        model_total_time=$((model_total_time + elapsed))
        model_total_size=$((model_total_size + size))
        model_total_cost=$(echo "$model_total_cost + $test_cost" | bc 2>/dev/null || echo "$model_total_cost")
        model_total_input=$((model_total_input + test_input))
        model_total_output=$((model_total_output + test_output))
        model_total_tokens=$((model_total_tokens + test_total_tokens))

        # Save per-test detail
        {
            echo "test: $test_name"
            echo "model: $model"
            echo "score: $test_pass/$test_checks"
            echo "time: ${elapsed}s"
            echo "output_bytes: $size"
            echo "cost: $test_cost"
            echo "input_tokens: $test_input"
            echo "output_tokens: $test_output"
            echo "reasoning_tokens: $test_reasoning"
            echo "total_tokens: $test_total_tokens"
            echo "timed_out: $([ "$elapsed" -ge "$TIMEOUT" ] && echo yes || echo no)"
        } > "$model_result_dir/${test_name}_result.txt"

    done

    # Store model totals
    echo "$model_total_pass" > "$TMPRESULTS/$model_safe/total_pass"
    echo "$model_total_checks" > "$TMPRESULTS/$model_safe/total_checks"
    echo "$model_total_time" > "$TMPRESULTS/$model_safe/total_time"
    echo "$model_total_size" > "$TMPRESULTS/$model_safe/total_size"
    echo "$model_total_cost" > "$TMPRESULTS/$model_safe/total_cost"
    echo "$model_total_input" > "$TMPRESULTS/$model_safe/total_input_tokens"
    echo "$model_total_output" > "$TMPRESULTS/$model_safe/total_output_tokens"
    echo "$model_total_tokens" > "$TMPRESULTS/$model_safe/total_tokens"

    model_cost_display=$(printf "\$%.4f" "$model_total_cost")
    echo ""
    echo "  Model total: $model_total_pass/$model_total_checks | $(format_time $model_total_time) | $model_cost_display | ${model_total_tokens} tokens"
done

# ── Comparison table ─────────────────────────────────────────────────────────

COMPARISON_FILE="$RESULTS_DIR/comparison_${TIMESTAMP}.txt"

echo ""
echo ""
echo "═══════════════════════════════════════════════════════════════════════════════════════════════════"
echo "  COMPARISON TABLE"
echo "═══════════════════════════════════════════════════════════════════════════════════════════════════"

# Build and print table
print_table() {
    # Header
    local header
    header=$(printf "%-28s" "Model")
    for test_dir in "${TESTS[@]}"; do
        tn=$(basename "$test_dir" | cut -c1-2)
        header="$header | $(printf "%2s" "$tn")"
    done
    header="$header | $(printf "%5s" "Score") | $(printf "%8s" "Time") | $(printf "%8s" "Cost") | $(printf "%9s" "Tokens")"

    echo "$header"
    local divider
    divider=$(printf '%0.s─' $(seq 1 ${#header}))
    echo "$divider"

    for model in "${MODELS[@]}"; do
        model_safe=$(sanitize_name "$model")
        local row
        row=$(printf "%-28s" "$model")

        for test_dir in "${TESTS[@]}"; do
            test_name=$(basename "$test_dir")
            score_file="$TMPRESULTS/$model_safe/${test_name}_score"
            score=0
            [ -f "$score_file" ] && score=$(cat "$score_file")
            row="$row | $(printf "%2s" "$score")"
        done

        total_pass=$(cat "$TMPRESULTS/$model_safe/total_pass" 2>/dev/null || echo 0)
        total_checks=$(cat "$TMPRESULTS/$model_safe/total_checks" 2>/dev/null || echo 0)
        total_time=$(cat "$TMPRESULTS/$model_safe/total_time" 2>/dev/null || echo 0)
        total_cost=$(cat "$TMPRESULTS/$model_safe/total_cost" 2>/dev/null || echo 0)
        total_tokens=$(cat "$TMPRESULTS/$model_safe/total_tokens" 2>/dev/null || echo 0)

        cost_fmt=$(printf "\$%.2f" "$total_cost")

        row="$row | $(printf "%5s" "$total_pass/$total_checks") | $(printf "%8s" "$(format_time $total_time)") | $(printf "%8s" "$cost_fmt") | $(printf "%9s" "${total_tokens}")"
        echo "$row"
    done

    echo "$divider"
}

# Print to terminal and save to file
print_table | tee "$COMPARISON_FILE"

# ── Per-test cost breakdown ──────────────────────────────────────────────────

echo ""
echo "═══════════════════════════════════════════════════════════════════════════════════════════════════"
echo "  COST BREAKDOWN"
echo "═══════════════════════════════════════════════════════════════════════════════════════════════════"

cost_header=$(printf "%-28s" "Model / Test")
cost_header="$cost_header | $(printf "%8s" "Cost") | $(printf "%8s" "Input") | $(printf "%8s" "Output") | $(printf "%10s" "Total Tok.")"
echo "$cost_header"
cost_divider=$(printf '%0.s─' $(seq 1 ${#cost_header}))
echo "$cost_divider"

for model in "${MODELS[@]}"; do
    model_safe=$(sanitize_name "$model")
    echo "$model"

    for test_dir in "${TESTS[@]}"; do
        test_name=$(basename "$test_dir")
        t_cost=$(cat "$TMPRESULTS/$model_safe/${test_name}_cost" 2>/dev/null || echo "0")
        t_input=$(cat "$TMPRESULTS/$model_safe/${test_name}_input_tokens" 2>/dev/null || echo "0")
        t_output=$(cat "$TMPRESULTS/$model_safe/${test_name}_output_tokens" 2>/dev/null || echo "0")
        t_total=$(cat "$TMPRESULTS/$model_safe/${test_name}_total_tokens" 2>/dev/null || echo "0")
        t_score_file="$TMPRESULTS/$model_safe/${test_name}_score"
        t_score=0
        [ -f "$t_score_file" ] && t_score=$(cat "$t_score_file")

        cost_fmt=$(printf "\$%.4f" "$t_cost")
        printf "  %-26s | %8s | %8s | %8s | %10s  (%s/3)\n" "$test_name" "$cost_fmt" "$t_input" "$t_output" "$t_total" "$t_score"
    done

    total_cost=$(cat "$TMPRESULTS/$model_safe/total_cost" 2>/dev/null || echo "0")
    total_input=$(cat "$TMPRESULTS/$model_safe/total_input_tokens" 2>/dev/null || echo "0")
    total_output=$(cat "$TMPRESULTS/$model_safe/total_output_tokens" 2>/dev/null || echo "0")
    total_tokens=$(cat "$TMPRESULTS/$model_safe/total_tokens" 2>/dev/null || echo "0")
    total_cost_fmt=$(printf "\$%.4f" "$total_cost")
    echo "$cost_divider"
    printf "  %-26s | %8s | %8s | %8s | %10s\n" "TOTAL" "$total_cost_fmt" "$total_input" "$total_output" "$total_tokens"
    echo ""
done

# Append cost breakdown to comparison file
{
    echo ""
    echo "COST BREAKDOWN"
    echo "$cost_divider"
    for model in "${MODELS[@]}"; do
        model_safe=$(sanitize_name "$model")
        echo "$model"
        for test_dir in "${TESTS[@]}"; do
            test_name=$(basename "$test_dir")
            t_cost=$(cat "$TMPRESULTS/$model_safe/${test_name}_cost" 2>/dev/null || echo "0")
            t_input=$(cat "$TMPRESULTS/$model_safe/${test_name}_input_tokens" 2>/dev/null || echo "0")
            t_output=$(cat "$TMPRESULTS/$model_safe/${test_name}_output_tokens" 2>/dev/null || echo "0")
            t_total=$(cat "$TMPRESULTS/$model_safe/${test_name}_total_tokens" 2>/dev/null || echo "0")
            t_score_file="$TMPRESULTS/$model_safe/${test_name}_score"
            t_score=0
            [ -f "$t_score_file" ] && t_score=$(cat "$t_score_file")
            cost_fmt=$(printf "\$%.4f" "$t_cost")
            printf "  %-26s | %8s | %8s | %8s | %10s  (%s/3)\n" "$test_name" "$cost_fmt" "$t_input" "$t_output" "$t_total" "$t_score"
        done
        total_cost=$(cat "$TMPRESULTS/$model_safe/total_cost" 2>/dev/null || echo "0")
        total_input=$(cat "$TMPRESULTS/$model_safe/total_input_tokens" 2>/dev/null || echo "0")
        total_output=$(cat "$TMPRESULTS/$model_safe/total_output_tokens" 2>/dev/null || echo "0")
        total_tokens=$(cat "$TMPRESULTS/$model_safe/total_tokens" 2>/dev/null || echo "0")
        total_cost_fmt=$(printf "\$%.4f" "$total_cost")
        echo "$cost_divider"
        printf "  %-26s | %8s | %8s | %8s | %10s\n" "TOTAL" "$total_cost_fmt" "$total_input" "$total_output" "$total_tokens"
        echo ""
    done
} >> "$COMPARISON_FILE"

echo ""
echo "Results saved to: $COMPARISON_FILE"
echo "Detailed logs in: $RESULTS_DIR/*_${TIMESTAMP}/"
