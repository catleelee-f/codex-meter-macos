#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/outputs/offline-tests"
mkdir -p "$BUILD_DIR/module-cache"
xcrun swiftc -O -swift-version 5 \
  -module-cache-path "$BUILD_DIR/module-cache" \
  "$PROJECT_DIR/source/Models.swift" \
  "$PROJECT_DIR/source/CodexLogScanner.swift" \
  "$PROJECT_DIR/source/CodexAccountUsageClient.swift" \
  "$PROJECT_DIR/tests/offline/main.swift" \
  -o "$BUILD_DIR/tests"
"$BUILD_DIR/tests" "$BUILD_DIR"
