#!/usr/bin/env bash

zpool import -f -N -R /mnt rpool
print "Load keys"
zfs load-key -a -L 'prompt'

# Slash dataset
print "Create slash dataset"
zfs create -o mountpoint=none                           rpool/ARCH/ROOT
zfs create -o mountpoint=/ -o canmount=noauto           rpool/ARCH/ROOT/arch
zfs create -o mountpoint=/home -o canmunt=noauto        rpool/ARCH/home
zfs create -o mountpoint=/root -o canmount=noauto       rpool/ARCH/home/root
zfs create -o mountpoint=/home/rengo -o canmount=noauto rpool/ARCH/home/rengo

# Manually mount slash dataset
zfs mount rpool/ARCH/ROOT/arch
zfs mount rpool/ARCH/home
zfs mount rpool/ARCH/home/root
zfs mount rpool/ARCH/home/rengo

# Mount EFI part
print "Mount EFI part"
mkdir -p /mnt/boot/efi
mount /dev/sda1 /mnt/boot/efi

# Copy ZFS cache
print "Generate and copy zfs cache"
mkdir -p /mnt/etc/zfs
zpool set cachefile=/etc/zfs/rpool.cache rpool
cp /etc/zfs/rpool.cache /mnt/etc/zfs/rpool.cache

# Finish
echo -e "\e[32mAll OK"
