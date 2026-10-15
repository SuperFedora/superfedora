# shellcheck shell=bash
# Copyright 2026 SuperFedora Contributors
# SPDX-License-Identifier: Apache-2.0
# desc: Developer toolchains (compilers, Node, Rust, uv)

module_run() {
    need_pkgs "$SF_ROOT/packages/dev.txt"

    need_script_tool "rustup + cargo" rustup https://sh.rustup.rs sh -y --no-modify-path
    _musl_t() { rustup target list --installed 2>/dev/null | grep >/dev/null x86_64-unknown-linux-musl; }
    _musl_i() { rustup target add x86_64-unknown-linux-musl; }
    command -v rustup >/dev/null && need "rust target x86_64-unknown-linux-musl" _musl_t _musl_i

    _binstall_t() { command -v cargo-binstall >/dev/null; }
    _binstall_i() { curl -L --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash; }
    command -v cargo >/dev/null && need "cargo-binstall" _binstall_t _binstall_i

    _cpkg_t() { command -v cargo-deb >/dev/null && command -v cargo-generate-rpm >/dev/null; }
    _cpkg_i() { cargo binstall -y cargo-deb cargo-generate-rpm; }
    command -v cargo-binstall >/dev/null && need "cargo-deb + cargo-generate-rpm" _cpkg_t _cpkg_i

    need_script_tool "uv / uvx" uv https://astral.sh/uv/install.sh sh

    # When --build-from-source is active, generate localhost -march=native profile & compile native targets
    if [[ "${SF_BUILD_MODE:-quick}" == "source" ]]; then
        _hw_t() { [[ -f "$SF_STATE/hardware-flags.env" ]]; }
        _hw_i() { "$SF_ROOT/lib/build-source.sh" profile; }
        need "localhost hardware profile (-march=native / target-cpu=native)" _hw_t _hw_i

        _src_t() {
            local c
            for c in superfedora wlctl bluetui wiremix tuigreet fuzzel btop; do
                [[ -f "$SF_STATE/source-built/$c.stamp" ]] || return 1
            done
        }
        _src_i() { "$SF_ROOT/lib/build-source.sh" all; }
        need "localhost native source builds (superfedora, wlctl, bluetui, wiremix, tuigreet, fuzzel, btop)" _src_t _src_i
    fi
}
