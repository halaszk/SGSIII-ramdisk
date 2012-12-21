#!/sbin/busybox sh

#Credits:
# Zacharias.maladroit
# Voku1987
# Collin_ph@xda
# Dorimanx@xda
# Gokhanmoral@xda
# Johnbeetee
# halaszk

# TAKE NOTE THAT LINES PRECEDED BY A "#" IS COMMENTED OUT.
# This script must be activated after init start =< 25sec or parameters from /sys/* will not be loaded.

# read setting from profile

# Get values from profile. since we dont have the recovery source code i cant change the .siyah dir, so just leave it there for history.
PROFILE=`cat /data/.siyah/.active.profile`;
. /data/.siyah/$PROFILE.profile;

FILE_NAME=$0;
PIDOFCORTEX=$$;

# default settings (1000 = 10 seconds)
dirty_expire_centisecs_default=1000;
dirty_writeback_centisecs_default=1000;

# battery settings
dirty_expire_centisecs_battery=0;
dirty_writeback_centisecs_battery=0;

# =========
# Renice - kernel thread responsible for managing the swap memory and logs
# =========
renice 15 -p `pgrep -f "kswapd0"`;
renice 15 -p `pgrep -f "logcat"`;

# replace kernel version info for repacked kernels
cat /proc/version | grep infra && (kmemhelper -t string -n linux_proc_banner -o 15 `cat /res/version`);

# ==============================================================
# I/O-TWEAKS 
# ==============================================================
IO_TWEAKS()
{
	if [ "$cortexbrain_io" == on ]; then
		MMC=`ls -d /sys/block/mmc*`;
		ZRM=`ls -d /sys/block/zram*`;

		for z in $ZRM; do
	
			if [ -e $i/queue/rotational ]; then
				echo "0" > $i/queue/rotational;
			fi;

			if [ -e $i/queue/iostats ]; then
				echo "0" > $i/queue/iostats;
			fi;

			if [ -e $i/queue/rq_affinity ]; then
				echo "1" > $i/queue/rq_affinity;
			fi;

			if [ -e $i/queue/read_ahead_kb ]; then
				echo "512" >  $i/queue/read_ahead_kb;
			fi;

			if [ -e $i/queue/max_sectors_kb ]; then
				echo "512" >  $i/queue/max_sectors_kb; # default: 127
			fi;

		done;

		for i in $MMC; do

			if [ -e $i/queue/scheduler ]; then
				echo $scheduler > $i/queue/scheduler;
			fi;

			if [ -e $i/queue/rotational ]; then
				echo "0" > $i/queue/rotational;
			fi;

			if [ -e $i/queue/iostats ]; then
				echo "0" > $i/queue/iostats;
			fi;

			if [ -e $i/queue/read_ahead_kb ]; then
				echo $read_ahead_kb >  $i/queue/read_ahead_kb; # default: 128
			fi;

			if [ -e $i/queue/nr_requests ]; then
				echo "20" > $i/queue/nr_requests; # default: 128
			fi;

			if [ -e $i/queue/iosched/back_seek_penalty ]; then
				echo "1" > $i/queue/iosched/back_seek_penalty; # default: 2
			fi;

			if [ -e $i/queue/iosched/slice_idle ]; then
				echo "2" > $i/queue/iosched/slice_idle; # default: 8
			fi;

			if [ -e $i/queue/iosched/fifo_batch ]; then
				echo "1" > $i/queue/iosched/fifo_batch;
			fi;

		done;

		if [ -e /sys/devices/virtual/bdi/default/read_ahead_kb ]; then
			echo $read_ahead_kb > /sys/devices/virtual/bdi/default/read_ahead_kb;
		fi;

		SDCARDREADAHEAD=`ls -d /sys/devices/virtual/bdi/179*`;
		for i in $SDCARDREADAHEAD; do
			echo $read_ahead_kb > $i/read_ahead_kb;
		done;

		echo "10" > /proc/sys/fs/lease-break-time;
		echo "524288" > /proc/sys/fs/file-max;
		echo "32000" > /proc/sys/fs/inotify/max_queued_events;
		echo "256" > /proc/sys/fs/inotify/max_user_instances;
		echo "10240" > /proc/sys/fs/inotify/max_user_watches;

		echo NO_NORMALIZED_SLEEPER > /sys/kernel/debug/sched_features;
		echo NO_NEW_FAIR_SLEEPERS > /sys/kernel/debug/sched_features;

		log -p i -t $FILE_NAME "*** IO_TWEAKS ***: enabled";
	fi;
}
IO_TWEAKS;

# ==============================================================
# KERNEL-TWEAKS
# ==============================================================
KERNEL_TWEAKS()
{
	if [ "$cortexbrain_kernel_tweaks" == on ]; then
		echo "1" > /proc/sys/vm/oom_kill_allocating_task;
		sysctl -w vm.panic_on_oom=0;
		echo "65536" > /proc/sys/kernel/msgmax;
		echo "2048" > /proc/sys/kernel/msgmni;
		echo "128" > /proc/sys/kernel/random/read_wakeup_threshold;
		echo "256" > /proc/sys/kernel/random/write_wakeup_threshold;
		echo "500 512000 64 2048" > /proc/sys/kernel/sem;
		echo "2097152" > /proc/sys/kernel/shmall;
		echo "268435456" > /proc/sys/kernel/shmmax;
		echo "524288" > /proc/sys/kernel/threads-max;
  		/sbin/busybox sysctl -w kernel.panic=10;
	
		log -p i -t $FILE_NAME "*** KERNEL_TWEAKS ***: enabled";
	fi;
}
KERNEL_TWEAKS;

# ==============================================================
# SYSTEM-TWEAKS
# ==============================================================
SYSTEM_TWEAKS()
{
	if [ "$cortexbrain_system" == on ]; then
		# render UI with GPU
		setprop hwui.render_dirty_regions false;
		setprop windowsmgr.max_events_per_sec 100;
		# enable Hardware Rendering
	setprop video.accelerate.hw 1;
	setprop debug.performance.tuning 1;
	setprop debug.sf.hw 1;
	setprop persist.sys.use_dithering 1;
#	setprop persist.sys.ui.hw true; # ->reported as problem maker in some roms.

	# render UI with GPU
	setprop hwui.render_dirty_regions false;
	setprop windowsmgr.max_events_per_sec 120;
	setprop profiler.force_disable_err_rpt 1;
	setprop profiler.force_disable_ulog 1;

	# Proximity tweak
	setprop mot.proximity.delay 15;

	# more Tweaks
	setprop dalvik.vm.execution-mode int:jit;
	setprop persist.adb.notify 0;
	setprop pm.sleep_mode 1;

	# =========
	# Optimized Audio and Video Settings
	# =========
	setprop ro.media.enc.jpeg.quality 100;
	setprop ro.media.dec.jpeg.memcap 8000000;
	setprop ro.media.enc.hprof.vid.bps 8000000;
	setprop ro.media.capture.maxres 8m;
	#setprop ro.media.capture.fast.fps 4
	#setprop ro.media.capture.slow.fps 120
	#setprop ro.media.capture.flashMinV 3300000
	#setprop ro.media.capture.torchIntensity 40
	#setprop ro.media.capture.flashIntensity 70
	setprop ro.media.panorama.defres 3264x1840;
	setprop ro.media.panorama.frameres 1280x720;
	setprop ro.camcorder.videoModes true;
	setprop ro.media.enc.hprof.vid.fps 65;
	#setprop ro.service.swiqi.supported true
	#setprop persist.service.swiqi.enable 1
	setprop media.stagefright.enable-player true;
	setprop media.stagefright.enable-meta true;
	setprop media.stagefright.enable-scan true;
	setprop media.stagefright.enable-http true;
	setprop media.stagefright.enable-rtsp=true;
	setprop media.stagefright.enable-record false;

		log -p i -t $FILE_NAME "*** SYSTEM_TWEAKS ***: enabled";
	fi;
}
SYSTEM_TWEAKS;

# ==============================================================
# BATTERY-TWEAKS
# ==============================================================
BATTERY_TWEAKS()
{
	if [ "$cortexbrain_battery" == on ]; then
	  # vm tweaks
	  /sbin/busybox sysctl -w vm.dirty_background_ratio=70;
	  /sbin/busybox sysctl -w vm.dirty_ratio=90;
	  /sbin/busybox sysctl -w vm.vfs_cache_pressure=10;

	# System tweaks: Hardcore speedmod
	  # vm tweaks
	  echo "12288" > /proc/sys/vm/min_free_kbytes
	  echo "1500" > /proc/sys/vm/dirty_writeback_centisecs
	  echo "200" > /proc/sys/vm/dirty_expire_centisecs
	
	if [ "$power_reduce" == on ]; then
	# LCD Power-Reduce
	if [ -e /sys/class/lcd/panel/power_reduce ]; then
	echo "1" > /sys/class/lcd/panel/power_reduce;
	fi;
	else
	if [ -e /sys/class/lcd/panel/power_reduce ]; then
	echo "0" > /sys/class/lcd/panel/power_reduce;
	fi;
		fi;

		# USB power support
		for i in `ls /sys/bus/usb/devices/*/power/level`; do
			chmod 777 $i;
			echo "auto" > $i;
		done;
		for i in `ls /sys/bus/usb/devices/*/power/autosuspend`; do
			chmod 777 $i;
			echo "1" > $i;
		done;

		# BUS power support
		buslist="spi i2c sdio";
		for bus in $buslist; do
			for i in `ls /sys/bus/$bus/devices/*/power/control`; do
				chmod 777 $i;
				echo "auto" > $i;
			done;
		done;

		log -p i -t $FILE_NAME "*** BATTERY_TWEAKS ***: enabled";
	fi;
}

# ==============================================================
# CPU-TWEAKS
# ==============================================================

CPU_GOV_TWEAKS()
{
	if [ "$cortexbrain_cpu" == on ]; then
  echo "500000" > /sys/devices/system/cpu/cpufreq/pegasusq/hotplug_freq_1_1;
  echo "800000" > /sys/devices/system/cpu/cpufreq/pegasusq/hotplug_freq_2_1;
  echo "800000" > /sys/devices/system/cpu/cpufreq/pegasusq/hotplug_freq_3_1;
  echo "400000" > /sys/devices/system/cpu/cpufreq/pegasusq/hotplug_freq_2_0;
  echo "600000" > /sys/devices/system/cpu/cpufreq/pegasusq/hotplug_freq_3_0;
  echo "600000" > /sys/devices/system/cpu/cpufreq/pegasusq/hotplug_freq_4_0;
  echo "100" > /sys/devices/system/cpu/cpufreq/pegasusq/hotplug_rq_1_1;
  echo "100" > /sys/devices/system/cpu/cpufreq/pegasusq/hotplug_rq_2_0;
  echo "200" > /sys/devices/system/cpu/cpufreq/pegasusq/hotplug_rq_2_1;
  echo "200" > /sys/devices/system/cpu/cpufreq/pegasusq/hotplug_rq_3_0;
  echo "300" > /sys/devices/system/cpu/cpufreq/pegasusq/hotplug_rq_3_1;
  echo "300" > /sys/devices/system/cpu/cpufreq/pegasusq/hotplug_rq_4_0;
  echo "80" > /sys/devices/system/cpu/cpufreq/pegasusq/up_threshold;
  echo "$max_cpu_lock" > /sys/devices/system/cpu/cpufreq/pegasusq/max_cpu_lock;
  echo "80" > /sys/devices/system/cpu/cpufreq/pegasusq/up_threshold_at_min_freq;
  echo "10" > /sys/devices/system/cpu/cpufreq/pegasusq/cpu_down_rate;
  echo "$lcdfreq_enable" > /sys/devices/system/cpu/cpufreq/peqasusq/lcdfreq_enable;

		log -p i -t $FILE_NAME "*** CPU_GOV_TWEAKS ***: enabled";
	fi;
}

# ==============================================================
# MEMORY-TWEAKS
# ==============================================================
MEMORY_TWEAKS()
{
	if [ "$cortexbrain_memory" == on ]; then
		echo "$dirty_expire_centisecs_default" > /proc/sys/vm/dirty_expire_centisecs;
		echo "$dirty_writeback_centisecs_default" > /proc/sys/vm/dirty_writeback_centisecs;
		echo "4" > /proc/sys/vm/min_free_order_shift; # default: 4
		echo "0" > /proc/sys/vm/overcommit_memory; # default: 0
		echo "50" > /proc/sys/vm/overcommit_ratio; # default: 50
		echo "128 128" > /proc/sys/vm/lowmem_reserve_ratio;
		echo "3" > /proc/sys/vm/page-cluster; # default: 3
		echo "8192" > /proc/sys/vm/min_free_kbytes;
		# =========
# VM Settings
# =========
mem=`free|grep Mem | awk '{print $2}'`;
if [ "$mem" -lt 524288 ];then
	sysctl -w vm.dirty_background_ratio=20;
	sysctl -w vm.dirty_ratio=40;
elif [ "$mem" -lt 1049776 ];then
	sysctl -w vm.dirty_background_ratio=10;
	sysctl -w vm.dirty_ratio=20;
else 
	sysctl -w vm.dirty_background_ratio=5;
	sysctl -w vm.dirty_ratio=10;
fi;

		log -p i -t $FILE_NAME "*** MEMORY_TWEAKS ***: enabled";
	fi;
}
MEMORY_TWEAKS;

MULTITASKFIX()
{
		if [ "$cortexbrain_multitaskingfix" == on ]; then
		#Low memory killer tweaks
		#ALL OPENED APPS IN LATEST 4 SECONDS ARE LOCKED IN MEMORY EVERY 4 SECONDS so the possibility of killed apps is now ridicolous! (0 battery drain!!)
		#Better performance without any lags up to 12 apps running in same time (MAX 20 APPS RUNNING IN SAME TIME WITH A 301 APPS INSTALLED IN MY SCENARIO!)
		#Optimized for multiwindow use!
		#Minfree changed for best performaced and quick app load!
		echo "2560,5120,6912,12800,15104,17152" > /sys/module/lowmemorykiller/parameters/minfree;
(
	MULTITASK_CHECK=`pgrep -f "/sbin/ext/multitaskfix.sh" | wc -l`;
	if [ "$MULTITASK_CHECK" == 0 ]; then
	nohup /sbin/ext/multitaskfix.sh > /dev/null 2>&1;
	fi;
)&
		log -p i -t $FILE_NAME "*** MULTITASKFIX ***: enabled";
		fi;
		
	if [ "$cortexbrain_multitaskingfix" == off ]; then
	pkill -f "/sbin/ext/multitaskfix.sh";
	fi;
}
MULTITASKFIX;
# ==============================================================
# TCP-TWEAKS
# ==============================================================
TCP_TWEAKS()
{
	if [ "$cortexbrain_tcp" == on ]; then

		# =========
# Optimized for 3G/Edge speed and AGPS
# =========
	setprop ro.ril.hsxpa 3;
	setprop ro.ril.gprsclass 10;
	setprop ro.ril.hep 1;
	setprop ro.ril.enable.dtm 1;
	setprop ro.ril.hsdpa.category 10;
	setprop ro.ril.hsupa.category 5;
	setprop ro.ril.enable.a53 1;
	#setprop ro.ril.enable.a52 1
	setprop ro.ril.enable.3g.prefix 1;
	setprop ro.ril.htcmaskw1.bitmask 4294967295;
	setprop ro.ril.htcmaskw1 14449;
	#setprop ro.ril.def.agps.mode 2
	#setprop ro.ril.def.agps.feature 1
	#setprop ro.ril.enable.sdr 1
	#setprop ro.ril.enable.gea3 1
	#setprop ro.ril.enable.fd.plmn.prefix 23402,23410,23411
	setprop ro.ril.enable.amr.wideband 1;
	setprop ro.ril.fast.dormancy.rule 1;
	#setprop ro.ril.disable.mcc.filter 1
	#setprop ro.ril.emc.mode 1
	setprop ro.config.hw_fast_dormancy 0;
	#setprop ro.config.vc_call_steps 20
	setprop persist.cust.tel.eons 1;

		echo "0" > /proc/sys/net/ipv4/tcp_timestamps;
		echo "1" > /proc/sys/net/ipv4/tcp_tw_reuse;
		echo "1" > /proc/sys/net/ipv4/tcp_sack;
		echo "1" > /proc/sys/net/ipv4/tcp_tw_recycle;
		echo "1" > /proc/sys/net/ipv4/tcp_window_scaling;
		echo "1" > /proc/sys/net/ipv4/tcp_moderate_rcvbuf;
		echo "1" > /proc/sys/net/ipv4/route/flush;
		echo "2" > /proc/sys/net/ipv4/tcp_syn_retries;
		echo "2" > /proc/sys/net/ipv4/tcp_synack_retries;
		echo "10" > /proc/sys/net/ipv4/tcp_fin_timeout;
		echo "0" > /proc/sys/net/ipv4/tcp_ecn;
		echo "524288" > /proc/sys/net/core/wmem_max;
		echo "524288" > /proc/sys/net/core/rmem_max;
		echo "262144" > /proc/sys/net/core/rmem_default;
		echo "262144" > /proc/sys/net/core/wmem_default;
		echo "20480" > /proc/sys/net/core/optmem_max;
		echo "6144 87380 524288" > /proc/sys/net/ipv4/tcp_wmem;
		echo "6144 87380 524288" > /proc/sys/net/ipv4/tcp_rmem;
		echo "4096" > /proc/sys/net/ipv4/udp_rmem_min;
		echo "4096" > /proc/sys/net/ipv4/udp_wmem_min;
	  /sbin/busybox sysctl -w net.core.rmem_max=524288;
	  /sbin/busybox sysctl -w net.core.wmem_max=524288;
	  /sbin/busybox sysctl -w net.ipv4.tcp_rmem='6144 87380 524288';
	  /sbin/busybox sysctl -w net.ipv4.tcp_tw_recycle=1;
	  /sbin/busybox sysctl -w net.ipv4.tcp_wmem='6144 87380 524288';

		log -p i -t $FILE_NAME "*** TCP_TWEAKS ***: enabled";
	fi;
}
TCP_TWEAKS;

# ==============================================================
# FIREWALL-TWEAKS
# ==============================================================
FIREWALL_TWEAKS()
{
	if [ "$cortexbrain_firewall" == on ]; then
		# ping/icmp protection
		echo "1" > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts;
		echo "1" > /proc/sys/net/ipv4/icmp_echo_ignore_all;
		echo "1" > /proc/sys/net/ipv4/icmp_ignore_bogus_error_responses;

		# drop spoof, redirects, etc
		#echo "1" > /proc/sys/net/ipv4/conf/all/rp_filter;
		#echo "1" > /proc/sys/net/ipv4/conf/default/rp_filter;
		#echo "0" > /proc/sys/net/ipv4/conf/all/send_redirects;
		#echo "0" > /proc/sys/net/ipv4/conf/default/send_redirects;
		#echo "0" > /proc/sys/net/ipv4/conf/default/accept_redirects;
		#echo "0" > /proc/sys/net/ipv4/conf/all/accept_source_route;
		#echo "0" > /proc/sys/net/ipv4/conf/default/accept_source_route;

		log -p i -t $FILE_NAME "*** FIREWALL_TWEAKS ***: enabled";
	fi;
}
FIREWALL_TWEAKS;

# ==============================================================
# SCREEN-FUNCTIONS
# ==============================================================

ENABLE_WIFI_PM()
{
if [ "$wifi_pwr" == on ]; then
if [ -e /sys/module/dhd/parameters/wifi_pm ]; then
echo "1" > /sys/module/dhd/parameters/wifi_pm;
fi;
log -p i -t $FILE_NAME "*** WIFI_PM ***: enabled";
fi;
}

DISABLE_WIFI_PM()
{
if [ -e /sys/module/dhd/parameters/wifi_pm ]; then
echo "0" > /sys/module/dhd/parameters/wifi_pm;
log -p i -t $FILE_NAME "*** WIFI_PM ***: disabled";
fi;
}

ENABLE_LOGGER()
{
	if [ "$android_logger" == auto ] || [ "$android_logger" == debug ]; then
		if [ -e /dev/log-sleep ] && [ ! -e /dev/log ]; then
			mv /dev/log-sleep/ /dev/log/;
			log -p i -t $FILE_NAME "*** LOGGER ***: enabled";
		fi;
	fi;
}

DISABLE_LOGGER()
{
	if [ "$android_logger" == auto ] || [ "$android_logger" == disabled ]; then
		if [ -e /dev/log ]; then
			mv /dev/log/ /dev/log-sleep/;
			log -p i -t $FILE_NAME "*** LOGGER ***: disabled";
		fi;
	fi;
}

ENABLE_GESTURES()
{
	if [ "$gesture_tweak" == on ]; then
		echo "1" > /sys/devices/virtual/misc/touch_gestures/gestures_enabled;
		pkill -f "/data/gesture_set.sh";
		pkill -f "/sys/devices/virtual/misc/touch_gestures/wait_for_gesture";
		nohup /sbin/busybox sh /data/gesture_set.sh;
		log -p i -t $FILE_NAME "*** GESTURE ***: enabled";
	fi;
}

DISABLE_GESTURES()
{
	if [ `pgrep -f "/data/gesture_set.sh" | wc -l` != "0" ] || [ `pgrep -f "/sys/devices/virtual/misc/touch_gestures/wait_for_gesture" | wc -l` != "0" ] || [ "$gesture_tweak" == off ]; then
		pkill -f "/data/gesture_set.sh";
		pkill -f "/sys/devices/virtual/misc/touch_gestures/wait_for_gesture";
	fi;
	echo "0" > /sys/devices/virtual/misc/touch_gestures/gestures_enabled;
	log -p i -t $FILE_NAME "*** GESTURE ***: disabled";
}

ENABLE_KSM()
{
if [ "$run" == "1" ]; then
	# enable KSM on screen ON.
	KSM="/sys/kernel/mm/ksm/run";
	if [ -e "$KSM" ]; then
	echo "1" > $KSM;
	fi;
	log -p i -t $FILE_NAME "*** KSM ***: enabled";
fi;
}

DISABLE_KSM()
{
if [ "$run" == "0" ]; then
	# disable KSM on screen OFF
	KSM="/sys/kernel/mm/ksm/run";
	if [ -e "$KSM" ]; then
	echo "0" > $KSM;
	fi;
	log -p i -t $FILE_NAME "*** KSM ***: disabled";
fi;
}

# please don't kill "cortexbrain"
DONT_KILL_CORTEX()
{
	PIDOFCORTEX=`pgrep -f "/sbin/ext/cortexbrain-tune.sh"`;
	for i in $PIDOFCORTEX; do
		echo "-950" > /proc/${i}/oom_score_adj;
	done;
	PIDOFMALI=`pgrep -f "ru.services.malistatus"`;
        for i in $PIDOFMALI; do
                echo "-950" > /proc/${i}/oom_score_adj;
        done;

	log -p i -t $FILE_NAME "*** DONT_KILL_CORTEX ***";
}

MOUNT_SD_CARD()
{
        if [ "$auto_mount_sd" == on ]; then
echo "/dev/block/vold/179:48" > /sys/devices/virtual/android_usb/android0/f_mass_storage/lun0/file;
if [ -e /dev/block/vold/179:49 ]; then
echo "/dev/block/vold/179:49" > /sys/devices/virtual/android_usb/android0/f_mass_storage/lun1/file;
fi;
log -p i -t $FILE_NAME "*** MOUNT_SD_CARD ***";
fi;
}

# set wakeup booster delay to prevent mp3 music shattering when screen turned ON
WAKEUP_DELAY()
{
if [ "$wakeup_delay" != 0 ] && [ ! -e /data/.siyah/booting ]; then
log -p i -t $FILE_NAME "*** WAKEUP_DELAY ${wakeup_delay}sec ***";
sleep $wakeup_delay
fi;
}

WAKEUP_DELAY_SLEEP()
{
if [ "$wakeup_delay" != 0 ] && [ ! -e /data/.siyah/booting ]; then
log -p i -t $FILE_NAME "*** WAKEUP_DELAY_SLEEP ${wakeup_delay}sec ***";
sleep $wakeup_delay;
else
log -p i -t $FILE_NAME "*** WAKEUP_DELAY_SLEEP 3sec ***";
sleep 3;
fi;
}

# check if ROM booting now, then don't wait - creation and deletion of /data/.siyah/booting @> /sbin/ext/post-init.sh
WAKEUP_BOOST_DELAY()
{
if [ ! -e /data/.siyah/booting ] && [ "$wakeup_boost" != 0 ]; then
log -p i -t $FILE_NAME "*** WAKEUP_BOOST_DELAY ${wakeup_boost}sec ***";
sleep $wakeup_boost;
fi;
}

# boost CPU power for fast and no lag wakeup
MEGA_BOOST_CPU_TWEAKS()
{
if [ "$cortexbrain_cpu_boost" == on ]; then

echo "$scaling_governor" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor;
# GPU utilization to min delay
echo "100" > /sys/module/mali/parameters/mali_gpu_utilization_timeout;

	# bus freq to 400MHZ in low load
echo "30" > /sys/devices/system/cpu/cpufreq/busfreq_up_threshold;

echo "1400000" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq;
echo "1400000" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq;
if [ "$mali_resume_enable" == on ]; then
echo "$gpu_res_freq" > /sys/module/mali/parameters/step0_clk;
fi;
log -p i -t $FILE_NAME "*** MEGA_BOOST_CPU_TWEAKS ***";
fi;
}


# set less brightnes is battery is low
AUTO_BRIGHTNESS()
{
	if [ "$cortexbrain_auto_tweak_brightness" == on ]; then
		LEVEL=`cat /sys/class/power_supply/battery/capacity`;
		MAX_BRIGHTNESS=`cat /sys/class/backlight/panel/max_brightness`;
		OLD_BRIGHTNESS=`cat /sys/class/backlight/panel/brightness`;
		NEW_BRIGHTNESS=`$(( MAX_BRIGHTNESS*LEVEL/100 ))`;
		if [ "$NEW_BRIGHTNESS" -le "$OLD_BRIGHTNESS" ]; then
			echo "$NEW_BRIGHTNESS" > /sys/class/backlight/panel/brightness;
		fi;
		log -p i -t $FILE_NAME "*** AUTO_BRIGHTNESS ***";
	fi;
}


# set swappiness in case that no root installed, and zram used or disk swap used
SWAPPINESS()
{
	SWAP_CHECK=`free | grep Swap | awk '{ print $2 }'`;
	if [ "$zram" == 0 ] || [ "$SWAP_CHECK" == 0 ]; then
		echo "0" > /proc/sys/vm/swappiness;
		log -p i -t $FILE_NAME "*** SWAPPINESS ***: disabled";
	else
		echo "60" > /proc/sys/vm/swappiness;
		log -p i -t $FILE_NAME "*** SWAPPINESS ***: enabled";
	fi;
}

TUNE_IPV6()
{
	CISCO_VPN=`find /data/data/com.cisco.anyconnec* | wc -l`;
	if [ "$cortexbrain_ipv6" == on ] || [ "$CISCO_VPN" != 0 ]; then
		echo "0" > /proc/sys/net/ipv6/conf/wlan0/disable_ipv6;
		sysctl -w net.ipv6.conf.all.disable_ipv6=0;
		log -p i -t $FILE_NAME "*** TUNE_IPV6 ***: enabled";
	else
		echo "1" > /proc/sys/net/ipv6/conf/wlan0/disable_ipv6;
		sysctl -w net.ipv6.conf.all.disable_ipv6=1;
		log -p i -t $FILE_NAME "*** TUNE_IPV6 ***: disabled";
	fi;
}

KERNEL_SCHED_AWAKE()
{
	case "${cfs_tweaks}" in
  0)
    sysctl -w kernel.sched_min_granularity_ns=750000 > /dev/null;
    sysctl -w kernel.sched_latency_ns=10000000 > /dev/null;
    sysctl -w kernel.sched_wakeup_granularity_ns=2000000 > /dev/null;
    ;;
  1)
    sysctl -w kernel.sched_min_granularity_ns=750000 > /dev/null;
    sysctl -w kernel.sched_latency_ns=6000000 > /dev/null;
    sysctl -w kernel.sched_wakeup_granularity_ns=1000000 > /dev/null;
    ;;
  2)
    sysctl -w kernel.sched_min_granularity_ns=200000 > /dev/null;
    sysctl -w kernel.sched_latency_ns=400000 > /dev/null;
    sysctl -w kernel.sched_wakeup_granularity_ns=100000 > /dev/null;
    ;;
esac;

	log -p i -t $FILE_NAME "*** KERNEL_SCHED ***: awake";
}

KERNEL_SCHED_SLEEP()
{
	echo "20000000" > /proc/sys/kernel/sched_latency_ns;
	echo "4000000" > /proc/sys/kernel/sched_wakeup_granularity_ns;
	echo "2000000" > /proc/sys/kernel/sched_min_granularity_ns;
	log -p i -t $FILE_NAME "*** KERNEL_SCHED ***: sleep";
}

# if crond used, then give it root perent - if started by STweaks, then it will be killed in time
CROND_SAFETY()
{
	if [ "$crontab" == on ]; then
		pkill -f "crond";
		/res/crontab_service/service.sh;
		log -p i -t $FILE_NAME "*** CROND_SAFETY ***";
	fi;
}

DISABLE_NMI()
{
	if [ -e /proc/sys/kernel/nmi_watchdog ]; then
		echo "0" > /proc/sys/kernel/nmi_watchdog;
		log -p i -t $FILE_NAME "*** NMI ***: disable";
	fi;
}

ENABLE_NMI()
{
	if [ -e /proc/sys/kernel/nmi_watchdog ]; then
		echo "1" > /proc/sys/kernel/nmi_watchdog;
		log -p i -t $FILE_NAME "*** NMI ***: enabled";
	fi;
}


# ==============================================================
# TWEAKS: if Screen-ON
# ==============================================================
AWAKE_MODE()
{
	ENABLE_LOGGER;

	KERNEL_SCHED_AWAKE;
	
	WAKEUP_DELAY;
	
	MEGA_BOOST_CPU_TWEAKS;
	
	MOUNT_SD_CARD;
	
	ENABLE_GESTURES;
	
	WAKEUP_BOOST_DELAY;

	# set default values
	echo "$dirty_expire_centisecs_default" > /proc/sys/vm/dirty_expire_centisecs;
	echo "$dirty_writeback_centisecs_default" > /proc/sys/vm/dirty_writeback_centisecs;

	# set I/O-Scheduler
	echo "$scheduler" > /sys/block/mmcblk0/queue/scheduler;
	echo "$scheduler" > /sys/block/mmcblk1/queue/scheduler;
if [ "$mali_resume_enable" == on ]; then
	echo "$GPUFREQ1" > /sys/module/mali/parameters/step0_clk;
fi;
	echo "20" > /proc/sys/vm/vfs_cache_pressure;
	
	DISABLE_WIFI_PM;

	TUNE_IPV6;

	#CPU_GOV_TWEAKS;
	
	if [ "$cortexbrain_cpu_boost" == on ]; then
	# set CPU speed
	echo "$scaling_min_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq;
	echo "$scaling_max_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq;
	fi;

	# set wifi.supplicant_scan_interval
	setprop wifi.supplicant_scan_interval $supplicant_scan_interval;
	
	echo "$mali_gpu_utilization_timeout" > /sys/module/mali/parameters/mali_gpu_utilization_timeout;
	# set the vibrator - force in case it's has been reseted
	echo "$pwm_val" > /sys/vibrator/pwm_val;

	ENABLE_NMI;

	AUTO_BRIGHTNESS;

	DONT_KILL_CORTEX;
	
	ENABLE_KSM;
	
	SWAPPINESS;

	log -p i -t $FILE_NAME "*** AWAKE Normal Mode ***";
}

# ==============================================================
# TWEAKS: if Screen-OFF
# ==============================================================
SLEEP_MODE()
{
	# we only read the config when screen goes off ...
	PROFILE=`cat /data/.siyah/.active.profile`;
	. /data/.siyah/$PROFILE.profile;
	
	WAKEUP_DELAY_SLEEP;

	if [ "$cortexbrain_cpu_boost" == on ]; then
		# set CPU-Governor
	echo "$deep_sleep" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor;
	echo "$standby_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq;
	fi;
	# bus freq to min 133Mhz
	echo "80" > /sys/devices/system/cpu/cpufreq/busfreq_up_threshold;
	echo "500" > /sys/module/mali/parameters/mali_gpu_utilization_timeout;

	KERNEL_SCHED_SLEEP;

	DISABLE_GESTURES;

	TUNE_IPV6;

	BATTERY_TWEAKS;

	CROND_SAFETY;

	SWAPPINESS;
	
	ENABLE_WIFI_PM;
	
	DISABLE_KSM;

	if [ "$cortexbrain_cpu_boost" == on ]; then

# reduce deepsleep CPU speed, SUSPEND mode
echo "$scaling_min_suspend_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq;
echo "$scaling_max_suspend_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq;

# set CPU-Tweak
#CPU_GOV_TWEAKS;
fi;


		# set wifi.supplicant_scan_interval
		if [ "$supplicant_scan_interval" \< 180 ]; then
			setprop wifi.supplicant_scan_interval 360;
		fi;

		# set settings for battery -> don't wake up "pdflush daemon"
		echo "$dirty_expire_centisecs_battery" > /proc/sys/vm/dirty_expire_centisecs;
		echo "$dirty_writeback_centisecs_battery" > /proc/sys/vm/dirty_writeback_centisecs;
		
			# set disk I/O sched to noop simple and battery saving.
		echo "$sleep_scheduler" > /sys/block/mmcblk0/queue/scheduler;
		echo "$sleep_scheduler" > /sys/block/mmcblk1/queue/scheduler;

		# set battery value
		echo "10" > /proc/sys/vm/vfs_cache_pressure; # default: 100

		DISABLE_NMI;

		log -p i -t $FILE_NAME "*** SLEEP mode ***";

		DISABLE_LOGGER;
}

# ==============================================================
# Background process to check screen state
# ==============================================================

# Dynamic value do not change/delete
cortexbrain_background_process=1;

if [ "$cortexbrain_background_process" == 1 ] && [ `pgrep -f "cat /sys/power/wait_for_fb_sleep" | wc -l` == 0 ] && [ `pgrep -f "cat /sys/power/wait_for_fb_wake" | wc -l` == 0 ]; then
	(while [ 1 ]; do
		# AWAKE State. all system ON.
		cat /sys/power/wait_for_fb_wake > /dev/null 2>&1;
		AWAKE_MODE;
		sleep 3;

		# SLEEP state. All system to power save.
		cat /sys/power/wait_for_fb_sleep > /dev/null 2>&1;
		SLEEP_MODE;
	done &);
else
	if [ "$cortexbrain_background_process" == 0 ]; then
		echo "Cortex background disabled!"
	else
		echo "Cortex background process already running!";
	fi;
fi;

# ==============================================================
# Logic Explanations
#
# This script will manipulate all the system / cpu / battery behavior
# Based on chosen STWEAKS profile+tweaks and based on SCREEN ON/OFF state.
#
# When User select battery/default profile all tuning will be toward battery save.
# But user loose performance -20% and get more stable system and more battery left.
#
# When user select performance profile, tuning will be to max performance on screen ON.
# When screen OFF all tuning switched to max power saving. as with battery profile,
# So user gets max performance and max battery save but only on screen OFF.
#
# This script change governors and tuning for them on the fly.
# Also switch on/off hotplug CPU core based on screen on/off.
# This script reset battery stats when battery is 100% charged.
# This script tune Network and System VM settings and ROM settings tuning.
# This script changing default MOUNT options and I/O tweaks for all flash disks and ZRAM.
#
# TODO: add more description, explanations & default vaules ...
#
