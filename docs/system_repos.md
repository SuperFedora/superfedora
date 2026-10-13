# System Repositories & Package Sources

This document provides a complete catalogue of all package repositories, COPR repositories, third-party signing keys, and package managers active on **Fedora Linux 44**.

---

## 1. Active Repositories Inventory

| Repo ID | Name / Description | Status | Repo Configuration Path |
| :--- | :--- | :--- | :--- |
| `fedora` | Fedora 44 - x86_64 Core | Enabled | `/etc/yum.repos.d/fedora.repo` |
| `updates` | Fedora 44 - Updates | Enabled | `/etc/yum.repos.d/fedora-updates.repo` |
| `updates-testing` | Fedora 44 - Test Updates | Disabled | `/etc/yum.repos.d/fedora-updates-testing.repo` |
| `fedora-cisco-openh264` | OpenH264 codec from Cisco | Enabled | `/etc/yum.repos.d/fedora-cisco-openh264.repo` |
| `rpmfusion-free` | RPM Fusion Free | Enabled | `/etc/yum.repos.d/rpmfusion-free.repo` |
| `rpmfusion-free-updates` | RPM Fusion Free Updates | Enabled | `/etc/yum.repos.d/rpmfusion-free-updates.repo` |
| `rpmfusion-nonfree` | RPM Fusion Non-Free | Enabled | `/etc/yum.repos.d/rpmfusion-nonfree.repo` |
| `rpmfusion-nonfree-updates` | RPM Fusion Non-Free Updates | Enabled | `/etc/yum.repos.d/rpmfusion-nonfree-updates.repo` |
| `rpmfusion-nonfree-steam` | RPM Fusion Non-Free Steam | Enabled | `/etc/yum.repos.d/rpmfusion-nonfree-steam.repo` |
| `rpmfusion-nonfree-nvidia-driver` | RPM Fusion NVIDIA Driver | Enabled | `/etc/yum.repos.d/rpmfusion-nonfree-nvidia-driver.repo` |
| `lionheartp/Hyprland` | Hyprland Wayland Suite COPR | Enabled | `/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:lionheartp:Hyprland.repo` (module `10-repos`) |
| `idlescreen` | IdleScreen Screensaver RPMs | Enabled | `/etc/yum.repos.d/idlescreen.repo` |
| `google-chrome` | Google Chrome Browser | Enabled | `/etc/yum.repos.d/google-chrome.repo` |
| `microsoft-edge` | Microsoft Edge Browser | Enabled | `/etc/yum.repos.d/microsoft-edge.repo` |
| `tailscale-stable` | Tailscale Mesh VPN | Enabled | `/etc/yum.repos.d/tailscale.repo` |
| `phracek/PyCharm` | PyCharm IDE COPR | Enabled | `/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:phracek:PyCharm.repo` |

---

## 2. Setup & Restoration Playbooks

### 2.1 RPM Fusion Setup & Codecs
To enable RPM Fusion Free and Non-Free repositories:
```bash
sudo dnf install -y \
  https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
```

To install hardware multimedia codec acceleration:
```bash
sudo dnf groupupdate -y multimedia --setop="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin
```

---

### 2.2 COPR: lionheartp/Hyprland
Maintained by the Fedora community to supply recent builds of Hyprland, Quickshell, Hypridle, Hyprlock, Hyprpaper, uwsm, and portals:
```bash
sudo dnf copr enable -y lionheartp/Hyprland
```

---

### 2.3 IdleScreen Repository Setup
The IdleScreen repository is authenticated with its dedicated GPG public key:
```bash
# 1. Download and import repository signing key
sudo mkdir -p /etc/pki/rpm-gpg
sudo curl -fsSL https://idlescreen.github.io/packages/rpm/idlescreen-key.gpg -o /etc/pki/rpm-gpg/idlescreen-key.gpg
sudo rpm --import /etc/pki/rpm-gpg/idlescreen-key.gpg

# 2. Add repository file
sudo curl -fsSL https://idlescreen.github.io/packages/rpm/idlescreen.repo -o /etc/yum.repos.d/idlescreen.repo

# 3. Install idlescreen package
sudo dnf install -y idlescreen
```

File content of `/etc/yum.repos.d/idlescreen.repo`:
```ini
[idlescreen]
name=IdleScreen RPM Repository
baseurl=https://idlescreen.github.io/packages/rpm
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/idlescreen-key.gpg
metadata_expire=1h
excludepkgs=idle-cosmic
```

---

### 2.4 Tailscale Repository
```bash
curl -fsSL https://tailscale.com/install.sh | sh
```
File content of `/etc/yum.repos.d/tailscale.repo`:
```ini
[tailscale-stable]
name=Tailscale stable
baseurl=https://pkgs.tailscale.com/stable/fedora/$basearch
enabled=1
type=rpm
repo_gpgcheck=1
gpgcheck=1
gpgkey=https://pkgs.tailscale.com/stable/fedora/repo.gpg
```

---

### 2.5 Chrome & Edge Repositories
- **Google Chrome**:
  ```ini
  [google-chrome]
  name=google-chrome
  baseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64
  enabled=1
  gpgcheck=1
  gpgkey=https://dl.google.com/linux/linux_signing_key.pub
  ```
- **Microsoft Edge**:
  ```ini
  [microsoft-edge]
  name=microsoft-edge
  baseurl=https://packages.microsoft.com/yumrepos/edge-stable
  enabled=1
  gpgcheck=1
  gpgkey=https://packages.microsoft.com/keys/microsoft.asc
  ```

---

### 2.6 PyCharm COPR
```bash
sudo dnf copr enable -y phracek/PyCharm
```
Provides community and professional builds of JetBrains PyCharm.
