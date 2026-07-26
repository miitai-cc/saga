#!/usr/bin/env bash
# ============================================================
# download-llm-model.sh
# 下載 Qwen2.5-14B-Instruct LLM（GGUF 格式）
#
# 模型簡介：
#   - 名稱：Qwen2.5-14B-Instruct（阿里巴巴通義千問）
#   - 參數量：14B（低於 30B 限制）
#   - 語言：優先支援繁體中文、簡體中文與英文
#   - 量化：Q4_K_M（品質與大小的最佳平衡，約 9.0GB）
#   - 上下文：最大 128K tokens
#   - 來源：bartowski/Qwen2.5-14B-Instruct-GGUF（HuggingFace）
#
# 可選其他量化版本（效能 vs 速度取捨）：
#   Q2_K      ~5.0GB  品質最低，速度最快
#   Q4_K_M    ~9.0GB  推薦：品質與大小平衡（預設）
#   Q6_K      ~11.5GB 高品質，佔用較多記憶體
#   Q8_0      ~14.7GB 接近原始品質，需大記憶體
# ============================================================
set -euo pipefail

# ── 設定（可依需求修改量化版本）────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODEL_DIR="${SCRIPT_DIR}"
HF_REPO="bartowski/Qwen2.5-14B-Instruct-GGUF"
MODEL_FILE="${MODEL_FILE:-Qwen2.5-14B-Instruct-Q4_K_M.gguf}"
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
  info "若需下載其他量化版本，可設定 MODEL_FILE 環境變數："
  info "  MODEL_FILE=Qwen2.5-14B-Instruct-Q6_K.gguf bash $0"
  exit 0
fi

info "=========================================================="
info " Qwen2.5-14B-Instruct LLM 下載"
info "=========================================================="
info "目標路徑：${OUTPUT_PATH}"
info "下載來源：${DIRECT_URL}"
warn "檔案大小約 9.0GB（Q4_K_M），請確保磁碟空間充足。"
echo ""

# ── 下載方式選擇 ─────────────────────────────────────────────
mkdir -p "${MODEL_DIR}"

if command -v huggingface-cli &>/dev/null; then
  info "使用 huggingface-cli 下載（支援斷點續傳）..."
  huggingface-cli download "${HF_REPO}" "${MODEL_FILE}" \
    --local-dir "${MODEL_DIR}" \
    --local-dir-use-symlinks False
elif command -v wget &>/dev/null; then
  info "使用 wget 下載（支援斷點續傳，-c）..."
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
  info "啟動方式：bash ${SCRIPT_DIR}/run-llm-model.sh"
  warn "若要啟動，建議記憶體：≥ 16GB RAM 或 GPU VRAM"
else
  error "❌ 下載失敗，請檢查網路連線或手動下載："
  error "  ${DIRECT_URL}"
  exit 1
fi
