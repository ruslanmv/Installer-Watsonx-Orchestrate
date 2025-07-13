#!/usr/bin/env bash
# ┌────────────────────────────────────────────────────────────────────────────┐
# │                                                                            │
# │ ██╗    ██╗ █████╗ ████████╗███████╗ ██████╗ ███╗   ██╗██╗  ██╗             │
# │ ██║    ██║██╔══██╗╚══██╔══╝██╔════╝██╔═══██╗████╗  ██║╚██╗██╔╝             │
# │ ██║ █╗ ██║███████║   ██║   ███████╗██║   ██║██╔██╗ ██║ ╚███╔╝              │
# │ ██║███╗██║██╔══██║   ██║   ╚════██║██║   ██║██║╚██╗██║ ██╔██╗              │
# │ ╚███╔███╔╝██║  ██║   ██║   ███████║╚██████╔╝██║ ╚████║██╔╝ ██╗             │
# │  ╚══╝╚══╝ ╚═╝  ╚═╝   ╚═╝   ╚══════╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═╝             │
# │                                                                            │
# │            watsonx Orchestrate  DEV EDITION  by ruslanmv.com               │
# └────────────────────────────────────────────────────────────────────────────┘
#
#
# Installs a chosen STABLE version of IBM watsonx Orchestrate ADK in an
# isolated Python virtual-environment.

set -euo pipefail

# --- MODIFICATION 1: Accept the installation directory from the parent script ---
INSTALL_ROOT="$1"

# Exit if the installation directory was not provided.
if [ -z "$INSTALL_ROOT" ]; then
  echo "❌ Error: This script requires an installation root directory as an argument." >&2
  exit 1
fi


# ── Blue runtime logo ────────────────────────────────────────────────────────
print_logo() {
  local BLUE="\033[1;34m"; local NC="\033[0m"
  echo -e "${BLUE}"
  cat <<'EOF'
                _
               | |
 _ __ _   _ ___| | __ _ _ __   _ __ _____   __
| '__| | | / __| |/ _` | '_ \| '_ ` _ \ \ / /
| |  | |_| \__ \ | (_| | | | | | | | | \ V /
|_|   \__,_|___/_|\__,_|_| |_|_| |_| |_|\_/

EOF
  echo -e "${NC}"
}

print_logo

# ────────────────────────────────────────────────────────────────────────────
#  Pre-flight: Verify local tooling
# ────────────────────────────────────────────────────────────────────────────
command -v docker >/dev/null \
  || { echo "❌ Docker not installed. Please install Docker first."; exit 1; }

if ! docker compose version 2>/dev/null | grep -q 'v2\.'; then
  echo "❌ Docker Compose v2 missing. Please upgrade to Compose v2."; exit 1
fi

if ! command -v ifconfig >/dev/null; then
  echo "ℹ️  'ifconfig' not found (package net-tools). IP auto-detect will fall back to other methods."
fi

# ────────────────────────────────────────────────────────────────────────────
#  Config
# ────────────────────────────────────────────────────────────────────────────
ADK_VERSIONS=( "1.5.0" "1.5.1" "1.6.0" "1.6.1" "1.6.2" )
# --- MODIFICATION 2: Make paths dynamic using INSTALL_ROOT ---
ENV_FILE="${INSTALL_ROOT}/.env"
VENV_DIR="${INSTALL_ROOT}/venv"
ADK_VERSION=""
ACCOUNT_TYPE=""

# ────────────────────────────────────────────────────────────────────────────
#  Load .env *before* anything else
# ────────────────────────────────────────────────────────────────────────────
[[ -f "$ENV_FILE" ]] || { echo "❌ .env not found at ${ENV_FILE}"; exit 1; }
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

# ────────────────────────────────────────────────────────────────────────────
#  Detect account type based on WO_DEVELOPER_EDITION_SOURCE
# ────────────────────────────────────────────────────────────────────────────
if [[ "${WO_DEVELOPER_EDITION_SOURCE:-}" == "orchestrate" ]]; then
  ACCOUNT_TYPE="orchestrate"
elif [[ "${WO_DEVELOPER_EDITION_SOURCE:-}" == "myibm" ]]; then
  ACCOUNT_TYPE="watsonx.ai"
else
  echo "❌ WO_DEVELOPER_EDITION_SOURCE is not set or has an invalid value in .env." >&2
  echo "   It must be either 'orchestrate' or 'myibm'." >&2
  exit 1
fi
echo "🔍 Detected account source: ${WO_DEVELOPER_EDITION_SOURCE} (Account Type: ${ACCOUNT_TYPE})"


# ────────────────────────────────────────────────────────────────────────────
#  Validate required keys
# ────────────────────────────────────────────────────────────────────────────
if [[ "$ACCOUNT_TYPE" == "orchestrate" ]]; then
  for V in WO_DEVELOPER_EDITION_SOURCE WO_INSTANCE WO_API_KEY; do
    [[ -n "${!V:-}" ]] || { echo "❌ $V is missing in .env for 'orchestrate' source."; exit 1; }
  done
else # watsonx.ai
  for V in WO_DEVELOPER_EDITION_SOURCE WO_ENTITLEMENT_KEY WATSONX_APIKEY WATSONX_SPACE_ID; do
    [[ -n "${!V:-}" ]] || { echo "❌ $V is missing in .env for 'myibm' source."; exit 1; }
  done
fi

# ────────────────────────────────────────────────────────────────────────────
#  Setup Python virtual-environment & ADK
# ────────────────────────────────────────────────────────────────────────────
# --- MODIFICATION 3: Use the dynamic $VENV_DIR variable everywhere ---
if [[ -d "$VENV_DIR" ]]; then
  echo "📦 Found existing venv at ${VENV_DIR}. Activating…"
  # shellcheck disable=SC1091
  source "${VENV_DIR}/bin/activate"
  echo "🔧 Python $(python --version)"
  ADK_VERSION=$(pip show ibm-watsonx-orchestrate 2>/dev/null \
                | awk '/^Version:/{print $2}')
  [[ -z "$ADK_VERSION" ]] && echo "⚠️  Could not detect installed ADK version."
else
  echo "📦 Creating venv in ${VENV_DIR}…"
  python3.11 -m venv "$VENV_DIR"
  # shellcheck disable=SC1091
  source "${VENV_DIR}/bin/activate"
  echo "🔧 Python $(python --version)"

  echo; echo "Available ADK versions:"
  for i in "${!ADK_VERSIONS[@]}"; do
    printf "   %2d) %s\n" $((i+1)) "${ADK_VERSIONS[$i]}"
  done
  read -rp "Select ADK version number: " IDX
  [[ "$IDX" =~ ^[0-9]+$ && "$IDX" -ge 1 && "$IDX" -le "${#ADK_VERSIONS[@]}" ]] \
    || { echo "❌ Invalid version."; exit 1; }
  ADK_VERSION="${ADK_VERSIONS[$((IDX-1))]}"
  echo "📦 Installing ibm-watsonx-orchestrate==$ADK_VERSION …"
  pip install --quiet --upgrade "ibm-watsonx-orchestrate==$ADK_VERSION"
fi

# ────────────────────────────────────────────────────────────────────────────
#  Done
# ────────────────────────────────────────────────────────────────────────────
echo
if [[ -n "$ADK_VERSION" ]]; then
  echo "✅  Environment setup for ADK v$ADK_VERSION is complete."
else
  echo "✅  Environment setup is complete."
fi
# --- MODIFICATION 4: Update final instruction ---
echo "   You can now activate the venv with 'source \"${VENV_DIR}/bin/activate\"' and run the server."
echo "   Happy building — ruslanmv.com 🚀"