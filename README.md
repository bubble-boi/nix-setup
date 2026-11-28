# Note

## Shortcuts
| Key | Action |
|---|---|
| `Win + Enter` | Temporary Terminal |
| `Win + Shift + Enter` | Work Terminal  |
| `Win + R` | Launcher |
| `Win + V` | Clipboard |
| `Win + L` | Lock |
| `Win + M` | Logout |
| `Win + Shift + A` | Full screenshot |
| `Win + Shift + S` | Area screenshot |
| `Win + Shift + D` | Color picker |
| `Caps Lock` | Toggle IME |
| `Fn + F5 / F6` | Brightness - / + |
| `Fn + F2 / F3` | Volume - / + |

## Install

Run as root after mounting the target filesystems at `/mnt` and `/mnt/boot`.
The hardware configuration is machine-specific; regenerate it for each installation.

```bash
mkdir -p /mnt/etc
git clone https://github.com/bubble-boi/nix-setup.git /mnt/etc/nixos
nixos-generate-config --root /mnt

nix-channel --add https://channels.nixos.org/nixos-26.05 nixos
nix-channel --update
nixos-install
nixos-enter --root /mnt -c 'passwd qwe'
```

## Relocate

```bash
mkdir -p /mnt/home/qwe
mv /mnt/etc/nixos /mnt/home/qwe/nix-setup
nixos-enter --root /mnt -c 'chown -R qwe:users /home/qwe'
ln -s /home/qwe/nix-setup /mnt/etc/nixos

reboot
```

## Update

```bash
cd ~/nix-setup
git pull --ff-only && rebuild-offline
```

Use `rebuild` when downloads are needed. Automatic upgrades run at 03:00 and garbage collection at 04:00. Module imports are declared explicitly in `configuration.nix`.
