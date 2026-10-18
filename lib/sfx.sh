#!/usr/bin/env bash
# Copyright 2026 SuperFedora Contributors
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================
# sfx.sh — SuperFedora 16-Bit Sound Engine (pw-play + synthesized PCM WAV)
# ==============================================================================
# Usage:
#   superfedora sfx status                    Print 16-bit sound engine state (on/off)
#   superfedora sfx on | off | toggle | mute  Enable, disable, or toggle 16-bit UI sounds
#   superfedora sfx init                      Pre-synthesize 16-bit WAV sound bank
#   superfedora sfx [play] <chime>            Play chime (startup|click|confirm|toggle|volume|alert)
# ==============================================================================
set -euo pipefail

STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/superfedora"
SFX_CONF="$STATE_DIR/sfx.conf"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/superfedora/sfx"
mkdir -p "$STATE_DIR" "$CACHE_DIR"

SFX_ENABLED=1
# shellcheck disable=SC1090
[[ -f "$SFX_CONF" ]] && source "$SFX_CONF"

save_state() {
    printf 'SFX_ENABLED=%s\n' "$1" > "$SFX_CONF"
    SFX_ENABLED="$1"
    if command -v qs >/dev/null 2>&1 && pgrep -x quickshell >/dev/null 2>&1; then
        qs ipc call status refresh >/dev/null 2>&1 || true
    fi
}

ensure_bank() {
    [[ -f "$CACHE_DIR/startup.wav" && -f "$CACHE_DIR/click.wav" && -f "$CACHE_DIR/confirm.wav" ]] && return 0
    python3 - "$CACHE_DIR" <<'PY'
import math, os, struct, sys, wave

out_dir = sys.argv[1]
os.makedirs(out_dir, exist_ok=True)
SR = 44100

def synth(notes, vol=0.22, duty=0.5):
    samples = []
    for freq, dur in notes:
        n = int(SR * dur)
        for i in range(n):
            t = i / SR
            env = min(1.0, i / max(1, int(SR * 0.004))) * math.exp(-3.5 * (i / n))
            if freq <= 0:
                val = 0.0
            else:
                phase = (t * freq) % 1.0
                sq = 1.0 if phase < duty else -1.0
                sub = math.sin(2.0 * math.pi * (freq * 0.5) * t) * 0.35
                val = (sq * 0.65 + sub) * vol * env
            samples.append(int(max(-32767, min(32767, val * 32767))))
    echo_delay = int(SR * 0.055)
    out = list(samples) + [0] * echo_delay
    for i in range(len(samples)):
        out[i + echo_delay] = max(-32767, min(32767, out[i + echo_delay] + int(samples[i] * 0.28)))
    return out

def write_wav(name, notes, vol=0.20, duty=0.5):
    path = os.path.join(out_dir, f"{name}.wav")
    pcm = synth(notes, vol=vol, duty=duty)
    with wave.open(path, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SR)
        wf.writeframes(struct.pack(f"<{len(pcm)}h", *pcm))

write_wav("startup", [(987.77, 0.075), (1318.51, 0.32)], vol=0.22, duty=0.5)
write_wav("click",   [(1046.50, 0.018), (1567.98, 0.022)], vol=0.14, duty=0.25)
write_wav("confirm", [(523.25, 0.045), (659.25, 0.045), (783.99, 0.045), (1046.50, 0.14)], vol=0.18, duty=0.5)
write_wav("toggle",  [(659.25, 0.035), (987.77, 0.065)], vol=0.16, duty=0.35)
write_wav("volume",  [(880.00, 0.025)], vol=0.13, duty=0.5)
write_wav("alert",   [(392.00, 0.07), (311.13, 0.14)], vol=0.20, duty=0.5)
PY
}

play_sound() {
    local name="${1:-click}"
    [[ "${SFX_ENABLED:-1}" == "1" ]] || return 0
    case "$name" in
        boot|startup) name="startup" ;;
        tick|click)   name="click" ;;
        ok|confirm)   name="confirm" ;;
        toggle)       name="toggle" ;;
        vol|volume)   name="volume" ;;
        err|alert)    name="alert" ;;
        *)            name="click" ;;
    esac
    ensure_bank
    local wav="$CACHE_DIR/$name.wav"
    [[ -f "$wav" ]] || return 0
    if command -v pw-play >/dev/null 2>&1; then
        nohup pw-play "$wav" </dev/null >/dev/null 2>&1 & disown || true
    elif command -v paplay >/dev/null 2>&1; then
        nohup paplay "$wav" </dev/null >/dev/null 2>&1 & disown || true
    elif command -v aplay >/dev/null 2>&1; then
        nohup aplay -q "$wav" </dev/null >/dev/null 2>&1 & disown || true
    fi
}

CMD="${1:-status}"
case "$CMD" in
    status)
        if [[ "${SFX_ENABLED:-1}" == "1" ]]; then echo "on"; else echo "off"; fi ;;
    on|enable|unmute)
        save_state 1
        play_sound confirm
        echo "[OK] 16-bit sound effects enabled" ;;
    off|disable|mute)
        save_state 0
        echo "[OK] 16-bit sound effects muted" ;;
    toggle)
        if [[ "${SFX_ENABLED:-1}" == "1" ]]; then
            save_state 0
            echo "[OK] 16-bit sound effects muted"
        else
            save_state 1
            play_sound confirm
            echo "[OK] 16-bit sound effects enabled"
        fi ;;
    init)
        ensure_bank
        echo "[OK] Synthesized 16-bit WAV sound bank in $CACHE_DIR" ;;
    play)
        play_sound "${2:-click}" ;;
    startup|boot|click|tick|confirm|ok|volume|vol|alert|err)
        play_sound "$CMD" ;;
    -h|--help|help)
        sed -n '7,11p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' ;;
    *)
        echo "unknown sfx command: $CMD" >&2
        exit 2 ;;
esac
