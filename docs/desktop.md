# Desktop Environment: Hyprland + Quickshell (COSMIC keybindings)

The SuperFedora desktop is an Omarchy-style Hyprland session with a Quickshell bar, themed Tokyo Night, using **Pop!_OS COSMIC keybindings**. Every file listed here lives in [`dotfiles/`](../dotfiles) and is deployed by [`scripts/install-dotfiles.sh`](../scripts/install-dotfiles.sh).

The full keybinding reference is generated from the config: **[keybindings.md](keybindings.md)**.

---

## 1. Components

| Component | Role | Package source | Config (in `dotfiles/`) |
| :--- | :--- | :--- | :--- |
| **Hyprland** | Wayland tiling compositor | COPR `lionheartp/Hyprland` | `.config/hypr/hyprland.conf` + `conf/*.conf` |
| **Quickshell** | Bar, notifications, volume OSD | Fedora | `.config/quickshell/*.qml` |
| **Hypridle** | Idle → screensaver → lock → DPMS → suspend | COPR | `.config/hypr/hypridle.conf` |
| **Hyprlock** | Lock screen | COPR | `.config/hypr/hyprlock.conf` |
| **Hyprpaper** 0.8 | Wallpaper (block config + IPC) | Fedora | `.config/hypr/hyprpaper.conf` |
| **Fuzzel** | Launcher and every menu | Fedora | `.config/fuzzel/fuzzel.ini` |
| **kitty** | Terminal, internal tiling disabled | Fedora | `.config/kitty/kitty.conf` |
| **IdleScreen** | ASCII screensaver started by hypridle | IdleScreen RPM repo | `.config/idlescreen/config.toml` |
| **hyprland-session.target** | Activates `graphical-session.target` for portals and user services | SuperFedora | `.config/systemd/user/hyprland-session.target` |
| **xdg-terminal-exec** | Default-terminal shim (`$terminal`) | SuperFedora | `.local/bin/xdg-terminal-exec` |
| **JetBrainsMono Nerd Font** | Bar icons, fuzzel, hyprlock | nerd-fonts release | `~/.local/share/fonts/JetBrainsMonoNerd` |

Helpers used by bindings and the bar: `grim`, `slurp`, `wl-clipboard`, `hyprpicker`, `libnotify`, `playerctl`, `wireplumber` (`wpctl`), `brightnessctl`, `jq`, `NetworkManager` (`nmcli`), `orca`, `nautilus`, `gnome-calculator`, `gnome-control-center`, `firefox`.

---

## 2. Hyprland layout

`hyprland.conf` only sources the files in `conf/`; edit those.

| File | Contents |
| :--- | :--- |
| `monitors.conf` | `monitor = , preferred, auto, 1` |
| `envs.conf` | Default apps (`$terminal`, `$browser`, `$fileManager` resolved from XDG defaults), `PATH` including `~/.local/bin`, Wayland toolkit variables, cursor |
| `autostart.conf` | Environment export to systemd/D-Bus, starts `hyprland-session.target` (activates `graphical-session.target`), polkit agent, `quickshell`, `hypridle`, `hyprpaper` |
| `input.conf` | Keyboard, touchpad, gestures: 3-finger ←→ workspaces, 3↑ scratchpad, 4↑ fullscreen, 4↓ float |
| `looknfeel.conf` | Tokyo Night borders, gaps, square corners, animations, tab-group (stack) styling |
| `windows.conf` | Window rules (Hyprland 0.53+ `windowrule = match:…` syntax) |
| `bindings.conf` | COSMIC keybindings, then SuperFedora extras on keys COSMIC leaves free |

> [!NOTE]
> GDM starts Hyprland directly (`start-hyprland`, not uwsm), which has two side effects SuperFedora corrects:
> - `PATH` is only `/usr/local/bin:/usr/bin`, so `envs.conf` adds `$HOME/.local/bin` for keybindings that launch user-installed tools.
> - Nothing activates `graphical-session.target`, so `xdg-desktop-portal` (screen sharing, file pickers, dark-mode hints) and `idlescreen.service` never start. `autostart.conf` starts `~/.config/systemd/user/hyprland-session.target`, which binds to it, and stops it on exit.

### Scripts (`.config/hypr/scripts/`)

| Script | Used by |
| :--- | :--- |
| `menu.sh` | Fuzzel menus: main, capture, toggles, style, setup, system/power |
| `keybindings.sh` | Super+F1 searchable binding list (from `hyprctl binds`) |
| `focus.sh` | Stack-aware focus: walks tabs in a group before moving to the next window |
| `windows.sh` | Super+W window switcher |
| `toggle-tiling.sh` | Super+Y float/tile every window on the workspace |
| `zoom.sh` | Super+= / Super+- screen magnifier |
| `screenshot.sh` | Region / window / screen captures to `~/Pictures/Screenshots` + clipboard |
| `wallpaper.sh` | Next / pick wallpaper through hyprpaper IPC |
| `toggle-idle.sh`, `toggle-gaps.sh`, `toggle-touchpad.sh`, `toggle-screenreader.sh`, `restart-shell.sh` | Toggles |

---

## 3. Keybindings (COSMIC)

Bindings mirror `pop-os/cosmic-comp` `data/keybindings.ron` entry for entry. Highlights:

| Keys | Action |
| :--- | :--- |
| Super + T / B / F | Terminal / browser / file manager |
| Super + Q, Alt + F4 | Close window |
| Tap Super, Super + A, Super + / | Launcher |
| Super + arrows / HJKL | Focus (stack-aware) |
| Super + Shift + arrows / HJKL | Move window (joins and leaves stacks) |
| Super + 1–9, Super + 0 | Workspace N, last (empty) workspace |
| Super + Ctrl + arrows | Previous / next workspace |
| Super + Alt + arrows | Focus monitor |
| Super + S / Y / G / O / X | Stack, toggle tiling, float, split orientation, swap mode |
| Super + M, Super + F11 | Maximize, fullscreen |
| Super + R | Resize mode |
| Super + Esc | Lock |
| Super + Space | Next keyboard layout |

Approximations where Hyprland has no direct COSMIC equivalent: **Focus out/in** (Super+U/I) cycle windows; **Super+W** is a searchable window list rather than a visual grid; **Super+Y** floats/tiles the whole workspace.

See **[keybindings.md](keybindings.md)** for all 150+ bindings.

---

## 4. Idle, screensaver and lock chain

Hypridle owns `org.freedesktop.ScreenSaver` on Hyprland and drives IdleScreen:

| Idle time | Action |
| :--- | :--- |
| 2 min | `idlescreen start` (stopped again on activity) |
| 5 min | Lock with hyprlock (`loginctl lock-session`) |
| 10 min | Displays off (DPMS) |
| 30 min | Suspend, **on battery only** |

`lock_cmd` stops the screensaver before hyprlock appears. Super+Shift+I starts the screensaver immediately; Super+Ctrl+I toggles stay-awake (hypridle off), shown in the bar.

> [!IMPORTANT]
> Starting IdleScreen from hypridle needs IdleScreen **4.1.22+**, which calls its own D-Bus name (`io.github.idlescreen.Idle`) first instead of `org.freedesktop.ScreenSaver`.

---

## 5. Quickshell bar

| File | Purpose |
| :--- | :--- |
| `shell.qml` | One bar per screen, notifications, OSD; IPC target `bar` (`qs ipc call bar toggle`) |
| `Bar.qml` | Menu button, workspaces, submap indicator, clock, tray, stay-awake, Bluetooth, network, audio, CPU, battery, power |
| `Workspaces.qml` | Workspaces 1–5 always visible, plus any others in use |
| `Notifications.qml` | Notification server and popups; IPC `notifications` (`dismiss`, `dismissAll`, `toggleDnd`) |
| `Osd.qml` | Volume popup |
| `Status.qml`, `Theme.qml`, `BarLabel.qml`, `Tray.qml` | Shared state, colours, widgets |

---

## 6. Updating a running system

```bash
cd SuperFedora
git pull
./scripts/install-dotfiles.sh          # copies changed files, backs up the old ones, reloads Hyprland
./scripts/install-dotfiles.sh --check  # lists anything that differs from the repo
```
