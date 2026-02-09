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

### Monorepo / Multi-config

For projects with multiple Doppler configs (e.g., web + mobile), set `DOPPLER_MULTI="true"` in `.matrx-tools.conf`. See `templates/matrx-tools.conf.example` for the full syntax.

## Configuration

Each project has a `.matrx-tools.conf` file in its root:

```bash
PROJECT_TYPE="node"
TOOLS_ENABLED="env-sync"
DOPPLER_PROJECT="ai-matrx-admin"
DOPPLER_CONFIG="dev"
ENV_FILE=".env.local"
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
