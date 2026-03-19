#!/bin/bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$SCRIPT_DIR/workspace"
FIXTURES="$SCRIPT_DIR/fixtures"
TEST_ID="04_bugfix_existing_code"

# If workspace doesn't have task_manager.py, the model never got to run — fail all
if [ ! -f "$WORKSPACE/task_manager.py" ]; then
    echo "${TEST_ID}|runs_without_error|FAIL"
    echo "${TEST_ID}|bug_fixed_correctly|FAIL"
    echo "${TEST_ID}|didnt_break_other_features|FAIL"
    exit 0
fi

# Work in a temp directory so we don't mutate workspace between checks
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT
cp "$WORKSPACE/task_manager.py" "$TMPDIR/"
cp "$FIXTURES/tasks.json" "$TMPDIR/tasks.json"

# ─── Check 1: runs_without_error ──────────────────────────────────────────────
# Completing a task should not crash (the original code throws KeyError on list)
OUTPUT=$(cd "$TMPDIR" && python3 task_manager.py complete 1 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    # Now also verify that listing doesn't crash (the KeyError on completed_at)
    LIST_OUTPUT=$(cd "$TMPDIR" && python3 task_manager.py list 2>&1)
    LIST_EXIT=$?
    if [ $LIST_EXIT -eq 0 ]; then
        echo "${TEST_ID}|runs_without_error|PASS"
    else
        echo "${TEST_ID}|runs_without_error|FAIL"
    fi
else
    echo "${TEST_ID}|runs_without_error|FAIL"
fi

# ─── Check 2: bug_fixed_correctly ─────────────────────────────────────────────
# After completing task 1, it should actually be marked as completed.
# We check two things:
#   a) tasks.json has completed as boolean true (not the string "True")
#   b) list output shows some completed indicator for task 1

# Reset tasks.json for a clean run
cp "$FIXTURES/tasks.json" "$TMPDIR/tasks.json"

cd "$TMPDIR" && python3 task_manager.py complete 1 >/dev/null 2>&1

# Check tasks.json — completed should be boolean true, not string "True"
COMPLETED_VAL=$(python3 -c "
import json
with open('$TMPDIR/tasks.json') as f:
    tasks = json.load(f)
for t in tasks:
    if t['id'] == 1:
        # Check it's a real boolean True, not the string 'True'
        if t['completed'] is True:
            print('BOOL_TRUE')
        elif t['completed'] == 'True':
            print('STRING_TRUE')
        else:
            print('OTHER')
        break
" 2>/dev/null)

if [ "$COMPLETED_VAL" = "BOOL_TRUE" ]; then
    echo "${TEST_ID}|bug_fixed_correctly|PASS"
else
    echo "${TEST_ID}|bug_fixed_correctly|FAIL"
fi

# ─── Check 3: didnt_break_other_features ──────────────────────────────────────
# Adding a task and listing should work correctly
cp "$FIXTURES/tasks.json" "$TMPDIR/tasks.json"

ADD_OUTPUT=$(cd "$TMPDIR" && python3 task_manager.py add "New task" 2>&1)
ADD_EXIT=$?

LIST_OUTPUT=$(cd "$TMPDIR" && python3 task_manager.py list 2>&1)
LIST_EXIT=$?

if [ $ADD_EXIT -eq 0 ] && [ $LIST_EXIT -eq 0 ] && echo "$LIST_OUTPUT" | grep -qi "New task"; then
    echo "${TEST_ID}|didnt_break_other_features|PASS"
else
    echo "${TEST_ID}|didnt_break_other_features|FAIL"
fi
