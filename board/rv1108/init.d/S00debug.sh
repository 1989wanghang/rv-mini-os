#!/bin/sh

mount -t debugfs none /sys/kernel/debug

echo "/mnt/sdcard/core-%p-%e.$(date "+%Y%m%d_%H%M%S")" > /proc/sys/kernel/core_pattern
ulimit -c unlimited
