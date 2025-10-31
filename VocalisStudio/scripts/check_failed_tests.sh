#!/usr/bin/env bash
# 失敗テストを即座に確認するスクリプト

set -euo pipefail

PROJECT="VocalisStudio.xcodeproj"
SCHEME="VocalisStudio"
DEVICE="iPhone 16"

cd "$(dirname "$0")/.."

echo "🧪 テスト実行中..."
echo ""

# テスト実行して失敗テストのみ抽出
xcodebuild test \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  -allowProvisioningUpdates \
  2>&1 | tee /tmp/test_output.txt | \
  grep --line-buffered -E "(Test Case.*failed|Testing failed)" || true

echo ""
echo "📊 サマリー:"
echo "----------------------------------------"

# 失敗テスト数をカウント
FAILED_COUNT=$(grep -c "Test Case.*failed" /tmp/test_output.txt || echo "0")
TOTAL_TESTS=$(grep -c "Test Case.*started" /tmp/test_output.txt || echo "0")

echo "失敗: $FAILED_COUNT / $TOTAL_TESTS テスト"
echo ""

if [ "$FAILED_COUNT" -gt 0 ]; then
    echo "❌ 失敗テスト一覧:"
    grep "Test Case.*failed" /tmp/test_output.txt | \
      sed -E "s/Test case '(.*)' failed.*/  - \1/" | \
      sort -u
    exit 1
else
    echo "✅ 全テストパス"
    exit 0
fi
