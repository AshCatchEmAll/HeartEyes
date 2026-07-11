#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

mkdir -p build
echo "› Compiling tests…"
swiftc -swift-version 5 \
  -target arm64-apple-macos13.0 \
  Sources/RestLedger.swift \
  Tests/RestLedgerTests.swift \
  -o build/ledger-tests

echo "› Running…"
echo ""
./build/ledger-tests
