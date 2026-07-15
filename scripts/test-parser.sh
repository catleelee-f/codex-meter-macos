#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/outputs/test-build"
MODULE_CACHE_DIR="$BUILD_DIR/module-cache"
TEST_CACHE_DIR="$BUILD_DIR/cache"

mkdir -p "$BUILD_DIR" "$MODULE_CACHE_DIR" "$TEST_CACHE_DIR"

CLANG_MODULE_CACHE_PATH="$MODULE_CACHE_DIR" \
SWIFT_MODULE_CACHE_PATH="$MODULE_CACHE_DIR" \
xcrun swiftc \
  -O \
  -swift-version 5 \
  -target arm64-apple-macos13.0 \
  -module-cache-path "$MODULE_CACHE_DIR" \
  "$PROJECT_DIR/source/Models.swift" \
  "$PROJECT_DIR/source/CodexLogScanner.swift" \
  "$PROJECT_DIR/tests/main.swift" \
  -o "$BUILD_DIR/parser-smoke-test"

CODEX_METER_CACHE_DIR="$TEST_CACHE_DIR" \
  "$BUILD_DIR/parser-smoke-test"
