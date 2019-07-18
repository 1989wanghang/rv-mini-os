#!/bin/sh
date
mkdir -p /dev/pts
mount -t devpts none /dev/pts

echo 1 > /sys/module/rockchip_pm/parameters/policy
#ddr frequency:
#  'l' = 400M
#  'n' = 600M
#  'p' = 800M
echo 'p' > /dev/video_state
