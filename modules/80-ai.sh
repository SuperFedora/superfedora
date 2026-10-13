# shellcheck shell=bash
# desc: AI coding agents (Antigravity, Grok, MiniMax Code, Mistral Vibe)

module_run() {
    need_script_tool "Antigravity CLI (agy)" agy   https://antigravity.google/cli/install.sh
    need_script_tool "xAI Grok CLI (grok)"   grok  https://x.ai/cli/install.sh
    need_script_tool "MiniMax Code (mcode)"  mcode https://filecdn.minimax.chat/public/install.sh
    need_script_tool "Mistral Vibe (vibe)"   vibe  https://mistral.ai/vibe/install.sh
}
