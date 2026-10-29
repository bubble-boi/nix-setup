# nix-setup

## Preparation
* Get ISO
```bash
wget -c https://channels.nixos.org/nixos-26.05/latest-nixos-minimal-x86_64-linux.iso
```

* Create a Bootable USB
```bash
sudo dd if=latest-nixos-minimal-x86_64-linux.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

## Installation
```bash
sudo -i

loadkeys jp106

parted -s /dev/sda -- mklabel gpt
parted -s /dev/sda -- mkpart ESP fat32 1MiB 1025MiB
parted -s /dev/sda -- set 1 esp on
parted -s /dev/sda -- mkpart primary ext4 1025MiB 100%

mkfs.fat -F 32 -n BOOT /dev/sda1
mkfs.ext4 -L nixos /dev/sda2

mount /dev/sda2 /mnt
mkdir -p /mnt/boot
mount -o umask=077 /dev/sda1 /mnt/boot
lsblk -f

mkdir -p /mnt/etc

git clone https://github.com/bubble-boi/nix-setup.git /mnt/etc/nixos

nixos-generate-config --root /mnt

nixos-install

nixos-enter --root /mnt -c 'passwd qwe'

reboot
```