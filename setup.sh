#!/usr/bin/env bash
# agent-configs setup: symlink AI agent config into ~/.claude/ and ~/.cursor/.
# Idempotent — safe to re-run. Skips entries that don't exist in this repo.
# Self-locating: works whether invoked directly or via dotfiles/setup.sh.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log()  { printf "\033[1;34m==>\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m!!\033[0m %s\n" "$*" >&2; }

link() {
    local src="$REPO_DIR/$1"
    local dst="$HOME/$2"
    if [[ ! -e "$src" ]]; then
        return  # not present in this repo yet
    fi
    if [[ -e "$dst" && ! -L "$dst" ]]; then
        warn "Skipping $dst (real file/dir; move it aside first)"
        return
    fi
    mkdir -p "$(dirname "$dst")"
    ln -sfn "$src" "$dst"
    log "Linked ~/$2 -> agent-configs/$1"
}

# ----------------------------------------------------------------------------
# Claude Code: global rules + skills
# ----------------------------------------------------------------------------
# CLAUDE.md is a one-line `@./AGENTS.md` shim. AGENTS.md is the canonical
# tool-neutral source of truth.
link CLAUDE.md   .claude/CLAUDE.md
link AGENTS.md   .claude/AGENTS.md
link skills      .claude/skills

# ----------------------------------------------------------------------------
# Cursor: per-skill commands
# ----------------------------------------------------------------------------
# Cursor reads slash commands from ~/.cursor/commands/<name>.md — one link
# per skill. Cursor has no global AGENTS.md location; its global rules live
# in Settings → Rules (paste AGENTS.md contents manually if you want them).
if [[ -d "$REPO_DIR/skills" ]]; then
    mkdir -p "$HOME/.cursor/commands"
    for skill in "$REPO_DIR/skills"/*/; do
        name="$(basename "$skill")"
        if [[ -f "$skill/SKILL.md" ]]; then
            ln -sfn "$skill/SKILL.md" "$HOME/.cursor/commands/$name.md"
            log "Linked ~/.cursor/commands/$name.md -> agent-configs/skills/$name/SKILL.md"
        fi
    done
fi

log "agent-configs setup complete."
