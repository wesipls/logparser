#!/bin/bash

set -e

echo "Running tests..."

awk -v mode="match" -v pattern="ERROR" -f core.awk test1.log
awk -v mode="match" -v pattern="ERROR" -v dedup=1 -f core.awk test1.log
awk -v mode="match" -v pattern="ERROR" -v dedup_strip="[0-9]+" -f core.awk test2.log

awk -v mode="block" -v start_pattern="^=+" -v end_pattern="^=+" -f core.awk test3.log
awk -v mode="block" -v start_pattern="^=+" -v end_pattern="^=+" -v dedup=1 -f core.awk test3.log

echo "All tests ran."
