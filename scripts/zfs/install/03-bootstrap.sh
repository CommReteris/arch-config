#!/usr/bin/env bash

set -e

print () {
    echo -e "\n\033[1m> $1\033[0m\n"
}
# Collect hostname
echo "Please enter hostname :"
read hostname

# Root dataset
root_dataset=$(cat /tmp/root_dataset)

# Sort mirrors
print "Sort mirrors"
pacman -Sy reflector --noconfirm
reflector --country us --country Canada --latest 6 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
systemctl start reflector

# Install
print "Install Arch Linux"
pacstrap /mnt base base-devel linux linux-headers linux-firmware intel-ucode efibootmgr nano git ansible iwd wpa_supplicant nano-syntax-highlighting

# Generate fstab excluding ZFS entries
print "Generate fstab excluding ZFS entries"
genfstab -U -p /mnt | grep -v "rpool" | tr -s '\n' | sed 's/\/mnt//'  > /mnt/etc/fstab
 
# Set hostname
echo $hostname > /mnt/etc/hostname

# Configure /etc/hosts
print "Configure hosts file"
cat > /mnt/etc/hosts <<EOF
#<ip-address>	<hostname.domain.org>	<hostname>
127.0.0.1	    localhost   	        $hostname
::1   		    localhost              	$hostname
EOF

# Prepare locales and keymap
print "Prepare locales and keymap"
echo 'set KEYMAP "en_US.utf8"' > /mnt/etc/vconsole.conf
sed -i 's/#\(en_US.UTF-8\)/\1/' /mnt/etc/locale.gen
echo 'set LANG "en_US.UTF-8"' > /mnt/etc/locale.conf

# Prepare initramfs
print "Prepare initramfs"
cat > /mnt/etc/mkinitcpio.conf <<"EOF"
MODULES=()
BINARIES=()
FILES=()
HOOKS=(base udev autodetect modconf block keyboard zfs filesystems)
COMPRESSION="lz4"
EOF

print "Copy ZFS files"
cp /etc/hostid /mnt/etc/hostid
cp /etc/zfs/zpool.cache /mnt/etc/zfs/zpool.cache
cp /etc/zfs/zroot.key /mnt/etc/zfs

### Configure username
print 'Set your username'
read -r -p "Username: " user

# Chroot and configure
print "Chroot and configure system"

arch-chroot /mnt /bin/bash -xe <<EOF

  # ZFS deps
  pacman-key --recv-keys F75D9D76
  ### Reinit keyring
  # As keyring is initialized at boot, and copied to the install dir with pacstrap, and ntp is running
  # Time changed after keyring initialization, it leads to malfunction
  # Keyring needs to be reinitialised properly to be able to sign archzfs key.
  rm -Rf /etc/pacman.d/gnupg
  pacman-key --init
  pacman-key --populate archlinux
  pacman-key --recv-keys F75D9D76
  pacman-key --lsign-key F75D9D76
  pacman -S archlinux-keyring --noconfirm
  cat >> /etc/pacman.conf <<"EOSF"

[archzfs]
Server = https://zxcvfdsa.com/archzfs/archzfs/x86_64
Server = http://archzfs.com/archzfs/x86_64
Server = https://mirror.biocrafting.net/archlinux/archzfs/archzfs/x86_64

EOSF

  # chaotic-aur (source: https://aur.chaotic.cx/)
  pacman-key --recv-key FBA220DFC880C036 --keyserver keyserver.ubuntu.com
  pacman-key --lsign-key FBA220DFC880C036
  pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

  cat >> /etc/pacman.conf <<"EOSF"

[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist

EOSF

  pacman -Syu --noconfirm zfs-dkms-git zfs-utils-git

  # Sync clock
  hwclock --systohc

  # Set date
  timedatectl set-ntp true
  timedatectl set-timezone America/New_York

  # Generate locale
  locale-gen
  source /etc/locale.conf

  # Generate Initramfs
  mkinitcpio -P

  # Create user
  useradd -M greeter
  useradd $user

EOF

# Set root passwd
print "Set root password"
arch-chroot /mnt /bin/passwd

# Set user passwd
print "Set user password"
arch-chroot /mnt /bin/passwd "$user"

# Configure sudo
print "Configure sudo"
cat > /mnt/etc/sudoers <<EOF
root ALL=(ALL) ALL
$user ALL=(ALL) NOPASSWD: ALL
Defaults rootpw
EOF

# Configure network
print "Configure networking"
cat > /mnt/etc/systemd/network/enoX.network <<"EOF"
[Match]
Name=en*

[Network]
DHCP=ipv4
IPForward=yes

[DHCP]
UseDNS=yes
RouteMetric=10
EOF
cat > /mnt/etc/systemd/network/wlX.network <<"EOF"
[Match]
Name=wl*

[Network]
DHCP=ipv4
IPForward=yes

[DHCP]
UseDNS=yes
RouteMetric=20
EOF
systemctl enable systemd-networkd --root=/mnt
systemctl disable systemd-networkd-wait-online --root=/mnt

mkdir -p /mnt/etc/iwd
cat > /mnt/etc/iwd/main.conf <<"EOF"
[General]
EnableNetworkConfiguration=true
EOF
systemctl enable iwd --root=/mnt

# Activate zfs
print "Configure ZFS"
systemctl enable zfs-import-cache --root=/mnt
systemctl enable zfs-mount --root=/mnt
systemctl enable zfs-import.target --root=/mnt
systemctl enable zfs.target --root=/mnt

# Configure zfs-mount-generator
print "Configure zfs-mount-generator"
rm /mnt/etc/zfs/*.cache
mkdir -p /mnt/etc/zfs/zfs-list.cache
touch /mnt/etc/zfs/zfs-list.cache/rpool
zfs list -H -o name,mountpoint,canmount,atime,relatime,devices,exec,readonly,setuid,nbmand | sed 's/\/mnt//' > /mnt/etc/zfs/zfs-list.cache/rpool
ln -sf /usr/lib/zfs/zed.d/history_event-zfs-list-cacher.sh /mnt/etc/zfs/zed.d
systemctl enable zfs-zed.service --root=/mnt
systemctl enable zfs.target --root=/mnt
zfs set org.zfsbootmenu:commandline="rw verbose nowatchdog" rpool/ROOT/"$root_dataset"
# Generate hostid
print "Generate hostid"
arch-chroot /mnt zgenhostid $(hostid)

arch-chroot /mnt /bin/bash -xe <<"EOF"
  su -l $user
  git clone --recursive https://github.com/CommReteris/arch-config
  cd arch-config/ansible
  ansible-playbook install-zfs.yml -vvK
EOF

# Umount all parts
print "Umount all parts"
umount -l /mnt/boot/efi
zfs umount -a
umount -l /mnt

# Export rpool
print "Export rpool"
zpool export -f rpool

# Finish
echo -e "\e[32mAll OK"
