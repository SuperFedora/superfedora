#!/usr/bin/env python3
"""Generate docs/keybindings.md from dotfiles/.config/hypr/conf/bindings.conf.

Every described bind (bindd, bindeld, bindrd, ...) becomes a table row, grouped
by the "# ═══ Section ═══" headers in bindings.conf. Run by scripts/release.sh
so the published reference always matches the shipped config.
"""
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SRC = REPO / "dotfiles/.config/hypr/conf/bindings.conf"
OUT = REPO / "docs/keybindings.md"

KEY_NAMES = {
    "left": "←", "right": "→", "up": "↑", "down": "↓",
    "Return": "Enter", "Escape": "Esc", "SUPER_L": "Super (tap)",
    "grave": "`", "equal": "=", "minus": "-", "period": ".", "comma": ",",
    "slash": "/", "BackSpace": "Backspace", "space": "Space",
    "mouse:272": "Left drag", "mouse:273": "Right drag", "mouse:274": "Middle click",
    "mouse:275": "Mouse back", "mouse:276": "Mouse forward",
    "mouse_down": "Scroll down", "mouse_up": "Scroll up",
}


def fmt_combo(mods: str, key: str) -> str:
    parts = [m.capitalize() for m in mods.split() if m]
    parts = ["Super" if p == "Super" else p for p in parts]
    k = KEY_NAMES.get(key, key)
    if key.startswith("XF86"):
        k = key[4:]
    if key == "SUPER_L":
        return "Super (tap)"
    return " + ".join(parts + [k]) if parts else k


def main() -> int:
    version = (REPO / "VERSION").read_text().strip()
    sections: list[tuple[str, list[tuple[str, str]]]] = []
    current = ("General", [])
    submap = None
    bind_re = re.compile(r"^\s*bind([a-z]*)\s*=\s*(.*)$")

    for line in SRC.read_text().splitlines():
        h = re.match(r"^#\s*═+\s*(.+?)\s*═*\s*$", line)
        if h:
            if current[1]:
                sections.append(current)
            current = (h.group(1), [])
            continue
        s = re.match(r"^\s*submap\s*=\s*(\S+)", line)
        if s:
            submap = None if s.group(1) == "reset" else s.group(1)
            continue
        m = bind_re.match(line)
        if not m or "d" not in m.group(1):
            continue
        fields = [f.strip() for f in m.group(2).split(",")]
        if len(fields) < 3:
            continue
        mods, key, desc = fields[0], fields[1], fields[2]
        combo = fmt_combo(mods, key)
        if submap:
            combo = f"{combo} *(in {submap} mode)*"
        current[1].append((combo, desc))
    if current[1]:
        sections.append(current)

    out = [
        "# SuperFedora Keybindings",
        "",
        f"> Generated from [`bindings.conf`](../dotfiles/.config/hypr/conf/bindings.conf) "
        f"for **SuperFedora v{version}** by `scripts/gen-keybindings-doc.py`. Do not edit by hand.",
        ">",
        "> Bindings mirror Pop!_OS COSMIC defaults. Press **Super + F1** on the desktop for a searchable list.",
        "",
    ]
    for title, rows in sections:
        out += [f"## {title}", "", "| Keys | Action |", "| :--- | :--- |"]
        out += [f"| {c} | {d} |" for c, d in rows]
        out.append("")
    OUT.write_text("\n".join(out))
    print(f"wrote {OUT.relative_to(REPO)} ({sum(len(r) for _, r in sections)} bindings)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
