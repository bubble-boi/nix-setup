# nix-setup

## Preparation

### Get ISO

```bash
wget -c https://channels.nixos.org/nixos-26.05/latest-nixos-minimal-x86_64-linux.iso
```

### Create a Bootable USB

```bash
lsblk -o NAME,SIZE,TYPE,MODEL,MOUNTPOINTS

sudo dd \
  if=latest-nixos-minimal-x86_64-linux.iso \
  of=/dev/sdX \
  bs=4M status=progress conv=fsync
```

Replace `/dev/sdX` with the USB device. All data on the selected device will be overwritten.

## Installation

### Initialize

```bash
sudo -i

loadkeys jp106

test -d /sys/firmware/efi/efivars || {
  echo "UEFI boot required"
  exit 1
}

lsblk -o NAME,SIZE,TYPE,MODEL,MOUNTPOINTS
```

### Network

Check the network connection:

```bash
nmcli device status
```

If using Wi-Fi:

```bash
nmcli radio wifi on
nmcli device wifi list
nmcli --ask device wifi connect "SSID"
```

Verify connectivity:

```bash
ping -c 3 nixos.org
```

### Partition

Set `DISK` to the installation target. All existing partitions on the selected disk will be destroyed.

```bash
DISK=/dev/nvme0n1

test -b "$DISK" || exit 1

case "$DISK" in
  *[0-9])
    ESP="${DISK}p1"
    ROOT="${DISK}p2"
    ;;
  *)
    ESP="${DISK}1"
    ROOT="${DISK}2"
    ;;
esac

parted -s "$DISK" -- mklabel gpt
parted -s "$DISK" -- mkpart ESP fat32 1MiB 1025MiB
parted -s "$DISK" -- set 1 esp on
parted -s "$DISK" -- mkpart primary ext4 1025MiB 100%

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

git clone \
  https://github.com/bubble-boi/nix-setup.git \
  /mnt/etc/nixos

nixos-generate-config --root /mnt
```

Ensure `configuration.nix` contains:

```nix
networking.networkmanager.enable = true;
```

And that `qwe` belongs to the `networkmanager` group:

```nix
extraGroups = [ "wheel" "networkmanager" ];
```

### Install

```bash
nixos-install --flake path:/mnt/etc/nixos#nixos

nixos-enter --root /mnt -c 'passwd qwe'
```

### Relocate Configuration

```bash
nixos-enter --root /mnt -c \
  'mkdir -p /home/qwe && chown qwe:users /home/qwe'

mv /mnt/etc/nixos /mnt/home/qwe/nix-setup

nixos-enter --root /mnt -c \
  'chown -R qwe:users /home/qwe/nix-setup'

ln -s /home/qwe/nix-setup /mnt/etc/nixos
```

### Reboot

```bash
reboot
```

## Maintenance

Rebuild the system:

```bash
rebuild
```

Equivalent command:

```bash
sudo nixos-rebuild switch \
  --flake path:/home/qwe/nix-setup#nixos
```

Automatic updates are scheduled daily at 03:00, followed by garbage collection at 04:00.

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
| `rebuild` | Rebuild and activate the NixOS configuration |
| `browser` | Launch Google Chrome |
| `ide` | Launch Kate |
| `ide <path>` | Open a file or directory in Kate |
| `clip 1` | Start monitoring text clipboard history |
| `clip 2` | Start monitoring image clipboard history |
| `clip 3` | Open clipboard history and paste the selected entry |
| `grab color` | Pick a screen color and copy it |
| `grab area` | Capture a selected screen region |
| `grab full` | Capture the entire screen |
| `wl-copy` | Copy data to the Wayland clipboard through Bubblewrap |
| `c` | Clear the terminal |

Screenshots are saved to `~/.Screenshots/` and copied to the clipboard.

`clip 1` and `clip 2` start automatically with Hyprland.

## Shortcuts

### Hyprland

`Super` is the Windows key.

| Shortcut | Action |
|---|---|
| `Super + Enter` | Open Alacritty |
| `Super + B` | Open Google Chrome |
| `Super + L` | Lock the screen |
| `Super + V` | Open clipboard history |
| `Super + Shift + P` | Pick a color |
| `Super + Shift + S` | Capture a selected region |
| `Super + Shift + A` | Capture the entire screen |
| `Caps Lock` | Toggle Fcitx5 input method |
| `Brightness Up` | Increase brightness |
| `Brightness Down` | Decrease brightness |
| `Super + C` | Close the active window |
| `Super + W` | Toggle floating, resize and center |
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
| `Alt + N` | Split horizontally |
| `Alt + Shift + N` | Split vertically |
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
