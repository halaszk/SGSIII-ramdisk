#!/sbin/busybox sh
#
##### Enable seed in awake mode by NeoPhyTe-x360 ##### 
BB=/sbin/busybox;

$BB renice 19 `pidof seed.sh`;
killall -9 rngd;
sleep 1
/sbin/rngd -B 64 -t 2 -T 1 -s 256 --fill-watermark=80%;
sleep 2
echo "-15" > /proc/$(pgrep rngd)/oom_adj;
$BB renice 0 `pidof rngd`;





