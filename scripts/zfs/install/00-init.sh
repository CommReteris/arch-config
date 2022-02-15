#!/usr/bin/env bash


print "Testing if archiso is running"

grep 'arch.*iso' /proc/cmdline >/dev/null

print "Increasing cowspace to half of RAM"

mount -o remount,size=50% /run/archiso/cowspace
