# nix-setup

## Installation

### USB

```bash
wget -c https://channels.nixos.org/nixos-26.05/latest-nixos-minimal-x86_64-linux.iso
lsblk -o NAME,SIZE,TYPE,MODEL,MOUNTPOINTS
sudo dd if=latest-nixos-minimal-x86_64-linux.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

### Boot

```bash
sudo -i
loadkeys jp106
test -d /sys/firmware/efi/efivars || exit 1
```

For wireless：

```bash
nmcli device wifi list
nmcli --ask device wifi connect "SSID"
```

### Partition

```bash
DISK=/dev/nvme0n1
ESP=/dev/nvme0n1p1
ROOT=/dev/nvme0n1p2

parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart ESP fat32 1MiB 1025MiB
parted -s "$DISK" set 1 esp on
parted -s "$DISK" mkpart primary ext4 1025MiB 100%

partprobe "$DISK"
udevadm settle

mkfs.fat -F 32 -n BOOT "$ESP"
mkfs.ext4 -L nixos "$ROOT"

mount "$ROOT" /mnt
mkdir -p /mnt/boot
mount -o umask=077 "$ESP" /mnt/boot
```

### Install

```bash
mkdir -p /mnt/etc
git clone https://github.com/bubble-boi/nix-setup.git /mnt/etc/nixos
nixos-generate-config --root /mnt

nixos-install --flake path:/mnt/etc/nixos#nixos
nixos-enter --root /mnt -c 'passwd qwe'
```

### Relocate

```bash
mkdir -p /mnt/home/qwe
mv /mnt/etc/nixos /mnt/home/qwe/nix-setup
nixos-enter --root /mnt -c 'chown -R qwe:users /home/qwe'
ln -s /home/qwe/nix-setup /mnt/etc/nixos

reboot
```

### Rebuild

```bash
rebuild && hyprctl -i 0 reload
```

## Shortcuts

| Key | Action |
|---|---|
| `Super + Enter` | Temporary Terminal |
| `Super + Shift + Enter` | Work Terminal  |
| `Super + B` | Chrome |
| `Super + I` | Kate |
| `Super + P` | Wallpapers |
| `Super + V` | Clipboard |
| `Super + L` | Lock |
| `Super + M` | Logout |
| `Ctrl + Shift + P` | Color picker |
| `Ctrl + Shift + S` | Area screenshot |
| `Ctrl + Shift + A` | Full screenshot |
| `Caps Lock` | Toggle IME |
| `Fn + F5 / F6` | Brightness |
| `Fn + F2 / F3` | Volume |
