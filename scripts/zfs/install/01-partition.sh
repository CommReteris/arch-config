#!/usr/bin/env bash

set -e

print () {
    echo -e "\n\033[1m> $1\033[0m\n"
}

# Tests
ls /sys/firmware/efi/efivars > /dev/null && \
  ping archlinux.org -c 1 > /dev/null &&    \
  timedatectl set-ntp true > /dev/null &&   \
  print "Tests ok"

# Test to load zfs module
modprobe zfs

# Set DISK
select ENTRY in $(lsblk -ln -o NAME);
do
    DISK="/dev/$ENTRY"
    echo "Installing on $ENTRY."
    break
done

read -p "> Do you want to wipe all datas on $ENTRY ?" -n 1 -r
echo # move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
    # Clear disk
    dd if=/dev/zero of=$DISK bs=512 count=1
    wipefs -af $DISK
    sgdisk -Zo $DISK
fi

# EFI part
print "Creating EFI part"
sgdisk -n1:1M:+512M -t1:EF00 $DISK
EFI="$DISK"1

# ZFS part
print "Creating ZFS part"
sgdisk -n3:0:0 -t3:bf01 $DISK
ZFS="$DISK"3

# Inform kernel
partprobe $DISK

# Format boot part
sleep 1
print "Format EFI part"
mkfs.vfat $EFI

# Create ZFS pool
print "Create ZFS pool"
zpool create -f -o ashift=12           \
             -o autotrim=on            \
             -O acltype=posixacl       \
             -O compression=zstd       \
             -O relatime=on            \
             -O xattr=sa               \
             -O dnodesize=legacy       \
             -O encryption=aes-256-gcm \
             -O keyformat=passphrase   \
             -O keylocation=prompt     \
             -O normalization=formD    \
             -O mountpoint=none        \
             -O canmount=off           \
             -O devices=off            \
             -R /mnt                   \
             rpool $ZFS


# Home dataset
print "Create home dataset"

zfs create -o mountpoint=none              rpool/ROOT
zfs create                                 rpool/home
zfs create -o mountpoint=/root             rpool/home/root

zpool export -af
