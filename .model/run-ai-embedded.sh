#!/usr/bin/env bash
# ============================================================
# run-ai-embedded.sh
# 使用 llama.cpp 啟動 BGE-M3 嵌入模型伺服器
#
# 服務資訊：
#   - 端點：http://localhost:38000
#   - API：OpenAI 相容（POST /v1/embeddings）
#   - 模型：BGE-M3-Q8_0.gguf
# ============================================================
set -euo pipefail

# ── 設定 ────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODEL_PATH="${SCRIPT_DIR}/BGE-M3-Q8_0.gguf"
HOST="0.0.0.0"
PORT="38000"
CTX_SIZE="512"          # 嵌入模型通常使用較短的上下文
BATCH_SIZE="512"
UBATCH_SIZE="512"
N_GPU_LAYERS="${N_GPU_LAYERS:-999}"   # 盡量全部卸載至 GPU；無 GPU 時設為 0

# ── 顏色輸出 ────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ── 偵測 llama-server 執行檔 ────────────────────────────────
find_llama_server() {
  for cmd in llama-server llama.cpp/llama-server ./llama-server server; do
    if command -v "${cmd}" &>/dev/null; then
      echo "${cmd}"; return 0
    fi
  done
  return 1
}

LLAMA_SERVER=""
if ! LLAMA_SERVER=$(find_llama_server); then
  error "找不到 llama-server，請先安裝 llama.cpp："
  error "  # Ubuntu/Debian（使用預編譯二進位）"
  error "  wget https://github.com/ggml-org/llama.cpp/releases/latest/download/llama-linux-x64.zip"
  error "  unzip llama-linux-x64.zip && sudo cp llama-server /usr/local/bin/"
  error ""
  error "  # 或使用 Homebrew（macOS）"
  error "  brew install llama.cpp"
  exit 1
fi

# ── 檢查模型檔案 ─────────────────────────────────────────────
if [[ ! -f "${MODEL_PATH}" ]]; then
  error "找不到模型檔案：${MODEL_PATH}"
  error "請先執行下載腳本："
  error "  bash ${SCRIPT_DIR}/download-embedded-model.sh"
  exit 1
fi

# ── CPU 執行緒數 ─────────────────────────────────────────────
THREADS=$(nproc 2>/dev/null || sysctl -n hw.logicalcpu 2>/dev/null || echo "4")

# ── 啟動資訊 ─────────────────────────────────────────────────
info "=========================================================="
info " BGE-M3 嵌入模型伺服器"
info "=========================================================="
info "模型    ：${MODEL_PATH}"
info "監聽    ：http://${HOST}:${PORT}"
info "GPU 層  ：${N_GPU_LAYERS}（設為 0 強制使用 CPU）"
info "執行緒  ：${THREADS}"
info "上下文  ：${CTX_SIZE} tokens"
echo ""
info "API 使用範例："
info "  curl http://localhost:${PORT}/v1/embeddings \\"
info "    -H 'Content-Type: application/json' \\"
info "    -d '{\"model\":\"bge-m3\",\"input\":\"知識庫語意搜尋\"}'"
echo ""
warn "按 Ctrl+C 停止服務"
echo ""

# ── 啟動伺服器 ───────────────────────────────────────────────
exec "${LLAMA_SERVER}" \
  --model        "${MODEL_PATH}" \
  --host         "${HOST}" \
  --port         "${PORT}" \
  --ctx-size     "${CTX_SIZE}" \
  --batch-size   "${BATCH_SIZE}" \
  --ubatch-size  "${UBATCH_SIZE}" \
  --threads      "${THREADS}" \
  --n-gpu-layers "${N_GPU_LAYERS}" \
  --embedding \
  --pooling      mean \
  --log-prefix   "[embed] "
