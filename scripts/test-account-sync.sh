#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/outputs/test-build"
MODULE_CACHE_DIR="$BUILD_DIR/module-cache-account"

mkdir -p "$BUILD_DIR" "$MODULE_CACHE_DIR"

CLANG_MODULE_CACHE_PATH="$MODULE_CACHE_DIR" \
SWIFT_MODULE_CACHE_PATH="$MODULE_CACHE_DIR" \
xcrun swiftc \
  -O \
  -swift-version 5 \
  -target arm64-apple-macos13.0 \
  -module-cache-path "$MODULE_CACHE_DIR" \
  "$PROJECT_DIR/source/Models.swift" \
  "$PROJECT_DIR/source/CodexAccountUsageClient.swift" \
  "$PROJECT_DIR/tests/account-sync.swift" \
  -o "$BUILD_DIR/account-sync-probe"

"$BUILD_DIR/account-sync-probe"
