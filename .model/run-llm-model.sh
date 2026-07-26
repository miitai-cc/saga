#!/usr/bin/env bash
# ============================================================
# run-llm-model.sh
# 使用 llama.cpp 啟動 Qwen2.5-14B-Instruct LLM 伺服器
#
# 服務資訊：
#   - 端點：http://localhost:38200
#   - API：OpenAI Chat Completions 相容
#         POST /v1/chat/completions
#         POST /v1/completions
#   - 模型：Qwen2.5-14B-Instruct-Q4_K_M.gguf
#
# 環境變數覆蓋：
#   N_GPU_LAYERS=0     強制純 CPU 推論
#   CTX_SIZE=8192      調整上下文視窗大小
#   LLM_PORT=38200     調整監聽端口
#   PARALLEL=4         並行請求數
# ============================================================
set -euo pipefail

# ── 設定 ────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODEL_FILE="${MODEL_FILE:-Qwen2.5-14B-Instruct-Q4_K_M.gguf}"
MODEL_PATH="${SCRIPT_DIR}/${MODEL_FILE}"
HOST="0.0.0.0"
PORT="${LLM_PORT:-38200}"
CTX_SIZE="${CTX_SIZE:-8192}"          # 依記憶體調整，最大支援 131072
BATCH_SIZE="512"
UBATCH_SIZE="512"
N_GPU_LAYERS="${N_GPU_LAYERS:-999}"   # 無 GPU 時設為 0；或設定具體層數如 20
PARALLEL="${PARALLEL:-4}"             # 同時處理的並行請求數
KEEP_CTX="-1"                         # -1 = 保留整個系統提示於 KV Cache

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
  error ""
  error "  # Ubuntu/Debian 預編譯版（CPU）"
  error "  wget https://github.com/ggml-org/llama.cpp/releases/latest/download/llama-linux-x64.zip"
  error "  unzip llama-linux-x64.zip && sudo cp llama-server /usr/local/bin/"
  error ""
  error "  # Ubuntu/Debian 預編譯版（NVIDIA GPU / CUDA）"
  error "  wget https://github.com/ggml-org/llama.cpp/releases/latest/download/llama-linux-x64-cuda12.zip"
  error ""
  error "  # macOS"
  error "  brew install llama.cpp"
  exit 1
fi

# ── 檢查模型檔案 ─────────────────────────────────────────────
if [[ ! -f "${MODEL_PATH}" ]]; then
  error "找不到模型檔案：${MODEL_PATH}"
  error ""
  error "請先執行下載腳本："
  error "  bash ${SCRIPT_DIR}/download-llm-model.sh"
  error ""
  error "或設定 MODEL_FILE 指定其他量化版本："
  error "  MODEL_FILE=Qwen2.5-14B-Instruct-Q6_K.gguf bash $0"
  exit 1
fi

# ── CPU 執行緒數 ─────────────────────────────────────────────
THREADS=$(nproc 2>/dev/null || sysctl -n hw.logicalcpu 2>/dev/null || echo "4")
# 保留 2 個核心給系統，避免完全佔用
THREADS=$(( THREADS > 2 ? THREADS - 2 : THREADS ))

# ── 記憶體使用估算提示 ───────────────────────────────────────
info "=========================================================="
info " Qwen2.5-14B-Instruct LLM 伺服器"
info "=========================================================="
info "模型    ：${MODEL_PATH}"
info "監聽    ：http://${HOST}:${PORT}"
info "GPU 層  ：${N_GPU_LAYERS}（設為 0 強制使用 CPU）"
info "執行緒  ：${THREADS}"
info "上下文  ：${CTX_SIZE} tokens"
info "並行數  ：${PARALLEL} 請求"
echo ""
warn "記憶體需求估算（Q4_K_M）："
warn "  純 CPU：RAM ≥ 16GB（含 OS）"
warn "  混合  ：GPU VRAM 8GB + RAM 8GB"
warn "  全 GPU：VRAM ≥ 10GB（建議 12GB+）"
echo ""
info "API 使用範例（OpenAI 相容）："
info "  curl http://localhost:${PORT}/v1/chat/completions \\"
info "    -H 'Content-Type: application/json' \\"
info "    -d '{"
info "      \"model\": \"qwen2.5-14b\","
info "      \"messages\": [{\"role\":\"user\",\"content\":\"請介紹 SAG 知識庫架構\"}],"
info "      \"stream\": true"
info "    }'"
echo ""
info "在 SAG .env 中使用此 LLM："
info "  SAG_LLM_BASE_URL=http://localhost:${PORT}/v1"
info "  SAG_LLM_API_KEY=not-required"
info "  SAG_LLM_MODEL=qwen2.5-14b"
echo ""
warn "按 Ctrl+C 停止服務"
echo ""

# ── 啟動伺服器 ───────────────────────────────────────────────
exec "${LLAMA_SERVER}" \
  --model          "${MODEL_PATH}" \
  --host           "${HOST}" \
  --port           "${PORT}" \
  --ctx-size       "${CTX_SIZE}" \
  --batch-size     "${BATCH_SIZE}" \
  --ubatch-size    "${UBATCH_SIZE}" \
  --threads        "${THREADS}" \
  --n-gpu-layers   "${N_GPU_LAYERS}" \
  --parallel       "${PARALLEL}" \
  --keep            "${KEEP_CTX}" \
  --flash-attn \
  --cache-type-k   q8_0 \
  --cache-type-v   q8_0 \
  --log-prefix     "[llm] "
