# nix-setup

## Preparation

### Get ISO

```bash
wget -c https://channels.nixos.org/nixos-26.05/latest-nixos-minimal-x86_64-linux.iso
```

### Create a Bootable USB

```bash
lsblk -o NAME,SIZE,TYPE,MODEL,MOUNTPOINTS

sudo dd if=latest-nixos-minimal-x86_64-linux.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

Replace `/dev/sdX` with the USB device. All data on the selected device will be overwritten.

## Installation

Commands in this section are intended to be typed manually in the NixOS minimal installer.

### Initialize

```bash
sudo -i
loadkeys jp106
test -d /sys/firmware/efi/efivars || exit 1
lsblk -o NAME,SIZE,TYPE,MODEL,MOUNTPOINTS
```

### Network

Check connectivity:

```bash
nmcli device status
ping -c 3 nixos.org
```

For Wi-Fi:

```bash
nmcli radio wifi on
nmcli device wifi list
nmcli --ask device wifi connect "SSID"
```

### Partition

Set the installation disk and partition paths. The example uses an NVMe SSD; for SATA, use paths such as `/dev/sda`, `/dev/sda1`, and `/dev/sda2`.

All existing partitions on the selected disk will be destroyed.

```bash
DISK=/dev/nvme0n1
ESP=/dev/nvme0n1p1
ROOT=/dev/nvme0n1p2

test -b "$DISK" || exit 1

parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart ESP fat32 1MiB 1025MiB
parted -s "$DISK" set 1 esp on
parted -s "$DISK" mkpart primary ext4 1025MiB 100%

partprobe "$DISK"
udevadm settle
```

### Format and Mount

```bash
mkfs.fat -F 32 -n BOOT "$ESP"
mkfs.ext4 -L nixos "$ROOT"

mount "$ROOT" /mnt
mkdir -p /mnt/boot
mount -o umask=077 "$ESP" /mnt/boot

lsblk -f
```

### Configure

```bash
mkdir -p /mnt/etc
git clone https://github.com/bubble-boi/nix-setup.git /mnt/etc/nixos
nixos-generate-config --root /mnt
```

### Install

```bash
nixos-install --flake path:/mnt/etc/nixos#nixos
nixos-enter --root /mnt -c 'passwd qwe'
```

### Relocate Configuration

```bash
mkdir -p /mnt/home/qwe
mv /mnt/etc/nixos /mnt/home/qwe/nix-setup
nixos-enter --root /mnt -c 'chown -R qwe:users /home/qwe'
ln -s /home/qwe/nix-setup /mnt/etc/nixos
```

### Reboot

```bash
reboot
```

## Maintenance

### Rebuild

```bash
rebuild
```

Equivalent command:

```bash
sudo nixos-rebuild switch --flake path:/home/qwe/nix-setup#nixos
```

### Automatic Updates

| Schedule | Action |
|---|---|
| 03:00 daily | Update Flake inputs and rebuild NixOS |
| 04:00 daily | Nix garbage collection |

### Recovery

List system generations:

```bash
nixos-rebuild list-generations
```

Roll back to the previous generation:

```bash
sudo nixos-rebuild switch --rollback
```

For boot failures, select an older NixOS generation from the systemd-boot menu.

## Network

### Status

```bash
nmcli general status
nmcli device status
nmcli connection show --active
```

### Wi-Fi

```bash
nmcli radio wifi on
nmcli device wifi list
nmcli --ask device wifi connect "SSID"
```

### Connections

```bash
nmcli connection show
nmcli connection up "NAME"
nmcli connection down "NAME"
```

### Network Interface

```bash
ip address
ip route
```

## Commands

| Command | Description |
|---|---|
| `rebuild` | Rebuild and activate NixOS |
| `browser` | Launch Google Chrome |
| `ide` | Launch Kate |
| `ide <path>` | Open a file or directory in Kate |
| `clip 1` | Monitor text clipboard history |
| `clip 2` | Monitor image clipboard history |
| `clip 3` | Select and paste clipboard history |
| `grab color` | Pick a screen color and copy it |
| `grab area` | Capture a selected screen region |
| `grab full` | Capture the entire screen |
| `wl-copy` | Copy to Wayland clipboard through Bubblewrap |
| `c` | Clear the terminal |

Screenshots are saved to `~/.Screenshots/` and copied to the clipboard.

`clip 1` and `clip 2` start automatically with Hyprland.

## Shortcuts

### Hyprland

`Super` is the Windows key.

| Shortcut | Action |
|---|---|
| `Super + Enter` | Open Alacritty |
| `Super + Shift + Enter` | Open floating Alacritty (50% × 50%, centered) |
| `Super + B` | Open Google Chrome |
| `Super + L` | Lock the screen |
| `Super + M` | Exit Hyprland (binding to be added) |
| `Super + V` | Open clipboard history |
| `Super + Shift + P` | Pick a color |
| `Super + Shift + S` | Capture a selected region |
| `Super + Shift + A` | Capture the entire screen |
| `Caps Lock` | Toggle Fcitx5 input method |
| `Brightness Up` | Increase brightness |
| `Brightness Down` | Decrease brightness |
| `Super + C` | Close the active window |
| `Super + W` | Toggle floating, resize to 30% × 30% and center |
| `Super + U` | Toggle pseudotiling |
| `Super + J` | Toggle split orientation |
| `Super + Arrow` | Move focus |
| `Super + Shift + Arrow` | Move the active window |
| `Super + 1–9` | Switch to workspace 1–9 |
| `Super + 0` | Switch to workspace 10 |
| `Super + Shift + 1–9` | Move window to workspace 1–9 |
| `Super + Shift + 0` | Move window to workspace 10 |
| `Super + Left Mouse Drag` | Move window |
| `Super + Shift + Left Mouse Drag` | Resize window |

### tmux

Default prefix: `Ctrl + B`

| Shortcut | Action |
|---|---|
| `Alt + N` | Split horizontally (side by side) |
| `Alt + Shift + N` | Split vertically (top and bottom) |
| `Ctrl + B`, then `A` | Toggle synchronized pane input |

### Zsh

| Shortcut | Action |
|---|---|
| `Up / Down` | Search command history by prefix |
| `Ctrl + Left / Right` | Move backward or forward by word |
| `Home / End` | Move to the beginning or end of the line |
| `Shift + Tab` | Select previous completion |
| `Page Up / Page Down` | Navigate editing buffer or history |
| `Insert` | Toggle overwrite mode |
