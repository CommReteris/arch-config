#!/usr/bin/env bash

read -r -p "> ZFS passphrase: " -s pass
echo
echo "$pass" > /etc/zfs/rpool.key
chmod 000 /etc/zfs/rpool.key

zpool import -f -N -R /mnt rpool
print "Load keys"
zfs load-key -a

# Slash dataset
print "Create slash dataset"
zfs create -o mountpoint=/ -o canmount=noauto           rpool/ROOT/arch

# Manually mount slash dataset
zfs mount rpool/ROOT/arch
zfs mount -a

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
