#!/bin/bash

set -e

AWK="../awk/core.awk"
PASS=0
FAIL=0

run_test() {
    NAME=$1
    CMD=$2

    echo "Running: $NAME"

    OUTPUT=$(eval "$CMD")
    EXPECTED=$(cat "expected/$NAME.out")

    if diff <(echo "$OUTPUT") <(echo "$EXPECTED") >/dev/null; then
        echo "✅ PASS: $NAME"
        PASS=$((PASS + 1))
    else
        echo "❌ FAIL: $NAME"
        echo "---- Expected ----"
        echo "$EXPECTED"
        echo "---- Got ----"
        echo "$OUTPUT"
        echo "------------------"
        FAIL=$((FAIL + 1))
    fi

    echo
}

if [ $FAIL -eq 0 ]; then
    echo "🎉 ALL TESTS PASSED"
else
    echo "💥 SOME TESTS FAILED"
fi

# ------------------------
# Tests
# ------------------------

run_test "test1" \
    "awk -v mode=match -v pattern=ERROR -f $AWK input/test1.log"

run_test "test2" \
    "awk -v mode=match -v pattern=ERROR -v dedup=1 -f $AWK input/test1.log"

run_test "test3" \
    "awk -v mode=match -v pattern=ERROR -v dedup_strip='[0-9]+' -f $AWK input/test2.log"

run_test "test4" \
    "awk -v mode=block -v start_pattern='^=+' -v end_pattern='^=+' -f $AWK input/test3.log"

run_test "test5" \
    "awk -v mode=block -v start_pattern='^=+' -v end_pattern='^=+' -v dedup=1 -f $AWK input/test3.log"

run_test "test6" \
    "awk -v mode=block -v start_pattern='^=+' -v end_pattern='^=+' -v dedup_strip='[0-9]+' -f $AWK input/test4.log"

run_test "test7" \
    "awk -v mode=count -v pattern=ERROR -f $AWK input/test1.log"

run_test "test8" \
    "awk -v mode=count -v pattern=ERROR -v dedup=1 -f $AWK input/test1.log"

run_test "test9" \
    "awk -v mode=block -v start_pattern='^=+' -v end_pattern='^=+' -v dedup=1 -f $AWK input/test5.log"

run_test "test10" \
    "awk -v mode=block -v start_pattern='^=+' -v end_pattern='^=+' -f $AWK input/test6.log"
# ------------------------

echo "======================"
echo "Passed: $PASS"
echo "Failed: $FAIL"

if [ $FAIL -ne 0 ]; then
    exit 1
fi
