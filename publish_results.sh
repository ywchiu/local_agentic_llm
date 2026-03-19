#!/bin/bash
set -uo pipefail

# Generate a publishable experiment report from benchmark results.
# Usage: ./publish_results.sh "experiment name" [group]
# Example: ./publish_results.sh "2026-03-19 Python Fundamentals v1" group1_python_fundamentals

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results"

EXPERIMENT_NAME="${1:-}"
GROUP="${2:-all}"
DATE=$(date +%Y-%m-%d)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

if [ -z "$EXPERIMENT_NAME" ]; then
    echo "Usage: $0 \"experiment name\" [group]"
    echo "Example: $0 \"2026-03-19 Python Fundamentals v1\" group1_python_fundamentals"
    exit 1
fi

# Sanitize experiment name for directory
EXP_DIR_NAME=$(echo "$EXPERIMENT_NAME" | sed 's/[^a-zA-Z0-9._-]/_/g')
EXP_DIR="$RESULTS_DIR/experiments/${DATE}_${EXP_DIR_NAME}"
mkdir -p "$EXP_DIR"

echo "Publishing experiment: $EXPERIMENT_NAME"
echo "Output: $EXP_DIR"
echo ""

# Find the latest raw result directories (per model)
RAW_DIR="$RESULTS_DIR/raw"
if [ ! -d "$RAW_DIR" ]; then
    # Fall back to results root for backward compat
    RAW_DIR="$RESULTS_DIR"
fi

# Collect all model result directories
MODEL_DIRS=()
for dir in "$RESULTS_DIR"/openrouter_*/ "$RAW_DIR"/openrouter_*/; do
    [ -d "$dir" ] && MODEL_DIRS+=("$dir")
done

if [ ${#MODEL_DIRS[@]} -eq 0 ]; then
    echo "Error: No result directories found in $RESULTS_DIR or $RAW_DIR"
    exit 1
fi

# Generate clean report
REPORT="$EXP_DIR/report.md"
{
    echo "# Experiment: $EXPERIMENT_NAME"
    echo ""
    echo "**Date:** $DATE"
    echo "**Group:** $GROUP"
    echo "**Generated:** $(date)"
    echo ""
    echo "## Results"
    echo ""
    echo "| Model | Score | Time | Cost | Tokens |"
    echo "|-------|-------|------|------|--------|"

    for model_dir in "${MODEL_DIRS[@]}"; do
        model_name=$(basename "$model_dir" | sed 's/_[0-9]\{8\}_[0-9]\{6\}$//' | sed 's/_/\//g')

        total_score=0
        total_checks=0
        total_time=0
        total_cost="0"
        total_tokens=0
        has_data=false

        for result_file in "$model_dir"/*_result.txt; do
            [ -f "$result_file" ] || continue
            has_data=true

            score=$(grep "^score:" "$result_file" | head -1 | sed 's/score: //' | cut -d/ -f1)
            checks=$(grep "^score:" "$result_file" | head -1 | sed 's/score: //' | cut -d/ -f2)
            time=$(grep "^time:" "$result_file" | head -1 | sed 's/time: //' | sed 's/s$//')
            cost=$(grep "^cost:" "$result_file" | head -1 | sed 's/cost: //')
            tokens=$(grep "^total_tokens:" "$result_file" | head -1 | sed 's/total_tokens: //')

            total_score=$((total_score + ${score:-0}))
            total_checks=$((total_checks + ${checks:-3}))
            total_time=$((total_time + ${time:-0}))
            total_cost=$(echo "$total_cost + ${cost:-0}" | bc 2>/dev/null || echo "$total_cost")
            total_tokens=$((total_tokens + ${tokens:-0}))
        done

        if [ "$has_data" = true ]; then
            # Format time
            if [ "$total_time" -ge 60 ]; then
                time_fmt="${total_time}s ($((total_time/60))m $((total_time%60))s)"
            else
                time_fmt="${total_time}s"
            fi
            cost_fmt=$(printf "\$%.2f" "$total_cost")
            token_fmt="${total_tokens}"

            echo "| $model_name | $total_score/$total_checks | $time_fmt | $cost_fmt | $token_fmt |"
        fi
    done

    echo ""
    echo "## Per-Test Detail"
    echo ""

    for model_dir in "${MODEL_DIRS[@]}"; do
        model_name=$(basename "$model_dir" | sed 's/_[0-9]\{8\}_[0-9]\{6\}$//' | sed 's/_/\//g')
        has_results=false

        for result_file in "$model_dir"/*_result.txt; do
            [ -f "$result_file" ] || continue
            has_results=true
            break
        done

        [ "$has_results" = false ] && continue

        echo "### $model_name"
        echo ""
        echo "| Test | Score | Time | Cost | Tokens |"
        echo "|------|-------|------|------|--------|"

        for result_file in "$model_dir"/*_result.txt; do
            [ -f "$result_file" ] || continue
            test=$(grep "^test:" "$result_file" | sed 's/test: //')
            score=$(grep "^score:" "$result_file" | sed 's/score: //')
            time=$(grep "^time:" "$result_file" | sed 's/time: //')
            cost=$(grep "^cost:" "$result_file" | sed 's/cost: //')
            tokens=$(grep "^total_tokens:" "$result_file" | sed 's/total_tokens: //')
            timed_out=$(grep "^timed_out:" "$result_file" | sed 's/timed_out: //')

            cost_fmt=$(printf "\$%.4f" "${cost:-0}")
            timeout_flag=""
            [ "$timed_out" = "yes" ] && timeout_flag=" (timeout)"

            echo "| $test | $score | ${time}${timeout_flag} | $cost_fmt | ${tokens:-0} |"
        done
        echo ""
    done

} > "$REPORT"

# Copy comparison files if they exist
for cmp in "$RESULTS_DIR"/comparison_*.txt; do
    [ -f "$cmp" ] && cp "$cmp" "$EXP_DIR/" 2>/dev/null
done

echo "Report generated: $REPORT"
echo ""
echo "To commit:"
echo "  git add $EXP_DIR"
echo "  git commit -m 'Add experiment results: $EXPERIMENT_NAME'"
