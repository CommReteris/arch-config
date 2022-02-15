### EFI install

- sda1
  /boot
  FAT used as esp
- sda2
  ZFS pool


##### Boot latest arch iso

``00-init.sh`` will 
- curl init script from https://eoli3n.github.io
- source: https://github.com/eoli3n/archiso-zfs

``01-configure.sh`` will 
- Create partition scheme
- Format everything
- Mount partitions

``02-install.sh`` will
- Configure mirrors
- Install Arch Linux and kernel
- Generate initramfs
- Configure hostname, locales, keymap, network
- Install and configure bootloader
- Generate users and passwords

Boot latest archiso

```
loadkeys us
pacman -Sy git
git clone https://github.com/CommReteris/arch-config
cd arch-config/scripts/install
./01-configure.sh
./02-install.sh
```
