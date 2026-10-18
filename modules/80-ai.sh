# shellcheck shell=bash
# Copyright 2026 SuperFedora Contributors
# SPDX-License-Identifier: Apache-2.0
# desc: AI coding agents (Antigravity, Grok, MiniMax Code, Mistral Vibe)

module_run() {
    need_script_tool "Antigravity CLI (agy)" agy   https://antigravity.google/cli/install.sh
    need_script_tool "xAI Grok CLI (grok)"   grok  https://x.ai/cli/install.sh
    need_script_tool "MiniMax Code (mcode)"  mcode https://filecdn.minimax.chat/public/install.sh
    need_script_tool "Mistral Vibe (vibe)"   vibe  https://mistral.ai/vibe/install.sh

    # Ensure antigravity-cli alias symlink points to agy for Quake AI & shell scripts
    if [[ -x "$HOME/.local/bin/agy" && ! -e "$HOME/.local/bin/antigravity-cli" ]]; then
        ln -sf "$HOME/.local/bin/agy" "$HOME/.local/bin/antigravity-cli" 2>/dev/null || true
    fi
    _dig_t() { [[ -x "$HOME/.local/bin/sf-digest" || -x "$SF_ROOT/dotfiles/.local/bin/sf-digest" ]]; }
    _dig_i() { mkdir -p "$HOME/.local/bin" && install -m 755 "$SF_ROOT/dotfiles/.local/bin/sf-digest" "$HOME/.local/bin/sf-digest"; }
    need "SuperFedora AI Digest Utility (sf-digest)" _dig_t _dig_i
}
