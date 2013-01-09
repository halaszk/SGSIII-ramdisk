#!/sbin/busybox sh
# Logging
#/sbin/busybox cp /data/user.log /data/user.log.bak
#/sbin/busybox rm /data/user.log
#exec >>/data/user.log
#exec 2>&1

BB="/sbin/busybox";

# first mod the partitions then boot
$BB sh /sbin/ext/system_tune_on_init.sh;

PIDOFINIT=`pgrep -f "/sbin/ext/post-init.sh"`;
for i in $PIDOFINIT; do
echo "-600" > /proc/$i/oom_score_adj;
done;

if [ ! -d /data/.siyah ]; then
$BB mkdir -p /data/.siyah;
fi;

ccxmlsum=`md5sum /res/customconfig/customconfig.xml | awk '{print $1}'`
if [ "a${ccxmlsum}" != "a`cat /data/.siyah/.ccxmlsum`" ];
then
#  rm -f /data/.siyah/*.profile
  echo ${ccxmlsum} > /data/.siyah/.ccxmlsum;
fi
[ ! -f /data/.siyah/default.profile ] && cp /res/customconfig/default.profile /data/.siyah;
[ ! -f /data/.siyah/battery.profile ] && cp /res/customconfig/battery.profile /data/.siyah/battery.profile;
[ ! -f /data/.siyah/performance.profile ] && cp /res/customconfig/performance.profile /data/.siyah/performance.profile;

$BB chmod 0777 /data/.siyah/ -R;

. /res/customconfig/customconfig-helper;
read_defaults;
read_config;

#mdnie sharpness tweak
if [ "$mdniemod" == "on" ];then
. /sbin/ext/mdnie-sharpness-tweak.sh;
fi

# Cortex parent should be ROOT/INIT and not STweaks
nohup /sbin/ext/cortexbrain-tune.sh; 

#nohup /sbin/ext/multitaskfix.sh; 

if [ "$logger" == "on" ];then
insmod /lib/modules/logger.ko
fi

# disable debugging on some modules
if [ "$logger" == "off" ];then
  rm -rf /dev/log
  echo 0 > /sys/module/ump/parameters/ump_debug_level;
  echo 0 > /sys/module/mali/parameters/mali_debug_level;
  echo 0 > /sys/module/kernel/parameters/initcall_debug;
  echo 0 > /sys//module/lowmemorykiller/parameters/debug_level;
  echo 0 > /sys/module/earlysuspend/parameters/debug_mask;
  echo 0 > /sys/module/alarm/parameters/debug_mask;
  echo 0 > /sys/module/alarm_dev/parameters/debug_mask;
  echo 0 > /sys/module/binder/parameters/debug_mask;
  echo 0 > /sys/module/xt_qtaguid/parameters/debug_mask;
fi

if [ "$gesture_tweak" == "on" ]; then
echo "1" > /sys/devices/virtual/misc/touch_gestures/gestures_enabled;
pkill -f "/data/gesture_set.sh";
pkill -f "/sys/devices/virtual/misc/touch_gestures/wait_for_gesture";
nohup $BB sh /data/gesture_set.sh;
fi;
if [ "$exfat" == "on" ]; then
insmod /lib/modules/exfat_core.ko;
insmod /lib/modules/exfat_fs.ko;
fi;

######################################
# Loading Modules
######################################
$BB chmod -R 755 /lib;

(
	sleep 40;
	# order of modules load is important.
	$BB insmod /lib/modules/scsi_wait_scan.ko;
	$BB insmod /lib/modules/j4fs.ko;

	sleep 10;
	$BB insmod /lib/modules/auth_rpcgss.ko;
	$BB insmod /lib/modules/nfs.ko;
	$BB insmod /lib/modules/cifs.ko;
	$BB insmod /lib/modules/sunrpc.ko;
	$BB insmod /lib/modules/mvpkm.ko;
	$BB insmod /lib/modules/lockd.ko;
	$BB insmod /lib/modules/pvtcpkm.ko;
)&

if [ "$logger" == "off" ];then
rmmod /lib/modules/logger.ko
fi
if [ "$exfat" == "off" ]; then
rmmod /lib/modules/exfat_core.ko;
rmmod /lib/modules/exfat_fs.ko;
fi;
# for ntfs automounting
insmod /lib/modules/fuse.ko;
mount -o remount,rw /
mkdir -p /mnt/ntfs
chmod 777 /mnt/ntfs
mount -o mode=0777,gid=1000 -t tmpfs tmpfs /mnt/ntfs
mount -o remount,ro /

(
	$BB sh /sbin/ext/install.sh
)&

(
##### Early-init phase tweaks #####
	$BB sh /sbin/ext/tweaks.sh
)&

(
	$BB sh /sbin/ext/killing_samsung_apps.sh &
)&

(
        $BB sh /sbin/ext/smoothlauncher.sh &
)&


# enable kmem interface for everyone by GM
echo "0" > /proc/sys/kernel/kptr_restrict;
(
# Stop uci.sh from running all the PUSH Buttons in stweaks on boot.
$BB mount -o remount,rw rootfs;
$BB chown root:system /res/customconfig/actions/ -R;
$BB chmod 6755 /res/customconfig/actions/*;
$BB chmod 6755 /res/customconfig/actions/push-actions/*;
$BB mv /res/customconfig/actions/push-actions/* /res/no-push-on-boot/;

# set root access script.
$BB chmod 6755 /sbin/ext/cortexbrain-tune.sh;

# apply STweaks settings
echo "booting" > /data/.siyah/booting;
pkill -f "com.gokhanmoral.stweaks.app";
$BB sh /res/uci.sh restore;

# restore all the PUSH Button Actions back to there location
$BB mount -o remount,rw rootfs;
$BB mv /res/no-push-on-boot/* /res/customconfig/actions/push-actions/;
pkill -f "com.gokhanmoral.stweaks.app";
$BB rm -f /data/.siyah/booting;
# ==============================================================
# STWEAKS FIXING
# ==============================================================
# change USB mode MTP or Mass Storage
/res/customconfig/actions/usb-mode ${usb_mode};
)&

	$BB mount -t rootfs -o remount,rw rootfs;

##### EFS Backup #####
(
	$BB sh /sbin/ext/efs-backup.sh;
) &


PIDOFACORE=`pgrep -f "android.process.acore"`;
for i in $PIDOFACORE; do
echo "-800" > /proc/${i}/oom_score_adj;
renice -15 -p $i;
log -p 10 i -t boot "*** do not kill -> android.process.acore ***";
done;

##### init scripts #####

if [ $init_d == on ]; then
$BB sh /sbin/ext/run-init-scripts.sh;
fi;
# run partitions tune after full boot
$BB sh /sbin/ext/partitions-tune.sh

