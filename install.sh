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

# ─── Handle config file ─────────────────────────────────────────────────────

if [[ ! -f "$CONF_FILE" ]]; then
    echo ""
    echo -e "${YELLOW}No ${CONF_FILE} found. Let's create one.${NC}"
    echo ""

    # Detect project type
    if [[ -f "package.json" ]]; then
        detected_type="node"
    elif [[ -f "pyproject.toml" ]] || [[ -f "setup.py" ]] || [[ -f "requirements.txt" ]]; then
        detected_type="python"
    else
        detected_type="node"
    fi

    echo -e "  Detected project type: ${GREEN}${detected_type}${NC}"
    echo -n "  Project type (node/python) [${detected_type}]: "
    read -r user_type
    PROJECT_TYPE="${user_type:-$detected_type}"

    echo -n "  Doppler project name: "
    read -r DOPPLER_PROJECT
    if [[ -z "$DOPPLER_PROJECT" ]]; then
        echo -e "${RED}Doppler project name is required.${NC}"
        exit 1
    fi

    echo -n "  Doppler config [dev]: "
    read -r user_config
    DOPPLER_CONFIG="${user_config:-dev}"

    if [[ "$PROJECT_TYPE" == "node" ]]; then
        default_env=".env.local"
    else
        default_env=".env"
    fi
    echo -n "  Env file [${default_env}]: "
    read -r user_env
    ENV_FILE="${user_env:-$default_env}"

    cat > "$CONF_FILE" << CONF
# .matrx-tools.conf — Project configuration for matrx-dev-tools
# Docs: https://github.com/armanisadeghi/matrx-dev-tools

# Project type: "node" or "python"
PROJECT_TYPE="${PROJECT_TYPE}"

# ─── Tools to install ───────────────────────────────
TOOLS_ENABLED="env-sync"

# ─── Env Sync Configuration ─────────────────────────
DOPPLER_PROJECT="${DOPPLER_PROJECT}"
DOPPLER_CONFIG="${DOPPLER_CONFIG}"
ENV_FILE="${ENV_FILE}"

# ─── Multi-config mode (uncomment for monorepos) ────
# DOPPLER_MULTI="true"
# DOPPLER_CONFIGS="web,mobile"
# DOPPLER_PROJECT_web="my-project"
# DOPPLER_CONFIG_web="web"
# ENV_FILE_web="web/.env.local"
# DOPPLER_PROJECT_mobile="my-project"
# DOPPLER_CONFIG_mobile="mobile"
# ENV_FILE_mobile="mobile/.env"
CONF

    echo ""
    echo -e "${GREEN}✓ Created ${CONF_FILE}${NC}"
fi

# Source the config
# shellcheck disable=SC1090
source "$CONF_FILE"

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
