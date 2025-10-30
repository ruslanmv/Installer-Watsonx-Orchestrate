#!/usr/bin/env bash
# export.sh — Promote local watsonx Orchestrate assets (tools/ KBs/ agents/) to a cloud env
# Cross‑platform target: macOS/Linux (Bash). Works on Windows via Git Bash/WSL.
#
# Features
# - Activates project venv (if present) and verifies ADK CLI
# - Ensures/creates target cloud environment and activates it with API key
# - Imports in the correct order: tools → knowledge-bases → agents (orchestrator last)
# - Optionally consumes an ADK export bundle ZIP (unzips, then imports parts)
# - Optional deploy of imported agents (from YAML names) after import
# - Dry‑run mode to preview actions
#
# Usage examples
#   bash export.sh --cloud-url https://api.<region>.watson-orchestrate.ibm.com/instances/<id> \
#     --api-key $API_KEY --type ibm_iam --env prod --deploy-all
#
#   bash export.sh --env prod --deploy orchestrator_agent calculator_agent
#
#   bash export.sh --zip agent_bundle.zip --env prod --api-key $API_KEY --deploy-all

set -euo pipefail
shopt -s nullglob

# --------------------------- Colors & helpers ---------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
fail(){ echo -e "${RED}❌ $*${NC}"; exit 1; }
ok(){   echo -e "${GREEN}✅ $*${NC}"; }
info(){ echo -e "${BLUE}ℹ️  $*${NC}"; }
warn(){ echo -e "${YELLOW}⚠️  $*${NC}"; }

# ----------------------------- Args -----------------------------
ENV_NAME="prod"
CLOUD_URL=""
ENV_TYPE="ibm_iam"    # or mcsp
API_KEY=""
ADD_ENV=1              # auto-create env if missing
DRY_RUN=0
ZIP_BUNDLE=""
DEPLOY_ALL=0
DEPLOY_NAMES=()
SKIP_TOOLS=0
SKIP_KBS=0
SKIP_AGENTS=0
AGENTS_GLOB="*.y?(a)ml"   # bash extglob handles .yaml/.yml
TOOLS_GLOB_ALL=("*.py" "*.yaml" "*.yml")
KBS_GLOB_ALL=("*.yaml" "*.yml")

usage(){ cat <<'EOF'
Usage: bash export.sh [options]
  --env <name>            Target environment name (default: prod)
  --cloud-url <url>       Service instance URL (required if env doesn't exist)
  --type <ibm_iam|mcsp>   Environment type (default: ibm_iam)
  --api-key <key>         API key used to activate the cloud env
  --no-add-env            Do not auto-create env if missing
  --zip <bundle.zip>      Use an ADK export bundle (unzips, then imports).
  --deploy-all            Deploy all agents imported from YAMLs
  --deploy <A ...>        Deploy specific agent name(s)
  --skip-tools            Skip tools import
  --skip-kbs              Skip knowledge base import
  --skip-agents           Skip agents import
  --dry-run               Print actions without executing
  -h, --help              Show this help

Examples:
  bash export.sh --cloud-url https://api.<region>.watson-orchestrate.ibm.com/instances/<id> \
    --api-key $API_KEY --type ibm_iam --env prod --deploy-all

  bash export.sh --env prod --deploy orchestrator_agent calculator_agent

  bash export.sh --zip agent_bundle.zip --env prod --api-key $API_KEY --deploy-all
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV_NAME="${2:?missing env name}"; shift 2 ;;
    --cloud-url) CLOUD_URL="${2:?missing url}"; shift 2 ;;
    --type) ENV_TYPE="${2:?missing type}"; shift 2 ;;
    --api-key) API_KEY="${2:?missing api key}"; shift 2 ;;
    --no-add-env) ADD_ENV=0; shift ;;
    --zip) ZIP_BUNDLE="${2:?missing path}"; shift 2 ;;
    --deploy-all) DEPLOY_ALL=1; shift ;;
    --deploy) shift; while [[ $# -gt 0 && "${1:-}" != --* ]]; do DEPLOY_NAMES+=("$1"); shift; done ;;
    --skip-tools) SKIP_TOOLS=1; shift ;;
    --skip-kbs) SKIP_KBS=1; shift ;;
    --skip-agents) SKIP_AGENTS=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown arg: $1 (see --help)" ;;
  esac
done

# ------------------------- Resolve paths -------------------------
SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}" && pwd)"
VENV_DIR="${PROJECT_ROOT}/venv"
TOOLS_DIR="${PROJECT_ROOT}/tools"
KBS_DIR="${PROJECT_ROOT}/knowledge-bases"
AGENTS_DIR="${PROJECT_ROOT}/agents"
DOTENV_FILE="${PROJECT_ROOT}/.env"

# --- Zero-config: read WO_INSTANCE/WO_API_KEY from .env if not provided ---
read_dotenv_key(){
  local key="$1"; local file="$2"
  [[ -f "$file" ]] || return 1
  local line; line=$(grep -E "^${key}=" "$file" | tail -n1 || true)
  [[ -z "$line" ]] && return 1
  local val="${line#*=}"
  # trim simple quotes/spaces
  val="${val%\"}"; val="${val#\"}"
  val="${val% }"; val="${val# }"
  printf '%s' "$val"
}

if [[ -z "$CLOUD_URL" ]]; then
  v=$(read_dotenv_key WO_INSTANCE "$DOTENV_FILE" || true)
  if [[ -n "${v:-}" ]]; then CLOUD_URL="$v"; info "From .env → CLOUD_URL: $CLOUD_URL"; fi
fi
if [[ -z "$API_KEY" ]]; then
  v=$(read_dotenv_key WO_API_KEY "$DOTENV_FILE" || true)
  if [[ -n "${v:-}" ]]; then API_KEY="$v"; info "From .env → API_KEY: ********"; fi
fi

infer_env_type(){
  local url="$1"
  if [[ "$url" == *".cloud.ibm.com"* ]]; then echo "ibm_iam"; return; fi
  if [[ "$url" == *"watson-orchestrate.cloud.ibm.com"* ]]; then echo "ibm_iam"; return; fi
  if [[ "$url" == *"watson-orchestrate.ibm.com"* ]]; then echo "mcsp"; return; fi
  echo "ibm_iam"
}

if [[ -z "$ENV_TYPE" && -n "$CLOUD_URL" ]]; then
  ENV_TYPE="$(infer_env_type "$CLOUD_URL")"
  info "Inferred env type from URL: ${ENV_TYPE}"
fi
info "Project root: ${PROJECT_ROOT}"

# ---------------------- Virtual environment ---------------------
if [[ -d "$VENV_DIR" ]]; then
  echo "📦 Activating virtual environment: ${VENV_DIR}"
  # shellcheck disable=SC1091
  source "${VENV_DIR}/bin/activate"
else
  warn "Virtual environment not found at '${VENV_DIR}'. Proceeding with system Python/CLI."
fi

command -v orchestrate >/dev/null 2>&1 || fail "'orchestrate' CLI not found on PATH. Activate venv or install ADK."

# ---------------------- Dry-run executor ------------------------
run(){
  if (( DRY_RUN )); then
    echo -e "${CYAN}DRY-RUN:${NC} $*"
  else
    eval "$@"
  fi
}

# ---------------------- Env helpers -----------------------------
env_exists(){
  orchestrate env list 2>/dev/null | awk '{print $1}' | grep -Fxq "$ENV_NAME" && return 0 || return 1
}

ensure_env(){
  if env_exists; then
    info "Using existing env: ${ENV_NAME}"
  else
    if (( ADD_ENV )); then
      [[ -n "$CLOUD_URL" ]] || fail "Env '${ENV_NAME}' not found. Provide --cloud-url or create the env manually."
      info "Creating env '${ENV_NAME}' (type=${ENV_TYPE}) → ${CLOUD_URL}"
      run "orchestrate env add -n '${ENV_NAME}' -u '${CLOUD_URL}' --type ${ENV_TYPE} --activate"
    else
      fail "Env '${ENV_NAME}' not found and --no-add-env specified."
    fi
  fi
  # Always activate; pass API key if provided (refresh token)
  if [[ -n "$API_KEY" ]]; then
    run "orchestrate env activate '${ENV_NAME}' --api-key '${API_KEY}'"
  else
    run "orchestrate env activate '${ENV_NAME}'"
  fi
}

# ---------------------- ZIP bundle support ----------------------
TMP_DIR=""
cleanup(){ [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"; }
trap cleanup EXIT

use_zip_if_provided(){
  if [[ -n "$ZIP_BUNDLE" ]]; then
    [[ -f "$ZIP_BUNDLE" ]] || fail "ZIP not found: $ZIP_BUNDLE"
    command -v unzip >/dev/null 2>&1 || fail "'unzip' is required to process --zip bundles"
    TMP_DIR="$(mktemp -d)"
    info "Unzipping bundle → ${TMP_DIR}"
    run "unzip -q '${ZIP_BUNDLE}' -d '${TMP_DIR}'"
    # Repoint directories to the unzipped layout
    [[ -d "${TMP_DIR}/tools" ]] && TOOLS_DIR="${TMP_DIR}/tools"
    [[ -d "${TMP_DIR}/knowledge-bases" ]] && KBS_DIR="${TMP_DIR}/knowledge-bases"
    [[ -d "${TMP_DIR}/agents" ]] && AGENTS_DIR="${TMP_DIR}/agents"
  fi
}

# ---------------------- Import functions ------------------------
import_tools(){
  (( SKIP_TOOLS )) && { warn "Skipping tools import"; return; }
  if [[ ! -d "$TOOLS_DIR" ]]; then
    warn "No tools directory: ${TOOLS_DIR} (skipping)"; return
  fi
  info "Importing tools from ${TOOLS_DIR}"
  local count=0
  (cd "$TOOLS_DIR" && for pattern in "${TOOLS_GLOB_ALL[@]}"; do for f in $pattern; do [[ -f "$f" ]] || continue
      case "$f" in
        *.py)   info "Tool (python): $f"; run "orchestrate tools import -k python -f '${TOOLS_DIR}/$f'" ;;
        *.yml|*.yaml) info "Tool (openapi): $f"; run "orchestrate tools import -k openapi -f '${TOOLS_DIR}/$f'" ;;
        *) warn "Unknown tool file type: $f (skipped)" ;;
      esac
      count=$((count+1))
    done; done)
  (( count > 0 )) && ok "Imported $count tool file(s)" || warn "No matching tool files found"
}

import_kbs(){
  (( SKIP_KBS )) && { warn "Skipping knowledge-bases import"; return; }
  if [[ ! -d "$KBS_DIR" ]]; then
    warn "No knowledge-bases directory: ${KBS_DIR} (skipping)"; return
  fi
  info "Importing knowledge bases from ${KBS_DIR}"
  local count=0
  (cd "$KBS_DIR" && for pattern in "${KBS_GLOB_ALL[@]}"; do for kb in $pattern; do [[ -f "$kb" ]] || continue
      info "KB: $kb"; run "orchestrate knowledge-bases import -f '${KBS_DIR}/$kb'"; count=$((count+1))
    done; done)
  (( count > 0 )) && ok "Imported $count knowledge base file(s)" || warn "No matching KB files found"
}

# Extract agent name from YAML (first 'name:' key at top level)
agent_name_from_yaml(){
  local file="$1"
  # Grep the first 'name:' line that isn't under 'tools:' etc. Assumes simple YAML.
  local line
  line=$(grep -E '^[[:space:]]*name:[[:space:]]*' "$file" | head -n1 || true)
  [[ -z "$line" ]] && echo "" && return 1
  echo "$line" | sed -E 's/^[[:space:]]*name:[[:space:]]*"?([^"#]+)"?.*$/\1/' | tr -d '\r'
}

IMPORTED_AGENT_FILES=()
IMPORTED_AGENT_NAMES=()

import_agents(){
  (( SKIP_AGENTS )) && { warn "Skipping agents import"; return; }
  if [[ ! -d "$AGENTS_DIR" ]]; then
    warn "No agents directory: ${AGENTS_DIR} (skipping)"; return
  fi
  info "Importing agents from ${AGENTS_DIR}"

  # Import everything except orchestrator_* first
  local files=( )
  local orchestrator_file=""
  while IFS= read -r -d '' f; do
    case "$(basename "$f")" in
      orchestrator_*.yml|orchestrator_*.yaml) orchestrator_file="$f" ;;
      *) files+=("$f") ;;
    esac
  done < <(find "$AGENTS_DIR" -maxdepth 1 -type f \( -name '*.yaml' -o -name '*.yml' \) -print0 | sort -z)

  local count=0
  for f in "${files[@]}"; do
    info "Agent: $(basename "$f")"; run "orchestrate agents import -f '$f'"
    IMPORTED_AGENT_FILES+=("$f")
    local nm; nm=$(agent_name_from_yaml "$f" || true)
    [[ -n "$nm" ]] && IMPORTED_AGENT_NAMES+=("$nm")
    count=$((count+1))
  done

  if [[ -n "$orchestrator_file" ]]; then
    info "Agent (orchestrator last): $(basename "$orchestrator_file")"; run "orchestrate agents import -f '$orchestrator_file'"
    IMPORTED_AGENT_FILES+=("$orchestrator_file")
    local nm; nm=$(agent_name_from_yaml "$orchestrator_file" || true)
    [[ -n "$nm" ]] && IMPORTED_AGENT_NAMES+=("$nm")
    count=$((count+1))
  fi

  (( count > 0 )) && ok "Imported $count agent file(s)" || warn "No agent YAMLs found"
}

# ---------------------- Deployment -------------------------------
deploy_agents(){
  local names=()
  if (( DEPLOY_ALL )); then
    names=("${IMPORTED_AGENT_NAMES[@]}")
  elif (( ${#DEPLOY_NAMES[@]} > 0 )); then
    names=("${DEPLOY_NAMES[@]}")
  else
    return
  fi

  if (( ${#names[@]} == 0 )); then
    warn "No agent names available to deploy. Ensure YAML includes 'name:' and/or pass --deploy <names>."
    return
  fi

  info "Deploying agents: ${names[*]}"
  local okc=0
  for n in "${names[@]}"; do
    run "orchestrate agents deploy -n '$n'" && okc=$((okc+1)) || warn "Deploy failed: $n"
  done
  ok "Deployment attempted for ${#names[@]} agent(s); success: ${okc}"
}

# ---------------------- Main -------------------------------
main(){
  info "Target environment: ${ENV_NAME}"
  ensure_env
  use_zip_if_provided
  import_tools
  import_kbs
  import_agents
  deploy_agents
  echo
  info "Done. You can verify with: 'orchestrate agents list -v'"
}

main "$@"
