#!/bin/bash
# run_tests.sh — runs both test suites, exits non-zero if any fail
set -uo pipefail

OVERALL=0

run_suite() {
  local script=$1
  bash "/test/$script"
  local rc=$?
  [ $rc -ne 0 ] && OVERALL=1
  return 0
}

run_suite "test_string_match.sh"
echo ""
run_suite "test_with_redirect.sh"
echo ""

if [ $OVERALL -eq 0 ]; then
  echo -e "\033[0;32m══ All test suites passed ══\033[0m"
else
  echo -e "\033[0;31m══ One or more test suites FAILED ══\033[0m"
fi

exit $OVERALL
