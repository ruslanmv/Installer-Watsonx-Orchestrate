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

# Accept installation directory or default to the current directory
INSTALL_ROOT="${1:-$(pwd)}"

# --- Helper Functions ---

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

# --- FIX: Extracted ADK installation logic into a reusable function ---

install_adk() {
  echo
  echo "Available ADK versions:"
  for i in "${!ADK_VERSIONS[@]}"; do
    printf "   %2d) %s\n" $((i+1)) "${ADK_VERSIONS[$i]}"
  done

  local input
  read -rp "Select ADK version number (1-${#ADK_VERSIONS[@]}) or type version (e.g. ${ADK_VERSIONS[-1]}): " input

  # Direct match of a version string?
  if printf '%s\n' "${ADK_VERSIONS[@]}" | grep -qx -- "$input"; then
    ADK_VERSION="$input"

  # Numeric index into the array?
  elif [[ "$input" =~ ^[0-9]+$ ]] \
        && (( input >= 1 && input <= ${#ADK_VERSIONS[@]} )); then
    ADK_VERSION="${ADK_VERSIONS[$((input-1))]}"

  else
    echo "❌ Invalid selection. No installation performed."
    ADK_VERSION=""  # clear out on error
    return
  fi

  echo "📦 Installing ibm-watsonx-orchestrate==$ADK_VERSION …"
  pip install --upgrade "ibm-watsonx-orchestrate==$ADK_VERSION"
}



# --- Main Script ---
# Pre-flight: Verify local tooling
command -v docker >/dev/null \
  || { echo "❌ Docker not installed. Please install Docker first."; exit 1; }

if ! docker compose version 2>/dev/null | grep -q 'v2\.'; then
  echo "❌ Docker Compose v2 missing. Please upgrade to Compose v2."; exit 1
fi

# Config
ADK_VERSIONS=( "1.5.0" "1.5.1" "1.6.0" "1.6.1" "1.6.2" "1.7.0" )
ENV_FILE="${INSTALL_ROOT}/.env"
VENV_DIR="${INSTALL_ROOT}/venv"
ADK_VERSION=""
ACCOUNT_TYPE=""

# Load .env
[[ -f "$ENV_FILE" ]] || { echo "❌ .env not found at ${ENV_FILE}"; exit 1; }
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

# Detect account type
if [[ "${WO_DEVELOPER_EDITION_SOURCE:-}" == "orchestrate" ]]; then
  ACCOUNT_TYPE="orchestrate"
elif [[ "${WO_DEVELOPER_EDITION_SOURCE:-}" == "myibm" ]]; then
  ACCOUNT_TYPE="watsonx.ai"
else
  echo "❌ WO_DEVELOPER_EDITION_SOURCE is not set or has an invalid value in .env." >&2
  exit 1
fi
echo "🔍 Detected account source: ${WO_DEVELOPER_EDITION_SOURCE} (Account Type: ${ACCOUNT_TYPE})"

# Validate required keys
if [[ "$ACCOUNT_TYPE" == "orchestrate" ]]; then
  for V in WO_DEVELOPER_EDITION_SOURCE WO_INSTANCE WO_API_KEY; do
    [[ -n "${!V:-}" ]] || { echo "❌ $V is missing in .env for 'orchestrate' source."; exit 1; }
  done
else # watsonx.ai
  for V in WO_DEVELOPER_EDITION_SOURCE WO_ENTITLEMENT_KEY WATSONX_APIKEY WATSONX_SPACE_ID; do
    [[ -n "${!V:-}" ]] || { echo "❌ $V is missing in .env for 'myibm' source."; exit 1; }
  done
fi

# Setup Python virtual-environment & ADK
if [[ -d "$VENV_DIR" ]]; then
  echo "📦 Found existing venv at ${VENV_DIR}. Activating…"
  # shellcheck disable=SC1091
  source "${VENV_DIR}/bin/activate"
  echo "🔧 Python $(python --version)"

  if pip show ibm-watsonx-orchestrate &>/dev/null; then
      ADK_VERSION=$(pip show ibm-watsonx-orchestrate | awk '/^Version:/{print $2}')
  else
      ADK_VERSION=""
  fi

  # --- FIX: Prompt to install if ADK is missing ---
  if [[ -z "$ADK_VERSION" ]]; then
      echo "⚠️  Could not detect installed ADK version in the existing venv."
      read -rp "Do you want to install it now? (y/N) " choice
      case "$choice" in
        y|Y )
          install_adk # Call the installation function
          ;;
        * )
          echo "Skipping installation. The environment may not be complete."
          ;;
      esac
  fi
else
  echo "📦 Creating venv in ${VENV_DIR}…"
  python3.11 -m venv "$VENV_DIR"
  # shellcheck disable=SC1091
  source "${VENV_DIR}/bin/activate"
  echo "🔧 Python $(python --version)"
  install_adk # Call the installation function
fi

# Done
echo
if [[ -n "$ADK_VERSION" ]]; then
  echo "✅  Environment setup for ADK v$ADK_VERSION is complete."
else
  echo "✅  Environment setup is complete (ADK installation was skipped or failed)."
fi
echo "    You can now activate the venv with 'source \"${VENV_DIR}/bin/activate\"' and run the server."
echo "    Happy building — ruslanmv.com 🚀"