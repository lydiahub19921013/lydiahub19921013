#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
TEST_BINARY="$(mktemp -d)/shuorenhua-prompt-tests"

xcrun swiftc \
  -parse-as-library \
  "$ROOT_DIR/Sources/PromptBuilder.swift" \
  "$ROOT_DIR/Tests/PromptBuilderTests.swift" \
  -o "$TEST_BINARY"

"$TEST_BINARY"

xcrun swiftc -parse-as-library \
  "$ROOT_DIR/Sources/PromptBuilder.swift" \
  "$ROOT_DIR/Sources/BridgeProtocol.swift" \
  "$ROOT_DIR/Tests/BridgeProtocolTests.swift" \
  -o "$TEST_BINARY-bridge"
"$TEST_BINARY-bridge"

xcrun swiftc -parse-as-library \
  "$ROOT_DIR/Sources/ReplyTargetHeuristics.swift" \
  "$ROOT_DIR/Tests/ReplyTargetHeuristicsTests.swift" \
  -o "$TEST_BINARY-target"
"$TEST_BINARY-target"
