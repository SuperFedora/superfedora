# AI CLI Tools & Coding Agents Inventory

This document chronicles the installation, origin, configuration, and environment setup for all artificial intelligence command-line tools, autonomous coding agents, and desktop AI clients on **Fedora Linux 44**.

---

## 1. Quick Reference Matrix

| Tool | Binary Name | Version | Source / Install Link | Execution Path | State / Config Path |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Antigravity CLI** | `agy` | 1.3.3 | `https://antigravity.google/cli/install.sh` | `~/.local/bin/agy` | `~/.gemini/antigravity-cli/` |
| **xAI Grok CLI** | `grok`, `agent` | 1.0.52 | `https://x.ai/cli/install.sh` | `~/.grok/bin/grok` | `~/.grok/` |
| **MiniMax Code** | `mcode` | 0.6.8 | `https://filecdn.minimax.chat/public/install.sh` | `~/.minimax-code/bin/mcode` | `~/.minimax-code/`, `~/.minimax/` |
| **Mistral Vibe** | `vibe`, `vibe-acp` | 2.26.1 | `https://mistral.ai/vibe/install.sh` | `~/.local/share/uv/tools/mistral-vibe/bin/vibe` | `~/.config/vibe/` |
| **Msty Studio** | `mstystudio` | AppImage | `https://msty.app/` | `/opt/Msty/MstyStudio.AppImage` | `~/.local/share/MstyStudio/` |

---

## 2. Tool Deep-Dive & Setup Instructions

### 2.1 Antigravity CLI (`agy`)
- **Description**: Google DeepMind's advanced agentic coding assistant CLI.
- **Current Version**: `1.3.3`
- **Installation Method**:
  ```bash
  curl -fsSL https://antigravity.google/cli/install.sh | bash
  ```
- **Shell Environment (`~/.bashrc`)**:
  ```bash
  export PATH="$HOME/.local/bin:$PATH"
  export TERMINAL=kitty
  ```
- **Operational Files**:
  - Binary: `~/.local/bin/agy`
  - Working & App Data: `~/.gemini/antigravity-cli/`
- **Update Command**:
  ```bash
  agy update
  ```

---

### 2.2 xAI Grok CLI (`grok` & `agent`)
- **Description**: Official command-line interface for xAI Grok model interactions and autonomous code generation agents.
- **Current Version**: `1.0.52 (0920c8169e27) [stable]`
- **Installation Method**:
  ```bash
  curl -fsSL https://x.ai/cli/install.sh | bash
  ```
- **Shell Environment (`~/.bashrc`)**:
  ```bash
  # >>> grok installer >>>
  export PATH="$HOME/.grok/bin:$PATH"
  [[ -r "$HOME/.grok/completions/bash/grok.bash" ]] && source "$HOME/.grok/completions/bash/grok.bash"
  # <<< grok installer <<<
  ```
- **Provided Executables**:
  - `~/.grok/bin/grok`: Interactive prompt and quick query tool.
  - `~/.grok/bin/agent`: Full repository workspace agent.

---

### 2.3 MiniMax Code CLI (`mcode`)
- **Description**: Interactive terminal coding assistant engineered by MiniMax.
- **Current Version**: `0.6.8`
- **Installation Method**:
  ```bash
  curl -fsSL https://filecdn.minimax.chat/public/install.sh | bash
  ```
- **Shell Environment (`~/.bashrc`)**:
  ```bash
  export PATH="$HOME/.minimax-code/bin:$PATH"
  export PATH="$HOME/.minimax/bin:$PATH"
  ```
- **Operational Directories**:
  - Binary: `~/.minimax-code/bin/mcode`
  - Workspace cache: `~/.minimax-code/`
- **Update Command**:
  ```bash
  mcode update
  ```

---

### 2.4 Mistral Vibe (`vibe`, `vibe-acp`, `vibe-app-server`)
- **Description**: Terminal coding companion and Agent Client Protocol (ACP) integration daemon by Mistral AI.
- **Current Version**: `2.26.1`
- **Installation Method**:
  ```bash
  curl -LsSf https://mistral.ai/vibe/install.sh | bash
  ```
- **Underlying Architecture**:
  - Installed via Astral `uv` tool isolation in `~/.local/share/uv/tools/mistral-vibe/`.
  - Exposed via symlinks in `~/.local/bin/`:
    - `vibe` -> `~/.local/share/uv/tools/mistral-vibe/bin/vibe`
    - `vibe-acp` -> `~/.local/share/uv/tools/mistral-vibe/bin/vibe-acp`
    - `vibe-app-server` -> `~/.local/share/uv/tools/mistral-vibe/bin/vibe-app-server`
- **Configuration & Setup**:
  ```bash
  vibe --setup
  ```
  Configuration data is saved under `~/.config/vibe/`.

---

### 2.5 Msty Studio
- **Description**: Offline-first, secure desktop GUI for chatting with local LLMs (via llama.cpp/Ollama) and cloud APIs.
- **Installation Location**:
  - AppImage: `/opt/Msty/MstyStudio.AppImage`
- **Launcher Wrapper**: `~/.local/bin/mstystudio`
  ```bash
  #!/usr/bin/env bash
  set -e
  MSTY_DIR="$HOME/.local/share/MstyStudio"
  if [ -x "$MSTY_DIR/mstystudio" ]; then
      exec "$MSTY_DIR/mstystudio" --no-sandbox "$@"
  fi
  echo "Error: Msty Studio executable not found at $MSTY_DIR/mstystudio" >&2
  exit 1
  ```
- **User Data**: `~/.local/share/MstyStudio`

---

## 3. Quake AI Drop-Down Console & Extensible Agent Framework

SuperFedora includes a Quake-style drop-down AI terminal (`SUPER + \`` to toggle, `Esc` or `SUPER + \`` to hide when open, `SUPER + Shift + \`` to cycle agents) integrated with the **Top Bar AI icon (`󰚩`)** popover (`panels/AiPopup.qml`).

### 3.1 Built-In Agent Support
- **Core Stack**:
  - `agy` — **Antigravity CLI** (`agy`, default)
  - `mcode` — **MiniMax Code** (`mcode`)
  - `grok` — **xAI Grok CLI** (`grok`)
  - `vibe` — **Mistral Vibe** (`vibe`)
- **Standard Agents**:
  - `claude` — **Claude Code** (`claude`)
  - `chatgpt` — **ChatGPT / OpenAI Codex CLI** (`chatgpt` or `codex`)
- **Ollama Connection (`ip:port` + model)**:
  - `ollama` — **Ollama** (`OLLAMA_HOST=<ip:port> ollama run <model>`)

### 3.2 Ollama (`ip:port`) & Custom Agent CLI / TUI Configuration
All settings persist in `~/.config/superfedora/quake-ai.env` and `~/.config/superfedora/ai-agents.conf` (`id|label|command` lines):

```bash
# Switch active Quake AI agent
sf ai set-agent mcode
sf ai set-agent claude
sf ai set-agent chatgpt

# Configure Ollama connection with any local or LAN ip:port and model
sf ai set-ollama 192.168.1.50:11434 qwen2.5-coder
sf ai set-agent ollama

# Register or remove any custom AI agent CLI
sf ai add-agent aider "Aider Pair Programmer" "aider"
sf ai remove-agent aider

# Launch interactive TUI configurator
sf ai configure
```
