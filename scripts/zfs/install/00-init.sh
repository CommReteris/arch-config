#!/usr/bin/env bash

set -e

print () {
    echo -e "\n\033[1m> $1\033[0m"
}

print "Testing if archiso is running"

grep 'arch.*iso' /proc/cmdline >/dev/null

print "Increasing cowspace to half of RAM"

mount -o remount,size=50% /run/archiso/cowspace

modprobe zfs
