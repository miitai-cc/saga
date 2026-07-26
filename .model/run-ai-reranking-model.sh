#!/usr/bin/env bash
# ============================================================
# run-ai-reranking-model.sh
# 使用 llama.cpp 啟動 BGE-Reranker-v2-M3 重排序模型伺服器
#
# 服務資訊：
#   - 端點：http://localhost:38100
#   - API：POST /v1/reranking（llama.cpp 原生）
#   - 模型：bge-reranker-v2-m3-Q8_0.gguf
# ============================================================
set -euo pipefail

# ── 設定 ────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODEL_PATH="${SCRIPT_DIR}/bge-reranker-v2-m3-Q8_0.gguf"
HOST="0.0.0.0"
PORT="38100"
CTX_SIZE="512"
BATCH_SIZE="512"
UBATCH_SIZE="512"
N_GPU_LAYERS="${N_GPU_LAYERS:-999}"   # 無 GPU 時設為 0

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
  error "  wget https://github.com/ggml-org/llama.cpp/releases/latest/download/llama-linux-x64.zip"
  error "  unzip llama-linux-x64.zip && sudo cp llama-server /usr/local/bin/"
  exit 1
fi

# ── 檢查模型檔案 ─────────────────────────────────────────────
if [[ ! -f "${MODEL_PATH}" ]]; then
  error "找不到模型檔案：${MODEL_PATH}"
  error "請先執行下載腳本："
  error "  bash ${SCRIPT_DIR}/download-reranking-model.sh"
  exit 1
fi

# ── CPU 執行緒數 ─────────────────────────────────────────────
THREADS=$(nproc 2>/dev/null || sysctl -n hw.logicalcpu 2>/dev/null || echo "4")

# ── 啟動資訊 ─────────────────────────────────────────────────
info "=========================================================="
info " BGE-Reranker-v2-M3 重排序模型伺服器"
info "=========================================================="
info "模型    ：${MODEL_PATH}"
info "監聽    ：http://${HOST}:${PORT}"
info "GPU 層  ：${N_GPU_LAYERS}（設為 0 強制使用 CPU）"
info "執行緒  ：${THREADS}"
echo ""
info "API 使用範例："
info "  curl http://localhost:${PORT}/v1/reranking \\"
info "    -H 'Content-Type: application/json' \\"
info "    -d '{"
info "      \"model\": \"bge-reranker-v2-m3\","
info "      \"query\": \"什麼是 SAG 架構？\","
info "      \"documents\": ["
info "        \"SAG 使用事件–實體索引進行知識檢索\","
info "        \"傳統 RAG 使用向量相似度\"
info "      ]"
info "    }'"
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
  --reranking \
  --log-prefix   "[rerank] "
