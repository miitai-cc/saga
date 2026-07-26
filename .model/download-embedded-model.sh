#!/usr/bin/env bash
# ============================================================
# download-embedded-model.sh
# 下載 BAAI/BGE-M3 多語言嵌入模型（GGUF 格式）
#
# 模型簡介：
#   - 名稱：BGE-M3
#   - 參數量：~570M（遠低於 4B 限制）
#   - 語言：支援 100+ 語言，含繁體中文
#   - 能力：密集向量 + 稀疏向量 + 多向量（ColBERT）
#   - 量化：Q8_0（品質最佳，約 591MB）
#   - 來源：second-state/BGE-M3-GGUF（HuggingFace）
# ============================================================
set -euo pipefail

# ── 設定 ────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODEL_DIR="${SCRIPT_DIR}"
HF_REPO="second-state/BGE-M3-GGUF"
MODEL_FILE="BGE-M3-Q8_0.gguf"
OUTPUT_PATH="${MODEL_DIR}/${MODEL_FILE}"
HF_BASE="https://hf-mirror.com"
DIRECT_URL="${HF_BASE}/${HF_REPO}/resolve/main/${MODEL_FILE}"

# ── 顏色輸出 ────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ── 檢查是否已存在 ───────────────────────────────────────────
if [[ -f "${OUTPUT_PATH}" ]]; then
  info "模型已存在：${OUTPUT_PATH}"
  info "若需重新下載，請先刪除該檔案後再執行本腳本。"
  exit 0
fi

info "=========================================================="
info " BGE-M3 嵌入模型下載"
info "=========================================================="
info "目標路徑：${OUTPUT_PATH}"
info "下載來源：${DIRECT_URL}"
echo ""

# ── 下載方式選擇 ─────────────────────────────────────────────
mkdir -p "${MODEL_DIR}"

if command -v huggingface-cli &>/dev/null; then
  info "使用 huggingface-cli 下載（支援斷點續傳）..."
  huggingface-cli download "${HF_REPO}" "${MODEL_FILE}" \
    --local-dir "${MODEL_DIR}" \
    --local-dir-use-symlinks False
elif command -v wget &>/dev/null; then
  info "使用 wget 下載..."
  wget --continue \
       --show-progress \
       --progress=bar:force \
       -O "${OUTPUT_PATH}" \
       "${DIRECT_URL}"
elif command -v curl &>/dev/null; then
  info "使用 curl 下載..."
  curl -L --continue-at - \
       --progress-bar \
       -o "${OUTPUT_PATH}" \
       "${DIRECT_URL}"
else
  error "找不到下載工具，請安裝以下任一工具："
  error "  pip install huggingface_hub  （推薦，支援斷點續傳）"
  error "  sudo apt install wget"
  exit 1
fi

# ── 驗證 ────────────────────────────────────────────────────
if [[ -f "${OUTPUT_PATH}" ]]; then
  SIZE=$(du -sh "${OUTPUT_PATH}" | cut -f1)
  info "✅ 下載完成！檔案大小：${SIZE}"
  info "模型路徑：${OUTPUT_PATH}"
  echo ""
  info "啟動方式：bash ${SCRIPT_DIR}/run-ai-embedded.sh"
else
  error "❌ 下載失敗，請檢查網路連線或手動下載："
  error "  ${DIRECT_URL}"
  exit 1
fi
