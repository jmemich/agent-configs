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
# Home root: AGENTS.md + CLAUDE.md at ~ (for agents that read $HOME directly)
# ----------------------------------------------------------------------------
link AGENTS.md   AGENTS.md
link CLAUDE.md   CLAUDE.md

# ----------------------------------------------------------------------------
# Cursor: Agent Skills (same tree as Claude)
# ----------------------------------------------------------------------------
# Cursor discovers user skills under ~/.cursor/skills/<name>/SKILL.md (and
# mirrors .agents/skills). Link the whole skills/ tree — same as ~/.claude/skills.
#
# Do NOT symlink individual skill dirs or command .md files: Cursor's scanner
# skips symlinked paths ("Refusing to read symlink") and they won't appear in /.
# Cursor has no global AGENTS.md location; global rules live in Settings → Rules.

# Legacy: remove per-skill command symlinks from an older setup layout.
if [[ -d "$HOME/.cursor/commands" ]]; then
    for cmd in "$HOME/.cursor/commands"/*.md; do
        [[ -L "$cmd" ]] || continue
        rm -f "$cmd"
        log "Removed legacy command symlink $(basename "$cmd")"
    done
    rmdir "$HOME/.cursor/commands" 2>/dev/null || true
fi
# Legacy: per-skill dir symlinks under ~/.cursor/skills/<name> (not the whole tree).
if [[ -d "$HOME/.cursor/skills" && ! -L "$HOME/.cursor/skills" ]]; then
    for skill_link in "$HOME/.cursor/skills"/*; do
        [[ -L "$skill_link" ]] || continue
        rm -f "$skill_link"
        log "Removed legacy skill symlink $(basename "$skill_link")"
    done
    rmdir "$HOME/.cursor/skills" 2>/dev/null || true
fi

link skills .cursor/skills

log "agent-configs setup complete."
