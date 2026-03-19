#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$SCRIPT_DIR/workspace"
TEST_ID="06_file_organizer"

# Check 1: skill_and_script — SKILL.md + companion script + SKILL.md references script
check1=FAIL
if [ -f "$WORKSPACE/SKILL.md" ]; then
    SCRIPT_FILE=$(find "$WORKSPACE" -maxdepth 1 \( -name "*.sh" -o -name "*.py" \) ! -name "SKILL.md" -type f | head -1)
    if [ -n "$SCRIPT_FILE" ]; then
        script_name=$(basename "$SCRIPT_FILE")
        if grep -q "$script_name" "$WORKSPACE/SKILL.md" 2>/dev/null; then
            check1=PASS
        fi
    fi
fi
echo "${TEST_ID}|skill_and_script|${check1}"

# Check 2: organizes_files — run the script on test_dir, check files moved into subdirs
check2=FAIL
if [ -n "${SCRIPT_FILE:-}" ] && [ -d "$WORKSPACE/test_dir" ]; then
    chmod +x "$SCRIPT_FILE" 2>/dev/null
    # Try running with test_dir as argument, or from within test_dir
    (cd "$WORKSPACE" && bash "$SCRIPT_FILE" test_dir 2>/dev/null || bash "$SCRIPT_FILE" "$WORKSPACE/test_dir" 2>/dev/null || python3 "$SCRIPT_FILE" test_dir 2>/dev/null || python3 "$SCRIPT_FILE" "$WORKSPACE/test_dir" 2>/dev/null) || true

    # Count files that ended up in subdirectories (not in test_dir root)
    moved=0
    for f in report.pdf photo.jpg notes.txt data.csv script.py; do
        if find "$WORKSPACE/test_dir" -mindepth 2 -name "$f" 2>/dev/null | grep -q .; then
            moved=$((moved + 1))
        fi
    done
    [ "$moved" -ge 3 ] && check2=PASS
fi
echo "${TEST_ID}|organizes_files|${check2}"

# Check 3: no_data_loss — all 5 files still exist somewhere
check3=FAIL
found=0
for f in report.pdf photo.jpg notes.txt data.csv script.py; do
    if find "$WORKSPACE/test_dir" -name "$f" 2>/dev/null | grep -q .; then
        found=$((found + 1))
    fi
done
[ "$found" -ge 5 ] && check3=PASS
echo "${TEST_ID}|no_data_loss|${check3}"
