#!/bin/bash
#
# MTサーバーからファイルを同期し、変換・ビルドまで一括実行
#
# Usage:
#   ./scripts/sync-from-server.sh              # フル同期 + ビルド
#   ./scripts/sync-from-server.sh --sync-only  # 同期のみ（ビルドしない）
#   ./scripts/sync-from-server.sh --dry-run    # 確認のみ（ファイル変更なし）
#   ./scripts/sync-from-server.sh --skip-sync  # 同期スキップ（変換+ビルドのみ）
#

set -euo pipefail

# ========== 設定 ==========
REMOTE_USER="as-tetra"
REMOTE_HOST="as-tetra.info"
REMOTE_PATH="/home/as-tetra/www/as-tetra.info"
REMOTE="${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}"

# プロジェクトルート（このスクリプトの親ディレクトリ）
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# ========== オプション解析 ==========
DRY_RUN=false
SYNC_ONLY=false
SKIP_SYNC=false

for arg in "$@"; do
  case $arg in
    --dry-run)   DRY_RUN=true ;;
    --sync-only) SYNC_ONLY=true ;;
    --skip-sync) SKIP_SYNC=true ;;
    -h|--help)
      echo "Usage: $0 [--dry-run] [--sync-only] [--skip-sync]"
      echo ""
      echo "Options:"
      echo "  --dry-run    確認のみ（ファイル変更なし）"
      echo "  --sync-only  サーバー同期のみ（変換・ビルドしない）"
      echo "  --skip-sync  同期スキップ（変換・ビルドのみ実行）"
      exit 0
      ;;
  esac
done

# ========== ユーティリティ ==========
log_step() {
  echo ""
  echo "========================================"
  echo "📌 $1"
  echo "========================================"
}

log_info() {
  echo "   ℹ️  $1"
}

log_ok() {
  echo "   ✅ $1"
}

log_warn() {
  echo "   ⚠️  $1"
}

# ========== rsync 共通オプション ==========
RSYNC_BASE_OPTS="-avz --progress"
if $DRY_RUN; then
  RSYNC_BASE_OPTS="${RSYNC_BASE_OPTS} --dry-run"
fi

# sshpass が使えるか確認
RSYNC_CMD="rsync"
if command -v sshpass &>/dev/null; then
  # 環境変数 RSYNC_PASSWORD があれば sshpass を使用
  if [ -n "${RSYNC_PASSWORD:-}" ]; then
    RSYNC_CMD="sshpass -p '${RSYNC_PASSWORD}' rsync"
    log_info "sshpass を使用（環境変数 RSYNC_PASSWORD）"
  fi
fi

# ========== メイン処理 ==========
cd "$PROJECT_DIR"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  MT → Eleventy 同期 & ビルドスクリプト   ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "リモート: ${REMOTE}"
echo "ローカル: ${PROJECT_DIR}"
if $DRY_RUN; then
  echo "モード:   🔍 DRY RUN（確認のみ）"
elif $SYNC_ONLY; then
  echo "モード:   📥 同期のみ"
elif $SKIP_SYNC; then
  echo "モード:   🔧 変換 + ビルドのみ"
else
  echo "モード:   🚀 フル実行（同期 → 変換 → ビルド）"
fi

# ----------------------------------------
# Step 1: サーバーからファイルを同期
# ----------------------------------------
if ! $SKIP_SYNC; then
  log_step "Step 1/6: MTサーバーからファイルを同期"

  # 1-1. トップページ
  log_info "index.html を同期中..."
  eval $RSYNC_CMD $RSYNC_BASE_OPTS \
    "${REMOTE}/index.html" \
    "${PROJECT_DIR}/index.html"

  # 1-2. archives/（HTML + PHP）
  log_info "archives/ を同期中（HTML + PHP）..."
  eval $RSYNC_CMD $RSYNC_BASE_OPTS \
    --include='*.html' --include='*.php' --include='*/' --exclude='*' \
    "${REMOTE}/archives/" \
    "${PROJECT_DIR}/archives/"

  # 1-3. genre/（HTML + PHP）
  log_info "genre/ を同期中（HTML + PHP）..."
  eval $RSYNC_CMD $RSYNC_BASE_OPTS \
    --include='*.html' --include='*.php' --include='*/' --exclude='*' \
    "${REMOTE}/genre/" \
    "${PROJECT_DIR}/genre/"

  # 1-4. tetra/（HTML + PHP）
  log_info "tetra/ を同期中（HTML + PHP）..."
  eval $RSYNC_CMD $RSYNC_BASE_OPTS \
    --include='*.html' --include='*.php' --include='*/' --exclude='*' \
    "${REMOTE}/tetra/" \
    "${PROJECT_DIR}/tetra/"

  # 1-5. upload/（画像ファイル全て）
  log_info "upload/ を同期中（画像ファイル）..."
  eval $RSYNC_CMD $RSYNC_BASE_OPTS \
    "${REMOTE}/upload/" \
    "${PROJECT_DIR}/upload/"

  # 1-6. cat47/（HTML + PHP）
  log_info "cat47/ を同期中..."
  eval $RSYNC_CMD $RSYNC_BASE_OPTS \
    --include='*.html' --include='*.php' --include='*/' --exclude='*' \
    "${REMOTE}/cat47/" \
    "${PROJECT_DIR}/cat47/" 2>/dev/null || log_warn "cat47/ はリモートに存在しません（スキップ）"

  # 1-7. top/（HTML + PHP）
  log_info "top/ を同期中..."
  eval $RSYNC_CMD $RSYNC_BASE_OPTS \
    --include='*.html' --include='*.php' --include='*/' --exclude='*' \
    "${REMOTE}/top/" \
    "${PROJECT_DIR}/top/" 2>/dev/null || log_warn "top/ はリモートに存在しません（スキップ）"

  log_ok "サーバー同期完了"
fi

if $SYNC_ONLY; then
  echo ""
  echo "✅ 同期完了（--sync-only モード）"
  echo "次のステップ: npm run initial:process"
  exit 0
fi

if $DRY_RUN; then
  echo ""
  echo "🔍 DRY RUN 完了（ファイルは変更されていません）"
  exit 0
fi

# ----------------------------------------
# Step 2: PHP → HTML 変換
# ----------------------------------------
log_step "Step 2/6: PHP → HTML 変換"
node scripts/remove-php-and-rename-index.js --no-backup 2>/dev/null && log_ok "PHP変換完了" || log_warn "PHP変換：対象ファイルなし（スキップ）"

# ----------------------------------------
# Step 3: URL正規化 & 画像width追加
# ----------------------------------------
log_step "Step 3/6: URL正規化"
npm run normalize-urls --silent
log_ok "URL正規化完了"

log_info "img width=\"168\" を追加中..."
npm run add-img-width --silent
log_ok "img width追加完了"

# ----------------------------------------
# Step 4: データ抽出（ページネーション用）
# ----------------------------------------
log_step "Step 4/6: データ抽出（ページネーション用）"

npm run extract-genre-entries --silent
log_ok "ジャンルデータ抽出完了"

npm run extract-archive-entries --silent
log_ok "アーカイブデータ抽出完了"

npm run extract-tetra-entries --silent
log_ok "tetraデータ抽出完了"

# ----------------------------------------
# Step 5: 画像最適化（大きいファイルのみ）
# ----------------------------------------
log_step "Step 5/6: 画像最適化（500KB以上）"
node scripts/optimize-large-images.js 2>/dev/null && log_ok "画像最適化完了" || log_warn "画像最適化：対象ファイルなし（スキップ）"

# ----------------------------------------
# Step 6: ビルド
# ----------------------------------------
log_step "Step 6/6: Eleventy ビルド"
npm run build:local --silent
log_ok "ビルド完了"

# ========== 完了 ==========
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║         🎉 全処理が完了しました！          ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "📌 次のステップ:"
echo "   1. ローカル確認:  npm run serve"
echo "   2. ブラウザで確認: http://localhost:8080/"
echo "   3. コミット:      git add -A && git commit -m '...'"
echo "   4. プッシュ:      git push origin develop"
echo ""
