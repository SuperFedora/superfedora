#!/usr/bin/env bash
# Copyright 2026 SuperFedora Contributors
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================
# forge.sh — Hardware-Tuned Source Installer (sf forge)
# ==============================================================================
# Usage:
#   sf forge status                  Show localhost CPU/GPU/linker optimization flags
#   sf forge list                    List built-in recipes & forged binaries
#   sf forge <target|owner/repo>     Clone, hardware-tune (-march=native), build & install
#   sf forge rebuild                 Recompile all installed forge targets for current CPU
#   sf forge deps <target> [--install] Check or install Fedora -devel build dependencies
# ==============================================================================
set -euo pipefail

STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/superfedora"
STAMP_DIR="$STATE_DIR/source-built"
FORGE_JSON="$STATE_DIR/forge.json"
BIN_DIR="$HOME/.local/bin"
SYSROOT="$HOME/.local/sysroot/usr"
TMP_BUILD="${XDG_CACHE_HOME:-$HOME/.cache}/superfedora/forge-build"
mkdir -p "$TMP_BUILD"
export TMPDIR="$TMP_BUILD" PATH="$BIN_DIR:$HOME/.cargo/bin:$SYSROOT/bin:/usr/bin:/bin:$PATH"
[[ -d "$SYSROOT" ]] && export LD_LIBRARY_PATH="$SYSROOT/lib64:${LD_LIBRARY_PATH:-}" LIBRARY_PATH="$SYSROOT/lib64:$HOME/.local/usr/lib64:$HOME/.local/lib:/usr/lib64" CPATH="$SYSROOT/include:$HOME/.local/usr/include" PKG_CONFIG_PATH="$SYSROOT/lib64/pkgconfig:$SYSROOT/share/pkgconfig:/usr/lib64/pkgconfig:/usr/share/pkgconfig"

detect_hw() {
    CPU_ARCH="$(uname -m)"
    CPU_MODEL="$(awk -F': ' '/^model name/{print $2; exit}' /proc/cpuinfo 2>/dev/null || echo "$CPU_ARCH")"
    CPU_JOBS="$(nproc 2>/dev/null || echo 4)"
    MARCH_TARGET=""
    command -v rustc >/dev/null 2>&1 && MARCH_TARGET="$(rustc --print target-cpus 2>/dev/null | sed -n 's/.*currently \([^)]*\)).*/\1/p' | head -1)"
    [[ -z "$MARCH_TARGET" && -x /usr/bin/gcc ]] && MARCH_TARGET="$(/usr/bin/gcc -march=native -Q --help=target 2>/dev/null | awk '/^\s*-march=/{print $2; exit}')"
    MARCH_TARGET="${MARCH_TARGET:-native}"
    ISA_FLAGS="$(grep -m1 '^flags' /proc/cpuinfo 2>/dev/null | grep -oE '\b(avx512f|avx2|avx|fma|bmi2|aes|vaes|sha_ni|sse4_2)\b' | sort -u | tr '\n' ' ' | sed 's/ $//' || echo "standard")"
    [[ -n "$ISA_FLAGS" ]] || ISA_FLAGS="standard"

    LINKER="bfd"; LD_FLAG=""; RUST_LD=""
    if command -v mold >/dev/null 2>&1; then
        LINKER="mold"; LD_FLAG="-fuse-ld=mold"; RUST_LD="-C link-arg=-fuse-ld=mold"
    elif command -v ld.lld >/dev/null 2>&1; then
        LINKER="lld"; LD_FLAG="-fuse-ld=lld"; RUST_LD="-C link-arg=-fuse-ld=lld"
    fi

    GPU_INFO="$(lspci 2>/dev/null | awk -F': ' '/VGA|3D|Display/{print $2; exit}' || echo "Wayland/DRM")"
    HOST_CFLAGS="-O3 -pipe -march=native -mtune=native -flto=auto -ffat-lto-objects -fno-plt"
    HOST_CXXFLAGS="-O3 -pipe -march=native -mtune=native -flto=auto -ffat-lto-objects -fno-plt"
    HOST_LDFLAGS="-Wl,-O1,--sort-common,--as-needed,-z,relro,-z,now -flto=auto ${LD_FLAG}"
    HOST_RUSTFLAGS="-C opt-level=3 -C target-cpu=native -C codegen-units=1 -C strip=symbols ${RUST_LD}"
}

ensure_pkgs() {
    local -a missing=()
    local p l
    for p in "$@"; do
        [[ "$p" =~ ^(gcc|gcc-c\+\+|make|cmake|ninja-build)$ ]] && command -v "${p%-build}" >/dev/null 2>&1 && continue
        rpm -q --quiet "$p" 2>/dev/null || [[ -f "$HOME/.local/pkg_cache/.ok-$p" ]] || missing+=("$p")
    done
    [[ ${#missing[@]} -eq 0 ]] && return 0
    if [[ $EUID -eq 0 ]]; then dnf install -y "${missing[@]}"
    elif [[ "${INSTALL_DEPS:-0}" -eq 1 ]]; then sudo dnf install -y "${missing[@]}"
    else
        echo "[+] Staging build headers into user sysroot: ${missing[*]}"
        mkdir -p "$HOME/.local/pkg_cache" "$HOME/.local/sysroot"
        dnf download --arch="$(uname -m),noarch" --destdir="$HOME/.local/pkg_cache" "${missing[@]}" >/dev/null 2>&1 || true
        for p in "$HOME/.local/pkg_cache"/*.rpm; do [[ -f "$p" ]] && (cd "$HOME/.local/sysroot" && rpm2cpio "$p" 2>/dev/null | cpio -idmu --quiet 2>/dev/null || true); done
        for l in "$SYSROOT/lib64"/lib*.so; do [[ -L "$l" && ! -e "$l" && -e "/usr/lib64/$(readlink "$l")" ]] && ln -sf "/usr/lib64/$(readlink "$l")" "$l" || true; done
        sed -i "s|/usr/lib64/libc_nonshared.a|$SYSROOT/lib64/libc_nonshared.a|g; s|/usr/lib64/libmvec_nonshared.a|$SYSROOT/lib64/libmvec_nonshared.a|g" "$SYSROOT/lib64/libc.so" "$SYSROOT/lib64/libm.so" 2>/dev/null || true
        sed -i "s|^prefix=/usr$|prefix=$SYSROOT|g; s|/usr/include|$SYSROOT/include|g" "$SYSROOT"/lib64/pkgconfig/*.pc "$SYSROOT"/share/pkgconfig/*.pc 2>/dev/null || true
        for p in "${missing[@]}"; do touch "$HOME/.local/pkg_cache/.ok-$p"; done
    fi
}

preset_deps() {
    case "$1" in
        ripgrep|rg|fd|zoxide) echo "gcc make" ;;
        idlescreen)           echo "gcc make pkgconf-pkg-config wayland-devel libxkbcommon-devel dbus-devel" ;;
        fastfetch)            echo "gcc gcc-c++ cmake ninja-build pkgconf-pkg-config pciutils-devel wayland-devel libdrm-devel glib2-devel" ;;
        btop)                 echo "gcc-c++ make" ;;
        wlctl|bluetui)        echo "gcc make pkgconf-pkg-config dbus-devel" ;;
        wiremix)              echo "gcc clang make pkgconf-pkg-config pipewire-devel alsa-lib-devel" ;;
        fuzzel)               echo "gcc meson ninja-build pkgconf-pkg-config wayland-devel wayland-protocols-devel libxkbcommon-devel pixman-devel cairo-devel pango-devel fcft-devel tllist-devel fontconfig-devel libpng-devel librsvg2-devel scdoc" ;;
        hyprland)             echo "gcc-c++ cmake meson ninja-build pkgconf-pkg-config wayland-devel wayland-protocols-devel cairo-devel pango-devel pixman-devel libdrm-devel mesa-libEGL-devel mesa-libGLES-devel libinput-devel libxkbcommon-devel libuuid-devel tomlplusplus-devel hyprlang-devel hyprcursor-devel hyprutils-devel hyprwayland-scanner-devel aquamarine-devel hyprgraphics-devel re2-devel muParser-devel" ;;
        quickshell)           echo "gcc-c++ cmake ninja-build pkgconf-pkg-config spirv-tools qt6-qtbase-devel qt6-qtbase-private-devel qt6-qtdeclarative-devel qt6-qtwayland-devel qt6-qtsvg-devel qt6-qtshadertools-devel wayland-devel wayland-protocols-devel libdrm-devel mesa-libgbm-devel pipewire-devel pam-devel cli11-devel jemalloc-devel" ;;
        *)                    echo "gcc gcc-c++ make cmake" ;;
    esac
}

record_forge() {
    local name="$1" repo="$2" bin="$3" sys="$4" ver
    mkdir -p "$STATE_DIR" "$STAMP_DIR"
    ver="$("$BIN_DIR/$bin" --version 2>/dev/null | head -1 || echo "native-$MARCH_TARGET")"
    printf 'component=%s\nrepo=%s\narch=%s\nbuilt_at=%s\ncflags=%s\nrustflags=%s\n' \
        "$name" "$repo" "$MARCH_TARGET" "$(date -u +%FT%TZ)" "$HOST_CFLAGS" "$HOST_RUSTFLAGS" > "$STAMP_DIR/$name.stamp"
    python3 - "$FORGE_JSON" "$name" "$repo" "$BIN_DIR/$bin" "$sys" "$MARCH_TARGET" "$LINKER" "$ver" <<'PY'
import datetime, json, os, re, sys
p, name, repo, bpath, bsys, arch, lnk, ver = sys.argv[1:9]
ver = re.sub(r"\x1b\[[0-9;]*m", "", ver).strip()
d = json.load(open(p)) if os.path.exists(p) else {}
d.setdefault("targets", {})[name] = {"repo": repo, "binary": bpath, "build_system": bsys, "march": arch, "linker": lnk, "version": ver, "built_at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")}
json.dump(d, open(p, "w"), indent=2)
PY
}

install_bin() {
    local src="$1" dst_name="${2:-$(basename "$1")}"
    mkdir -p "$BIN_DIR"
    install -m 755 "$src" "$BIN_DIR/.${dst_name}.tmp.$$" && mv -f "$BIN_DIR/.${dst_name}.tmp.$$" "$BIN_DIR/$dst_name"
    echo "[OK] Installed $BIN_DIR/$dst_name (-march=$MARCH_TARGET, linker=$LINKER)"
}

forge_generic_dir() {
    local dir="$1" name="$2" repo="$3" bin_hint="${4:-$2}" extra_cargo="${5:-}" cc_bin="gcc" cxx_bin="g++" found
    [[ -x /usr/bin/gcc ]] && cc_bin="/usr/bin/gcc"
    [[ -x /usr/bin/g++ ]] && cxx_bin="/usr/bin/g++"
    if [[ -f "$dir/Cargo.toml" ]]; then
        local rtarget="${CPU_ARCH}-unknown-linux-gnu"
        echo "[+] Building Rust project $name ($rtarget) with RUSTFLAGS='$HOST_RUSTFLAGS' (-j$CPU_JOBS)..."
        # shellcheck disable=SC2086
        (cd "$dir" && CC="$cc_bin" CXX="$cxx_bin" CFLAGS="$HOST_CFLAGS" CXXFLAGS="$HOST_CXXFLAGS" \
            RUSTFLAGS="$HOST_RUSTFLAGS" CARGO_BUILD_JOBS="$CPU_JOBS" cargo build --release --target "$rtarget" $extra_cargo)
        found="$dir/target/$rtarget/release/$bin_hint"
        [[ -x "$found" ]] || found="$dir/target/release/$bin_hint"
        [[ -x "$found" ]] || found="$(find "$dir/target/$rtarget/release" "$dir/target/release" -maxdepth 1 -type f -executable ! -name '*.so' ! -name '*.d' 2>/dev/null | head -1)"
        install_bin "$found" "$bin_hint"; record_forge "$name" "$repo" "$bin_hint" "cargo"
    elif [[ -f "$dir/CMakeLists.txt" ]]; then
        echo "[+] Building CMake project $name with CFLAGS='$HOST_CFLAGS' (-j$CPU_JOBS)..."
        local gen="-G Unix Makefiles" extra_cmake="-DBUILD_TESTING=OFF"
        command -v ninja >/dev/null 2>&1 && gen="-G Ninja"
        [[ "$name" == "quickshell" ]] && extra_cmake="-DBUILD_TESTING=OFF -DCRASH_REPORTER=OFF -DDISTRIBUTOR=SuperFedora"
        [[ "$name" == "hyprland" ]] && extra_cmake="-DNO_TESTS=ON -DBUILD_TESTING=OFF"
        # shellcheck disable=SC2086
        CC="$cc_bin" CXX="$cxx_bin" CFLAGS="$HOST_CFLAGS -ffat-lto-objects" CXXFLAGS="$HOST_CXXFLAGS -ffat-lto-objects" LDFLAGS="$HOST_LDFLAGS" \
            cmake -B "$dir/build" -S "$dir" $gen -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$HOME/.local" -Wno-dev $extra_cmake
        cmake --build "$dir/build" -j "$CPU_JOBS"
        found="$(find "$dir/build" -type f -executable -name "$bin_hint" | head -1)"
        [[ -n "$found" ]] || found="$(find "$dir/build" -maxdepth 3 -type f -executable ! -name '*.so*' ! -name 'CMake*' | head -1)"
        install_bin "$found" "$bin_hint"
        [[ "$name" == "quickshell" ]] && install_bin "$found" "qs"
        if [[ "$name" == "hyprland" ]]; then
            local hctl; hctl="$(find "$dir/build" -type f -executable -name "hyprctl" | head -1)"
            [[ -n "$hctl" ]] && install_bin "$hctl" "hyprctl"
        fi
        record_forge "$name" "$repo" "$bin_hint" "cmake"
    elif [[ -f "$dir/meson.build" ]]; then
        echo "[+] Building Meson project $name with CFLAGS='$HOST_CFLAGS' (-j$CPU_JOBS)..."
        CC="$cc_bin" CXX="$cxx_bin" CFLAGS="$HOST_CFLAGS" CXXFLAGS="$HOST_CXXFLAGS" LDFLAGS="$HOST_LDFLAGS" \
            meson setup "$dir/build" "$dir" --prefix="$HOME/.local" -Dbuildtype=release -Db_lto=true
        ninja -C "$dir/build" -j "$CPU_JOBS"
        found="$(find "$dir/build" -type f -executable -name "$bin_hint" | head -1)"
        install_bin "$found" "$bin_hint"; record_forge "$name" "$repo" "$bin_hint" "meson"
    elif [[ -f "$dir/Makefile" || -f "$dir/GNUmakefile" ]]; then
        echo "[+] Building Makefile project $name with OPTFLAGS='$HOST_CXXFLAGS' (-j$CPU_JOBS)..."
        CC="$cc_bin" CXX="$cxx_bin" make -C "$dir" OPTFLAGS="-O3 -march=native -mtune=native -flto=auto" -j "$CPU_JOBS"
        found="$(find "$dir" -maxdepth 2 -type f -executable -name "$bin_hint" | head -1)"
        install_bin "$found" "$bin_hint"; record_forge "$name" "$repo" "$bin_hint" "make"
    elif [[ -f "$dir/go.mod" ]]; then
        (cd "$dir" && CGO_CFLAGS="$HOST_CFLAGS" go build -ldflags="-s -w" -o "$bin_hint" ./...)
        install_bin "$dir/$bin_hint" "$bin_hint"; record_forge "$name" "$repo" "$bin_hint" "go"
    elif [[ -f "$dir/build.zig" ]]; then
        (cd "$dir" && zig build -Doptimize=ReleaseFast -Dcpu=native)
        install_bin "$dir/zig-out/bin/$bin_hint" "$bin_hint"; record_forge "$name" "$repo" "$bin_hint" "zig"
    else
        echo "error: no supported build manifest (Cargo.toml, CMakeLists.txt, meson.build, Makefile, go.mod, build.zig) in $dir" >&2
        return 1
    fi
}

forge_target() {
    local raw="$1" force="${2:-0}" dry="${3:-0}"
    detect_hw
    local name="$raw" repo="" bin="$raw" cargo_args="" local_src=""
    case "${raw,,}" in
        ripgrep|rg|burntsushi/ripgrep) name="ripgrep"; repo="https://github.com/BurntSushi/ripgrep.git"; bin="rg" ;;
        fastfetch|fastfetch-cli/fastfetch) name="fastfetch"; repo="https://github.com/fastfetch-cli/fastfetch.git"; bin="fastfetch" ;;
        idlescreen|idlescreen/idlescreen)
            name="idlescreen"; repo="https://github.com/idlescreen/idlescreen.git"; bin="idlescreen"; cargo_args="-p idlescreen --bin idlescreen"
            [[ -d "/home/jeryd/Projects/idlescreen/idlescreen" ]] && local_src="/home/jeryd/Projects/idlescreen/idlescreen" ;;
        fd|sharkdp/fd) name="fd"; repo="https://github.com/sharkdp/fd.git"; bin="fd" ;;
        zoxide|ajeetdsouza/zoxide) name="zoxide"; repo="https://github.com/ajeetdsouza/zoxide.git"; bin="zoxide" ;;
        btop|aristocratos/btop) name="btop"; repo="https://github.com/aristocratos/btop.git"; bin="btop" ;;
        wlctl|aashish-thapa/wlctl) name="wlctl"; repo="https://github.com/aashish-thapa/wlctl.git"; bin="wlctl" ;;
        bluetui|pythops/bluetui) name="bluetui"; repo="https://github.com/pythops/bluetui.git"; bin="bluetui" ;;
        wiremix|tsowell/wiremix) name="wiremix"; repo="https://github.com/tsowell/wiremix.git"; bin="wiremix" ;;
        fuzzel|dnkl/fuzzel) name="fuzzel"; repo="https://codeberg.org/dnkl/fuzzel.git"; bin="fuzzel" ;;
        hyprland|hyprwm/hyprland) name="hyprland"; repo="https://github.com/hyprwm/Hyprland.git"; bin="Hyprland" ;;
        quickshell|outfoxxed/quickshell|quickshell-mirror/quickshell) name="quickshell"; repo="https://github.com/quickshell-mirror/quickshell.git"; bin="quickshell" ;;
        */*)
            name="${raw##*/}"; name="${name%.git}"; bin="$name"
            [[ "$raw" == http*://* || "$raw" == git@* ]] && repo="$raw" || repo="https://github.com/${raw}.git" ;;
        *)
            echo "error: unknown preset '$raw' (use <owner>/<repo> or preset: ripgrep, fastfetch, idlescreen, fd, zoxide, btop, hyprland, quickshell)" >&2
            return 2 ;;
    esac

    if [[ "$dry" -eq 1 ]]; then
        printf '[DRY-RUN] Would forge %s (%s -> %s/%s) with -march=%s (%s threads, linker=%s)\n' "$name" "$repo" "$BIN_DIR" "$bin" "$MARCH_TARGET" "$CPU_JOBS" "$LINKER"
        printf '  Deps: %s\n' "$(preset_deps "$name")"
        return 0
    fi
    if [[ "$force" -eq 0 && -x "$BIN_DIR/$bin" && -f "$STAMP_DIR/$name.stamp" ]] && grep -q "^arch=$MARCH_TARGET$" "$STAMP_DIR/$name.stamp" 2>/dev/null; then
        echo "[OK] $name ($BIN_DIR/$bin) is already forged for $MARCH_TARGET (use --force to rebuild)"
        return 0
    fi
    # shellcheck disable=SC2046
    ensure_pkgs $(preset_deps "$name")
    if [[ -n "$local_src" ]]; then
        echo "[+] Building from local source tree $local_src..."
        forge_generic_dir "$local_src" "$name" "$repo" "$bin" "$cargo_args"
        return 0
    fi
    mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/superfedora/forge-build"
    local tmp; tmp="$(mktemp -d -p "${XDG_CACHE_HOME:-$HOME/.cache}/superfedora/forge-build")"
    trap 'rm -rf "${tmp:-}"' RETURN
    echo "[+] Cloning $repo..."
    git clone --depth 1 --recurse-submodules --shallow-submodules "$repo" "$tmp/src"
    forge_generic_dir "$tmp/src" "$name" "$repo" "$bin" "$cargo_args"
}

print_status() {
    detect_hw
    printf 'SuperFedora Forge — Hardware-Tuned Source Builder\n'
    printf '  CPU Model    : %s\n  Target Arch  : -march=%s (%s, %s threads)\n  SIMD / ISA   : %s\n  Fast Linker  : %s\n  GPU Device   : %s\n  CFLAGS       : %s\n  RUSTFLAGS    : %s\n\n' \
        "$CPU_MODEL" "$MARCH_TARGET" "$CPU_ARCH" "$CPU_JOBS" "$ISA_FLAGS" "$LINKER" "$GPU_INFO" "$HOST_CFLAGS" "$HOST_RUSTFLAGS"
    printf '  PRESET       BINARY            STATUS\n  ------       ------            ------\n'
    local p b st
    for p in ripgrep:rg fastfetch:fastfetch idlescreen:idlescreen fd:fd zoxide:zoxide btop:btop wlctl:wlctl bluetui:bluetui wiremix:wiremix fuzzel:fuzzel hyprland:Hyprland quickshell:quickshell; do
        b="${p#*:}"; p="${p%:*}"; st="not-forged"
        [[ -f "$STAMP_DIR/$p.stamp" && -x "$BIN_DIR/$b" ]] && st="forged ($MARCH_TARGET)"
        printf '  %-12s %-17s [%s]\n' "$p" "$b" "$st"
    done
}

FORCE=0; DRY=0; INSTALL_DEPS=0; ARGS=()
for a in "$@"; do
    case "$a" in
        --force|-f) FORCE=1 ;; --dry-run|-n) DRY=1 ;; --install) INSTALL_DEPS=1 ;;
        -h|--help|help) sed -n '7,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) ARGS+=("$a") ;;
    esac
done
CMD="${ARGS[0]:-status}"
case "$CMD" in
    status|list|presets|env|flags) print_status ;;
    deps)
        t="${ARGS[1]:-hyprland}"; echo "Dependencies for $t: $(preset_deps "$t")"
        # shellcheck disable=SC2046
        [[ $INSTALL_DEPS -eq 1 ]] && ensure_pkgs $(preset_deps "$t") || true ;;
    rebuild)
        [[ -f "$FORGE_JSON" ]] && for t in $(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(" ".join(d.get("targets",{}).keys()))' "$FORGE_JSON"); do forge_target "$t" 1 "$DRY"; done ;;
    *) for t in "${ARGS[@]}"; do forge_target "$t" "$FORCE" "$DRY"; done ;;
esac
