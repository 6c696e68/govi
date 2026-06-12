#!/bin/bash
# Chạy test engine: biên dịch engine + runner, so với golden file tĩnh.
set -euo pipefail
cd "$(dirname "$0")/.."

TMP="$(mktemp -d)"
cp test/run_tests.swift "$TMP/main.swift"   # top-level code phải ở main.swift
swiftc -O Sources/Engine/*.swift "$TMP/main.swift" -o "$TMP/govitest"
"$TMP/govitest" test/golden.tsv
