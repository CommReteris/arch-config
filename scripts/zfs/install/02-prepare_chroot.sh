#!/usr/bin/env bash

zpool import -f -N -R /mnt rpool
print "Load keys"
zfs load-key -a -L 'prompt'

# Slash dataset
print "Create slash dataset"
zfs create -o mountpoint=/ -o canmount=noauto rpool/ROOT/arch

# Manually mount slash dataset
zfs mount rpool/ROOT/arch

# Specific datasets
print "Create specific datasets excluded from snapshots"
zfs create -o mountpoint=/var -o canmount=off     rpool/var
zfs create                                        rpool/var/log
zfs create -o mountpoint=/var/lib -o canmount=off rpool/var/lib
zfs create                                        rpool/var/lib/libvirt
zfs create                                        rpool/var/lib/docker

zfs mount rpool/ROOT/arch
zfs mount -a

# Mount EFI part
print "Mount EFI part"
mkdir -p /mnt/boot/efi
mount /de/sda1 /mnt/boot/efi

# Copy ZFS cache
print "Generate and copy zfs cache"
mkdir -p /mnt/etc/zfs
zpool set cachefile=/etc/zfs/rpool.cache rpool
cp /etc/zfs/rpool.cache /mnt/etc/zfs/rpool.cache

# Finish
echo -e "\e[32mAll OK"
