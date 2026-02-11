#!/usr/bin/env bash
# =============================================================================
# install.sh — Bootstrap/update matrx-dev-tools in any project
#
# Usage (from any project root):
#   curl -sL https://raw.githubusercontent.com/armanisadeghi/matrx-dev-tools/main/install.sh | bash
#
# Or update an existing install:
#   pnpm tools:update    (Node projects)
#   make tools-update    (Python projects)
#
# Compatible with bash 3.2+ (macOS default)
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

REPO_URL="https://github.com/armanisadeghi/matrx-dev-tools.git"
CONF_FILE=".matrx-tools.conf"
INSTALL_DIR="scripts/matrx"

echo ""
echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║     matrx-dev-tools installer         ║${NC}"
echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════╝${NC}"
echo ""

# ─── Interactive input helper ─────────────────────────────────────────────────
# Always reads from /dev/tty so curl|bash works correctly.

prompt_user() {
    local prompt_text="$1"
    local default_value="${2:-}"
    local result=""

    if [[ -n "$default_value" ]]; then
        echo -en "  ${prompt_text} [${GREEN}${default_value}${NC}]: " >&2
    else
        echo -en "  ${prompt_text}: " >&2
    fi

    # Read from /dev/tty (the actual terminal), NOT stdin
    if read -r result < /dev/tty 2>/dev/null; then
        : # success
    else
        # Fallback: if /dev/tty isn't available (rare CI scenario), use default
        result=""
    fi

    # Use default if empty
    if [[ -z "$result" ]]; then
        result="$default_value"
    fi

    echo "$result"
}

# ─── Detect project root ─────────────────────────────────────────────────────

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$PROJECT_ROOT"

echo -e "${DIM}Project root: ${PROJECT_ROOT}${NC}"

# ─── Clone/update dev-tools to temp dir ──────────────────────────────────────

TMPDIR_INSTALL=$(mktemp -d)
trap "rm -rf '$TMPDIR_INSTALL'" EXIT

echo -e "${DIM}Fetching latest matrx-dev-tools...${NC}"
git clone --depth 1 --quiet "$REPO_URL" "$TMPDIR_INSTALL/matrx-dev-tools" 2>/dev/null

TOOLS_SRC="$TMPDIR_INSTALL/matrx-dev-tools"

# ─── Smart defaults ──────────────────────────────────────────────────────────

detect_project_type() {
    if [[ -f "package.json" ]]; then
        echo "node"
    elif [[ -f "pyproject.toml" ]] || [[ -f "setup.py" ]] || [[ -f "requirements.txt" ]]; then
        echo "python"
    else
        echo "node"
    fi
}

detect_project_name() {
    # Best guess: repo directory name (matches Doppler project name ~90% of the time)
    basename "$PROJECT_ROOT"
}

detect_env_file() {
    local project_type="$1"

    # Check for existing env files first
    if [[ -f ".env.local" ]]; then
        echo ".env.local"
        return
    fi
    if [[ -f ".env" ]]; then
        echo ".env"
        return
    fi

    # Framework-specific defaults
    if [[ -f "next.config.ts" ]] || [[ -f "next.config.js" ]] || [[ -f "next.config.mjs" ]]; then
        echo ".env.local"
        return
    fi

    # General defaults by project type
    if [[ "$project_type" == "node" ]]; then
        echo ".env.local"
    else
        echo ".env"
    fi
}

detect_doppler_config() {
    # Default to "dev" — most common for local development
    echo "dev"
}

# ─── Handle config file ─────────────────────────────────────────────────────

if [[ ! -f "$CONF_FILE" ]]; then
    echo ""
    echo -e "${YELLOW}No ${CONF_FILE} found. Let's create one.${NC}"
    echo ""

    # Detect smart defaults
    detected_type=$(detect_project_type)
    detected_name=$(detect_project_name)

    PROJECT_TYPE=$(prompt_user "Project type (node/python)" "$detected_type")

    detected_env=$(detect_env_file "$PROJECT_TYPE")
    detected_config=$(detect_doppler_config)

    DOPPLER_PROJECT=$(prompt_user "Doppler project name" "$detected_name")

    if [[ -z "$DOPPLER_PROJECT" ]]; then
        echo -e "${RED}Error: Doppler project name is required.${NC}"
        echo -e "${DIM}This is the project name in your Doppler dashboard.${NC}"
        exit 1
    fi

    DOPPLER_CONFIG=$(prompt_user "Doppler config" "$detected_config")
    ENV_FILE=$(prompt_user "Env file" "$detected_env")

    # Validate: don't write garbage
    if [[ "$DOPPLER_PROJECT" == *"#"* ]] || [[ "$DOPPLER_PROJECT" == *"source"* ]] || [[ -z "$DOPPLER_PROJECT" ]]; then
        echo -e "${RED}Error: Invalid Doppler project name: '${DOPPLER_PROJECT}'${NC}"
        echo -e "${DIM}This usually means stdin was consumed by curl. Please create .matrx-tools.conf manually.${NC}"
        echo -e "${DIM}See: https://github.com/armanisadeghi/matrx-dev-tools#configuration${NC}"
        exit 1
    fi

    # Write config using explicit echo statements (not heredoc with interpolation)
    {
        echo '# .matrx-tools.conf — Project configuration for matrx-dev-tools'
        echo '# Docs: https://github.com/armanisadeghi/matrx-dev-tools'
        echo ''
        echo '# Project type: "node" or "python"'
        echo "PROJECT_TYPE=\"${PROJECT_TYPE}\""
        echo ''
        echo '# ─── Tools to install ───────────────────────────────'
        echo 'TOOLS_ENABLED="env-sync"'
        echo ''
        echo '# ─── Env Sync Configuration ─────────────────────────'
        echo "DOPPLER_PROJECT=\"${DOPPLER_PROJECT}\""
        echo "DOPPLER_CONFIG=\"${DOPPLER_CONFIG}\""
        echo "ENV_FILE=\"${ENV_FILE}\""
        echo ''
        echo '# ─── Machine-specific keys (optional) ──────────────'
        echo '# ENV_LOCAL_KEYS="ADMIN_PYTHON_ROOT,BASE_DIR,PYTHONPATH"'
        echo ''
        echo '# ─── Multi-config mode (uncomment for monorepos) ────'
        echo '# DOPPLER_MULTI="true"'
        echo '# DOPPLER_CONFIGS="web,mobile"'
        echo '# DOPPLER_PROJECT_web="my-project"'
        echo '# DOPPLER_CONFIG_web="web"'
        echo '# ENV_FILE_web="web/.env.local"'
        echo '# DOPPLER_PROJECT_mobile="my-project"'
        echo '# DOPPLER_CONFIG_mobile="mobile"'
        echo '# ENV_FILE_mobile="mobile/.env"'
    } > "$CONF_FILE"

    echo ""
    echo -e "${GREEN}✓ Created ${CONF_FILE}${NC}"
    echo -e "${DIM}  DOPPLER_PROJECT=${DOPPLER_PROJECT}${NC}"
    echo -e "${DIM}  DOPPLER_CONFIG=${DOPPLER_CONFIG}${NC}"
    echo -e "${DIM}  ENV_FILE=${ENV_FILE}${NC}"
else
    echo -e "${DIM}Found existing ${CONF_FILE}${NC}"
fi

# Source the config
# shellcheck disable=SC1090
source "$CONF_FILE"

# ─── Validate config after sourcing ──────────────────────────────────────────

validate_config() {
    local has_errors=0

    if [[ -z "${DOPPLER_PROJECT:-}" ]] || [[ "${DOPPLER_PROJECT:-}" == "# "* ]] || [[ "${DOPPLER_PROJECT:-}" == *"source"* ]]; then
        echo -e "${RED}Error: DOPPLER_PROJECT is missing or invalid in ${CONF_FILE}${NC}"
        echo -e "${DIM}  Current value: '${DOPPLER_PROJECT:-<empty>}'${NC}"
        echo -e "${DIM}  Expected: your Doppler project name (e.g., 'my-app')${NC}"
        has_errors=1
    fi

    if [[ -z "${DOPPLER_CONFIG:-}" ]] || [[ "${DOPPLER_CONFIG:-}" == "# "* ]]; then
        echo -e "${RED}Error: DOPPLER_CONFIG is missing or invalid in ${CONF_FILE}${NC}"
        echo -e "${DIM}  Current value: '${DOPPLER_CONFIG:-<empty>}'${NC}"
        echo -e "${DIM}  Expected: your Doppler config name (e.g., 'dev')${NC}"
        has_errors=1
    fi

    if [[ -z "${ENV_FILE:-}" ]] || [[ "${ENV_FILE:-}" == *"source"* ]] || [[ "${ENV_FILE:-}" == *'$'* ]]; then
        echo -e "${RED}Error: ENV_FILE is missing or invalid in ${CONF_FILE}${NC}"
        echo -e "${DIM}  Current value: '${ENV_FILE:-<empty>}'${NC}"
        echo -e "${DIM}  Expected: path to your env file (e.g., '.env.local')${NC}"
        has_errors=1
    fi

    if [[ $has_errors -eq 1 ]]; then
        echo ""
        echo -e "${YELLOW}Your ${CONF_FILE} has invalid values. This usually happens when the installer${NC}"
        echo -e "${YELLOW}was run via curl|bash and the prompts couldn't read from the terminal.${NC}"
        echo ""
        echo -e "${CYAN}To fix: edit ${CONF_FILE} and set the correct values, then re-run the installer.${NC}"
        echo -e "${DIM}Or delete ${CONF_FILE} and re-run to start fresh.${NC}"
        exit 1
    fi
}

validate_config

# ─── Install scripts ─────────────────────────────────────────────────────────

echo ""
echo -e "${CYAN}Installing tools...${NC}"

# Create install directory with lib subdirectory
mkdir -p "${INSTALL_DIR}/lib"

# Copy lib files
cp "$TOOLS_SRC/lib/colors.sh" "${INSTALL_DIR}/lib/colors.sh"
cp "$TOOLS_SRC/lib/utils.sh" "${INSTALL_DIR}/lib/utils.sh"

echo -e "  ${GREEN}✓${NC} lib/colors.sh"
echo -e "  ${GREEN}✓${NC} lib/utils.sh"

# Copy enabled tools
IFS=',' read -ra TOOLS <<< "${TOOLS_ENABLED:-env-sync}"
for tool in "${TOOLS[@]}"; do
    tool=$(echo "$tool" | tr -d ' ')
    if [[ -f "$TOOLS_SRC/tools/${tool}.sh" ]]; then
        cp "$TOOLS_SRC/tools/${tool}.sh" "${INSTALL_DIR}/${tool}.sh"
        chmod +x "${INSTALL_DIR}/${tool}.sh"
        echo -e "  ${GREEN}✓${NC} ${tool}.sh"
    else
        echo -e "  ${YELLOW}⚠${NC} ${tool}.sh not found in dev-tools repo, skipping"
    fi
done

# ─── Update .gitignore ──────────────────────────────────────────────────────

if [[ -f ".gitignore" ]]; then
    if ! grep -q '\.env-backups/' .gitignore 2>/dev/null; then
        echo "" >> .gitignore
        echo "# matrx-dev-tools backups" >> .gitignore
        echo ".env-backups/" >> .gitignore
        echo -e "  ${GREEN}✓${NC} Added .env-backups/ to .gitignore"
    fi
else
    echo ".env-backups/" > .gitignore
    echo -e "  ${GREEN}✓${NC} Created .gitignore with .env-backups/"
fi

# ─── Register commands ──────────────────────────────────────────────────────

echo ""

if [[ "$PROJECT_TYPE" == "node" ]]; then
    echo -e "${CYAN}Registering package.json scripts...${NC}"

    if [[ ! -f "package.json" ]]; then
        echo -e "${YELLOW}No package.json found, skipping script registration${NC}"
    else
        # Use node to safely patch package.json (preserves formatting better than sed)
        node -e "
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
if (!pkg.scripts) pkg.scripts = {};

const newScripts = {
    'env:pull': 'bash scripts/matrx/env-sync.sh pull',
    'env:push': 'bash scripts/matrx/env-sync.sh push',
    'env:diff': 'bash scripts/matrx/env-sync.sh diff',
    'env:status': 'bash scripts/matrx/env-sync.sh status',
    'env:pull:force': 'bash scripts/matrx/env-sync.sh pull --force',
    'env:push:force': 'bash scripts/matrx/env-sync.sh push --force',
    'tools:update': 'curl -sL https://raw.githubusercontent.com/armanisadeghi/matrx-dev-tools/main/install.sh | bash'
};

let added = 0;
let updated = 0;
for (const [key, val] of Object.entries(newScripts)) {
    if (!pkg.scripts[key]) {
        added++;
    } else if (pkg.scripts[key] !== val) {
        updated++;
    }
    pkg.scripts[key] = val;
}

fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
console.log('  Added: ' + added + ', Updated: ' + updated);
" 2>/dev/null && echo -e "  ${GREEN}✓${NC} package.json scripts updated" || echo -e "  ${YELLOW}⚠${NC} Could not patch package.json (update manually)"
    fi

elif [[ "$PROJECT_TYPE" == "python" ]]; then
    echo -e "${CYAN}Registering Makefile targets...${NC}"

    MARKER="# ─── matrx-dev-tools"

    if [[ -f "Makefile" ]]; then
        # Remove existing matrx-dev-tools section if present
        if grep -q "$MARKER" Makefile 2>/dev/null; then
            # Remove from marker to end of file (the section is always at the end)
            sed -i.bak "/$MARKER/,\$d" Makefile
            rm -f Makefile.bak
            echo -e "  ${DIM}Replacing existing matrx-dev-tools section${NC}"
        fi
    else
        # Create a new Makefile
        echo "# Makefile" > Makefile
        echo "" >> Makefile
        echo -e "  ${DIM}Created new Makefile${NC}"
    fi

    cat >> Makefile << 'MAKEFILE_SNIPPET'

# ─── matrx-dev-tools ─────────────────────────────────
env-pull:
	@bash scripts/matrx/env-sync.sh pull

env-push:
	@bash scripts/matrx/env-sync.sh push

env-diff:
	@bash scripts/matrx/env-sync.sh diff

env-status:
	@bash scripts/matrx/env-sync.sh status

env-pull-force:
	@bash scripts/matrx/env-sync.sh pull --force

env-push-force:
	@bash scripts/matrx/env-sync.sh push --force

tools-update:
	@curl -sL https://raw.githubusercontent.com/armanisadeghi/matrx-dev-tools/main/install.sh | bash

.PHONY: env-pull env-push env-diff env-status env-pull-force env-push-force tools-update
MAKEFILE_SNIPPET

    echo -e "  ${GREEN}✓${NC} Makefile targets registered"
fi

# ─── Spinner helper ───────────────────────────────────────────────────────────

spinner_pid=""

start_spinner() {
    local message="${1:-Working...}"
    (
        local chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
        local i=0
        while true; do
            printf '\r  %s %s ' "${chars:i%${#chars}:1}" "$message" >&2
            i=$((i + 1))
            sleep 0.1
        done
    ) &
    spinner_pid=$!
}

stop_spinner() {
    local success="${1:-1}"
    local message="${2:-}"
    if [[ -n "$spinner_pid" ]]; then
        kill "$spinner_pid" 2>/dev/null || true
        wait "$spinner_pid" 2>/dev/null || true
        spinner_pid=""
    fi
    printf '\r' >&2
    # Clear the line
    printf '  %-60s\r' "" >&2
    if [[ -n "$message" ]]; then
        if [[ "$success" == "1" ]]; then
            echo -e "  ${GREEN}✓${NC} ${message}"
        else
            echo -e "  ${RED}✗${NC} ${message}"
        fi
    fi
}

# ─── Open URL helper ─────────────────────────────────────────────────────────

open_url() {
    local url="$1"
    if [[ "$(uname)" == "Darwin" ]]; then
        open "$url" 2>/dev/null && return 0
    elif command -v xdg-open &>/dev/null; then
        xdg-open "$url" 2>/dev/null && return 0
    elif command -v wslview &>/dev/null; then
        wslview "$url" 2>/dev/null && return 0
    fi
    return 1
}

# ─── Ensure Doppler CLI is installed ──────────────────────────────────────────

echo ""
echo -e "${CYAN}Checking Doppler CLI...${NC}"

install_doppler() {
    echo -e "  ${YELLOW}Doppler CLI not found. Installing...${NC}"
    echo ""

    # Detect OS and install accordingly
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS — prefer Homebrew
        if command -v brew &>/dev/null; then
            start_spinner "Installing Doppler via Homebrew (this may take a minute)..."
            brew install dopplerhq/cli/doppler >/dev/null 2>&1
            local exit_code=$?
            if [[ $exit_code -eq 0 ]]; then
                stop_spinner 1 "Doppler installed via Homebrew"
            else
                stop_spinner 0 "Homebrew install failed"
                return 1
            fi
        else
            echo -e "${RED}Error: Homebrew not found. Install Doppler manually:${NC}"
            echo -e "  ${CYAN}https://docs.doppler.com/docs/install-cli${NC}"
            return 1
        fi
    elif [[ -f /etc/debian_version ]] || command -v apt-get &>/dev/null; then
        # Debian/Ubuntu
        start_spinner "Installing Doppler via apt (this may take a minute)..."
        (
            curl -sLf --retry 3 --tlsv1.2 --proto "=https" \
                'https://packages.doppler.com/public/cli/gpg.DE2A7741A397C129.key' \
                | sudo gpg --dearmor -o /usr/share/keyrings/doppler-archive-keyring.gpg 2>/dev/null
            echo "deb [signed-by=/usr/share/keyrings/doppler-archive-keyring.gpg] https://packages.doppler.com/public/cli/deb/debian any-version main" \
                | sudo tee /etc/apt/sources.list.d/doppler-cli.list >/dev/null
            sudo apt-get update -qq >/dev/null 2>&1
            sudo apt-get install -y -qq doppler >/dev/null 2>&1
        )
        local exit_code=$?
        if [[ $exit_code -eq 0 ]]; then
            stop_spinner 1 "Doppler installed via apt"
        else
            stop_spinner 0 "apt install failed"
            echo -e "  ${DIM}Install manually: ${CYAN}https://docs.doppler.com/docs/install-cli${NC}"
            return 1
        fi
    elif command -v yum &>/dev/null || command -v dnf &>/dev/null; then
        # RHEL/Fedora/CentOS
        start_spinner "Installing Doppler via rpm (this may take a minute)..."
        (
            sudo rpm --import 'https://packages.doppler.com/public/cli/gpg.DE2A7741A397C129.key' 2>/dev/null
            curl -sLf --retry 3 --tlsv1.2 --proto "=https" \
                'https://packages.doppler.com/public/cli/config.rpm.txt' \
                | sudo tee /etc/yum.repos.d/doppler-cli.repo >/dev/null
            if command -v dnf &>/dev/null; then
                sudo dnf install -y -q doppler >/dev/null 2>&1
            else
                sudo yum install -y -q doppler >/dev/null 2>&1
            fi
        )
        local exit_code=$?
        if [[ $exit_code -eq 0 ]]; then
            stop_spinner 1 "Doppler installed via rpm"
        else
            stop_spinner 0 "rpm install failed"
            echo -e "  ${DIM}Install manually: ${CYAN}https://docs.doppler.com/docs/install-cli${NC}"
            return 1
        fi
    else
        # Generic fallback — Doppler's install script
        start_spinner "Installing Doppler (this may take a minute)..."
        (curl -sLf --retry 3 --tlsv1.2 --proto "=https" https://cli.doppler.com/install.sh | sh) >/dev/null 2>&1
        local exit_code=$?
        if [[ $exit_code -eq 0 ]]; then
            stop_spinner 1 "Doppler installed"
        else
            stop_spinner 0 "Automatic install failed"
            echo -e "  ${DIM}Install manually: ${CYAN}https://docs.doppler.com/docs/install-cli${NC}"
            return 1
        fi
    fi
}

if command -v doppler &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Doppler CLI found"
else
    install_doppler || {
        echo ""
        echo -e "${YELLOW}Doppler could not be installed automatically.${NC}"
        echo -e "${DIM}The tools are installed, but env-sync won't work until Doppler is set up.${NC}"
        echo -e "${DIM}Install manually: ${CYAN}https://docs.doppler.com/docs/install-cli${NC}"
        DOPPLER_SKIP_AUTH=1
    }
fi

# ─── Ensure Doppler is authenticated ─────────────────────────────────────────

if [[ "${DOPPLER_SKIP_AUTH:-}" != "1" ]] && command -v doppler &>/dev/null; then
    if doppler me &>/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Doppler authenticated"
    else
        echo ""
        echo -e "  ${YELLOW}Doppler is not authenticated yet.${NC}"
        echo -e "  ${DIM}You need to log in once per machine so env-sync can access your secrets.${NC}"
        echo ""

        do_login=$(prompt_user "Log in to Doppler now? (y/n)" "y")

        if [[ "$do_login" == "y" || "$do_login" == "Y" || "$do_login" == "yes" ]]; then
            echo ""

            # Capture the auth URL from doppler login and try to auto-open it
            # doppler login --no-prompt outputs the URL without waiting for browser interaction
            local auth_url=""
            auth_url=$(doppler login --no-prompt 2>&1 | grep -oE 'https://[^ ]+' | head -1) || true

            if [[ -n "$auth_url" ]]; then
                if open_url "$auth_url"; then
                    echo -e "  ${GREEN}✓${NC} Opened Doppler login in your browser"
                else
                    echo -e "  ${CYAN}Open this URL in your browser to authenticate:${NC}"
                    echo ""
                    echo -e "    ${BOLD}${auth_url}${NC}"
                fi
                echo ""
                echo -e "  ${DIM}Waiting for authentication to complete...${NC}"

                # Poll until authenticated (timeout after 120 seconds)
                local waited=0
                start_spinner "Waiting for you to complete login in the browser..."
                while [[ $waited -lt 120 ]]; do
                    if doppler me &>/dev/null 2>&1; then
                        stop_spinner 1 "Doppler authenticated successfully"
                        break
                    fi
                    sleep 3
                    waited=$((waited + 3))
                done
                if [[ $waited -ge 120 ]]; then
                    stop_spinner 0 "Timed out waiting for login"
                    echo -e "  ${DIM}You can finish later: ${CYAN}doppler login${NC}"
                fi
            else
                # Fallback: run doppler login interactively
                echo -e "  ${CYAN}Running Doppler login...${NC}"
                echo ""
                if doppler login < /dev/tty 2>&1; then
                    echo ""
                    echo -e "  ${GREEN}✓${NC} Doppler authenticated successfully"
                else
                    echo ""
                    echo -e "  ${YELLOW}Login didn't complete. You can finish later:${NC}"
                    echo -e "    ${CYAN}doppler login${NC}"
                fi
            fi
        else
            echo ""
            echo -e "  ${DIM}Skipped. Run ${CYAN}doppler login${NC} ${DIM}before using env-sync commands.${NC}"
        fi
    fi
fi

# ─── Summary ─────────────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}${BOLD}✓ matrx-dev-tools installed successfully!${NC}"
echo ""
echo -e "${DIM}Installed to: ${INSTALL_DIR}/${NC}"
echo -e "${DIM}Config:       ${CONF_FILE}${NC}"
echo ""

if [[ "$PROJECT_TYPE" == "node" ]]; then
    echo -e "  Available commands:"
    echo -e "    ${CYAN}pnpm env:status${NC}      Quick sync summary"
    echo -e "    ${CYAN}pnpm env:diff${NC}        Show differences"
    echo -e "    ${CYAN}pnpm env:pull${NC}        Safe merge from Doppler"
    echo -e "    ${CYAN}pnpm env:push${NC}        Safe merge to Doppler"
    echo -e "    ${CYAN}pnpm env:pull:force${NC}  Full replace from Doppler"
    echo -e "    ${CYAN}pnpm env:push:force${NC}  Full replace to Doppler"
    echo -e "    ${CYAN}pnpm tools:update${NC}    Update dev-tools"
else
    echo -e "  Available commands:"
    echo -e "    ${CYAN}make env-status${NC}      Quick sync summary"
    echo -e "    ${CYAN}make env-diff${NC}        Show differences"
    echo -e "    ${CYAN}make env-pull${NC}        Safe merge from Doppler"
    echo -e "    ${CYAN}make env-push${NC}        Safe merge to Doppler"
    echo -e "    ${CYAN}make env-pull-force${NC}  Full replace from Doppler"
    echo -e "    ${CYAN}make env-push-force${NC}  Full replace to Doppler"
    echo -e "    ${CYAN}make tools-update${NC}    Update dev-tools"
fi
echo ""
