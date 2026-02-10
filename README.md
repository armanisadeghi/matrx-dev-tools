# matrx-dev-tools

Shared developer tooling for all AI Matrx projects. One repo, works everywhere — Node (pnpm) and Python alike.

## Quick Start

Run this from any project root:

```bash
curl -sL https://raw.githubusercontent.com/armanisadeghi/matrx-dev-tools/main/install.sh | bash
```

The installer will:
1. Ask for your project type and Doppler project name (first time only)
2. Install scripts to `scripts/matrx/`
3. Register commands in `package.json` (Node) or `Makefile` (Python)

## Update

```bash
pnpm tools:update    # Node
make tools-update    # Python
```

## Tools

### env-sync — Safe Doppler ↔ .env synchronization

Merge-based sync that **never deletes** keys from either side. Changed values keep the new value and comment out the old one with a timestamp.

| Node Command | Python Command | What it does |
|---|---|---|
| `pnpm env:status` | `make env-status` | Quick variable count summary |
| `pnpm env:diff` | `make env-diff` | Show differences between local and Doppler |
| `pnpm env:pull` | `make env-pull` | Safe merge from Doppler (add + update, never delete) |
| `pnpm env:push` | `make env-push` | Safe merge to Doppler (add + update, never delete) |
| `pnpm env:pull:force` | `make env-pull-force` | Full replace from Doppler |
| `pnpm env:push:force` | `make env-push-force` | Full replace to Doppler |

### Local Override Keys — Machine-Specific Variables

Some environment variables are machine-specific (local file paths, machine credentials, etc.) and should **never** be blindly synced between environments. List them in `.matrx-tools.conf`:

```bash
ENV_LOCAL_KEYS="ADMIN_PYTHON_ROOT,BASE_DIR,PYTHONPATH,GOOGLE_APPLICATION_CREDENTIALS"
```

**What happens:**

| Operation | Behavior |
|---|---|
| `env:push` / `env:push:force` | Stores `__REPLACE_ME__` placeholder in Doppler instead of the real value |
| `env:pull` (key exists locally) | **Keeps your local value** — never overwrites |
| `env:pull` (key missing locally) | Adds the key **commented out** so you're reminded to set it |
| `env:pull:force` | Same as merge — local overrides are always preserved |
| `env:diff` | Shows these keys with a `⚙ LOCAL OVERRIDE` label |

Example: after pulling on a fresh machine, your `.env.local` will contain:

```bash
# [env-sync] Local override variables — set these for your environment:
# ADMIN_PYTHON_ROOT="__REPLACE_ME__"
# BASE_DIR="__REPLACE_ME__"
# PYTHONPATH="__REPLACE_ME__"
```

Uncomment and set the values for your machine. Future pulls will leave them alone.

### Monorepo / Multi-config

For projects with multiple Doppler configs (e.g., web + mobile), set `DOPPLER_MULTI="true"` in `.matrx-tools.conf`. See `templates/matrx-tools.conf.example` for the full syntax.

Per-config local override keys are also supported:

```bash
ENV_LOCAL_KEYS_web="BASE_DIR,GOOGLE_APPLICATION_CREDENTIALS"
ENV_LOCAL_KEYS_mobile="BASE_DIR"
```

## Configuration

Each project has a `.matrx-tools.conf` file in its root:

```bash
PROJECT_TYPE="node"
TOOLS_ENABLED="env-sync"
DOPPLER_PROJECT="ai-matrx-admin"
DOPPLER_CONFIG="dev"
ENV_FILE=".env.local"

# Machine-specific keys (optional)
ENV_LOCAL_KEYS="ADMIN_PYTHON_ROOT,BASE_DIR,PYTHONPATH"
```

## Adding New Tools

1. Create `tools/my-tool.sh` in this repo
2. Source `lib/colors.sh` and `lib/utils.sh` for shared helpers
3. Add config keys to `templates/matrx-tools.conf.example`
4. Add the tool name to `TOOLS_ENABLED` in consuming projects
5. Run `tools:update` / `tools-update` to pick it up

## Requirements

- bash 3.2+ (macOS default works)
- git
- [Doppler CLI](https://docs.doppler.com/docs/install-cli) (for env-sync)
- node (for Node projects — used to patch package.json)
