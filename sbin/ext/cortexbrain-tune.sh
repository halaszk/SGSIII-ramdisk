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
IWCONFIG=/sbin/iwconfig;
INTERFACE=wlan0;
AWAKE_LAPTOP_MODE="0";
SLEEP_LAPTOP_MODE="5";
BB=/sbin/busybox;
PROP=/system/bin/setprop;
sqlite=/sbin/sqlite3;
wifi_idle_wait=10000;

# =========
# Renice - kernel thread responsible for managing the swap memory and logs
# =========
#renice 15 -p `pgrep -f "kswapd0"`;
#renice 15 -p `pgrep -f "logcat"`;

# replace kernel version info for repacked kernels
cat /proc/version | grep infra && (kmemhelper -t string -n linux_proc_banner -o 15 `cat /res/version`);

# ==============================================================
# I/O-TWEAKS 
# ==============================================================
IO_TWEAKS()
{
	if [ "$cortexbrain_io" == on ]; then

		ZRM=`ls -d /sys/block/zram*`;
		for z in $ZRM; do
	
			if [ -e $z/queue/rotational ]; then
				echo "0" > $z/queue/rotational;
			fi;

			if [ -e $z/queue/iostats ]; then
				echo "0" > $z/queue/iostats;
			fi;

			if [ -e $z/queue/rq_affinity ]; then
				echo "1" > $z/queue/rq_affinity;
			fi;

		done;

		MMC=`ls -d /sys/block/mmc*`;
		for i in $MMC; do

			if [ -e $i/queue/scheduler ]; then
				echo "$scheduler" > $i/queue/scheduler;
			fi;

			if [ -e $i/queue/rotational ]; then
				echo "0" > $i/queue/rotational;
			fi;

			if [ -e $i/queue/iostats ]; then
				echo "0" > $i/queue/iostats;
			fi;

			if [ -e $i/queue/read_ahead_kb ]; then
				echo "$cortexbrain_read_ahead_kb" >  $i/queue/read_ahead_kb; # default: 128
			fi;

			if [ -e $i/queue/nr_requests ]; then
				if [ "$scheduler" == "sio" ] || [ "$scheduler" == "zen" ]; then
					echo "20" > $i/queue/nr_requests; # default: 128
				fi;
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
			echo "$cortexbrain_read_ahead_kb" > /sys/devices/virtual/bdi/default/read_ahead_kb;
		fi;

		SDCARDREADAHEAD=`ls -d /sys/devices/virtual/bdi/179*`;
		for i in $SDCARDREADAHEAD; do
			echo "$cortexbrain_read_ahead_kb" > $i/read_ahead_kb;
		done;

		for i in /sys/block/*/queue/add_random; do 
		echo "0" > $i;
		done;
		echo "0" > /proc/sys/kernel/randomize_va_space;


		echo NO_NORMALIZED_SLEEPER > /sys/kernel/debug/sched_features;
		echo NO_NEW_FAIR_SLEEPERS > /sys/kernel/debug/sched_features;
		echo NO_START_DEBIT > /sys/kernel/debug/sched_features;
		echo NO_WAKEUP_PREEMPT > /sys/kernel/debug/sched_features;
		echo NEXT_BUDDY > /sys/kernel/debug/sched_features;
		echo SYNC_WAKEUPS > /sys/kernel/debug/sched_features;

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
  		$BB sysctl -w kernel.panic=10;
	
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
	$PROP hwui.render_dirty_regions false;
	$PROP windowsmgr.max_events_per_sec 100;
	# enable Hardware Rendering
	$PROP video.accelerate.hw 1;
	$PROP debug.performance.tuning 1;
	$PROP debug.sf.hw 1;
	$PROP persist.sys.use_dithering 1;
#	$PROP persist.sys.ui.hw true; # ->reported as problem maker in some roms.

	# render UI with GPU
	$PROP hwui.render_dirty_regions false;
	$PROP windowsmgr.max_events_per_sec 120;
	$PROP profiler.force_disable_err_rpt 1;
	$PROP profiler.force_disable_ulog 1;

	# Dialing Tweaks
	$PROP ro.telephony.call_ring.delay=0;
	$PROP ro.lge.proximity.delay=25;
	$PROP mot.proximity.delay=25;

	# more Tweaks
	$PROP dalvik.vm.execution-mode int:jit;
	$PROP persist.adb.notify 0;
	$PROP pm.sleep_mode 1;

	# =========
	# Optimized Audio and Video Settings
	# =========
	$PROP ro.media.enc.jpeg.quality 100;
	$PROP ro.media.dec.jpeg.memcap 8000000;
	$PROP ro.media.enc.hprof.vid.bps 8000000;
	$PROP ro.media.capture.maxres 8m;
	#$PROP ro.media.capture.fast.fps 4
	#$PROP ro.media.capture.slow.fps 120
	#$PROP ro.media.capture.flashMinV 3300000
	#$PROP ro.media.capture.torchIntensity 40
	#$PROP ro.media.capture.flashIntensity 70
	$PROP ro.media.panorama.defres 3264x1840;
	$PROP ro.media.panorama.frameres 1280x720;
	$PROP ro.camcorder.videoModes true;
	$PROP ro.media.enc.hprof.vid.fps 65;
	#$PROP ro.service.swiqi.supported true
	#$PROP persist.service.swiqi.enable 1
	$PROP media.stagefright.enable-player true;
	$PROP media.stagefright.enable-meta true;
	$PROP media.stagefright.enable-scan true;
	$PROP media.stagefright.enable-http true;
	$PROP media.stagefright.enable-rtsp=true;
	$PROP media.stagefright.enable-record false;



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
	  $BB mount -t debugfs none /sys/kernel/debug;
	  $BB umount /sys/kernel/debug;
	  # vm tweaks
	  $BB sysctl -w vm.dirty_background_ratio=70;
	  $BB sysctl -w vm.dirty_ratio=90;
	  $BB sysctl -w vm.vfs_cache_pressure=10;

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
	local state="$1";
	if [ "$cortexbrain_cpu" == on ]; then
	SYSTEM_GOVERNOR=`cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor`;
        
		# power_performance
	if [ "${state}" == "performance" ]; then

	echo "20000" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/sampling_rate;
	echo "10" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_up_rate;
	echo "10" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_down_rate;
	echo "40" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold;
	echo "20" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold_at_min_freq;
	echo "100" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_step;
	echo "800000" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_for_responsiveness;

		# sleep-settings
	elif [ "${state}" == "sleep" ]; then

	echo "$freq_for_responsiveness_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_for_responsiveness;
    echo "$freq_for_fast_down_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_for_fast_down;
    echo "$sampling_rate_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/sampling_rate;
	echo "$sampling_down_factor_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/sampling_down_factor;
	echo "$up_threshold_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold;
	echo "$down_differential_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/down_differential;
	echo "$up_threshold_at_min_freq_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold_at_min_freq;
	echo "$up_threshold_at_fast_down_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold_at_fast_down;
	echo "$freq_step_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_step;
	echo "$up_threshold_diff_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold_diff;
	echo "$freq_step_dec_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_step_dec;
	echo "$cpu_up_rate_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_up_rate;
	echo "$cpu_down_rate_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_down_rate;
	echo "$up_nr_cpus_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_nr_cpus;
	echo "$hotplug_freq_1_1_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_freq_1_1;
	echo "$hotplug_freq_2_0_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_freq_2_0;
	echo "$hotplug_freq_2_1_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_freq_2_1;
	echo "$hotplug_freq_3_0_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_freq_3_0;
	echo "$hotplug_freq_3_1_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_freq_3_1;
	echo "$hotplug_freq_4_0_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_freq_4_0;
	echo "$hotplug_rq_1_1_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_rq_1_1;
	echo "$hotplug_rq_2_0_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_rq_2_0;
	echo "$hotplug_rq_2_1_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_rq_2_1;
	echo "$hotplug_rq_3_0_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_rq_3_0;
	echo "$hotplug_rq_3_1_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_rq_3_1;
	echo "$hotplug_rq_4_0_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_rq_4_0;
	echo "$flexrate_enable_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/flexrate_enable;
	echo "$flexrate_max_freq_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/flexrate_max_freq;
	echo "$flexrate_forcerate_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/flexrate_forcerate;
	echo "$cpu_online_bias_count_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_online_bias_count;
	echo "$cpu_online_bias_up_threshold_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_online_bias_up_threshold;
	echo "$cpu_online_bias_down_threshold_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_online_bias_down_threshold;
	#echo "1" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/max_cpu_lock; # force cpu to single core mode when screen is off!
	#echo "0" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/lcdfreq_enable;
	echo "$hotplug_compare_level_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_compare_level;
	
		# awake-settings
	elif [ "${state}" == "awake" ]; then
	echo "$freq_for_responsiveness" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_for_responsiveness;
    echo "$freq_for_fast_down" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_for_fast_down;
    echo "$sampling_rate" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/sampling_rate;
	echo "$sampling_down_factor" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/sampling_down_factor;
	echo "$up_threshold" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold;
	echo "$down_differential" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/down_differential;
	echo "$up_threshold_at_min_freq" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold_at_min_freq;
	echo "$up_threshold_at_fast_down" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold_at_fast_down;
	echo "$freq_step" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_step;
	echo "$up_threshold_diff" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold_diff;
	echo "$freq_step_dec" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_step_dec;
	echo "$cpu_up_rate" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_up_rate;
	echo "$cpu_down_rate" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_down_rate;
	echo "$up_nr_cpus" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_nr_cpus;
	echo "$hotplug_freq_1_1" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_freq_1_1;
	echo "$hotplug_freq_2_0" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_freq_2_0;
	echo "$hotplug_freq_2_1" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_freq_2_1;
	echo "$hotplug_freq_3_0" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_freq_3_0;
	echo "$hotplug_freq_3_1" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_freq_3_1;
	echo "$hotplug_freq_4_0" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_freq_4_0;
	echo "$hotplug_rq_1_1" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_rq_1_1;
	echo "$hotplug_rq_2_0" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_rq_2_0;
	echo "$hotplug_rq_2_1" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_rq_2_1;
	echo "$hotplug_rq_3_0" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_rq_3_0;
	echo "$hotplug_rq_3_1" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_rq_3_1;
	echo "$hotplug_rq_4_0" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_rq_4_0;
	echo "$flexrate_max_freq" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/flexrate_max_freq;
	echo "$flexrate_forcerate" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/flexrate_forcerate;
	echo "$boost" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/boost;
	echo "$cpu_online_bias_count" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_online_bias_count;
	echo "$cpu_online_bias_up_threshold" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_online_bias_up_threshold;
	echo "$cpu_online_bias_down_threshold" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_online_bias_down_threshold;
	echo "$max_cpu_lock" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/max_cpu_lock;
	echo "$lcdfreq" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/lcdfreq_enable;
	echo "$hotplug_compare_level" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_compare_level;
	
	fi;

		log -p i -t $FILE_NAME "*** CPU_GOV_TWEAKS: ${state} ***: enabled";
	fi;
}
if [ "$cortexbrain_background_process" == 0 ]; then
	CPU_GOV_TWEAKS "awake";
fi;
# this needed for cpu tweaks apply from STweaks in real time.
apply_cpu=$2;
if [ "${apply_cpu}" == "update" ]; then
CPU_GOV_TWEAKS "awake";
fi;

# ==============================================================
# MEMORY-TWEAKS
# ==============================================================
MEMORY_TWEAKS()
{
	if [ "$cortexbrain_memory" == on ]; then
	#	echo "4" > /proc/sys/vm/min_free_order_shift; # default: 4
	#	echo "0" > /proc/sys/vm/overcommit_memory; # default: 0
	#	echo "50" > /proc/sys/vm/overcommit_ratio; # default: 50
	#	echo "128 128" > /proc/sys/vm/lowmem_reserve_ratio;
	#	echo "3" > /proc/sys/vm/page-cluster; # default: 3
		echo "2896" > /proc/sys/vm/min_free_kbytes;
		# =========
# VM Settings
# =========
mem=`free|grep Mem | awk '{print $2}'`;
if [ "$mem" -lt 524288 ];then
	$BB sysctl -w vm.dirty_background_ratio=20;
	$BB sysctl -w vm.dirty_ratio=40;
elif [ "$mem" -lt 1049776 ];then
	$BB sysctl -w vm.dirty_background_ratio=10;
	$BB sysctl -w vm.dirty_ratio=20;
else 
	$BB sysctl -w vm.dirty_background_ratio=5;
	$BB sysctl -w vm.dirty_ratio=10;
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

	# Website Bypass
	$PROP net.rmnet0.dns1=8.8.8.8;
	$PROP net.rmnet0.dns2=8.8.4.4;
	$PROP net.dns1=8.8.8.8;
	$PROP net.dns2=8.8.4.4;

		# =========
	# 3G-2G and wifi network battery tweaks
	$PROP ro.ril.enable.a52 0;
	$PROP ro.ril.enable.a53 1;
	$PROP ro.ril.fast.dormancy.timeout 3;
	$PROP ro.ril.enable.sbm.feature 1;
	$PROP ro.ril.enable.sdr 0;
	$PROP ro.ril.qos.maxpdps 2;
	$PROP ro.ril.hsxpa 2;
	$PROP ro.ril.hsdpa.category 14;
	$PROP ro.ril.hsupa.category 7;
	$PROP ro.ril.hep 1;
	$PROP ro.ril.enable.dtm 0;
	$PROP ro.ril.enable.amr.wideband 1;
	$PROP ro.ril.gprsclass 12;
	$PROP ro.ril.avoid.pdp.overlap 1;
	$PROP ro.ril.enable.prl.recognition 0;
	$PROP ro.ril.def.agps.mode 2;
	$PROP ro.ril.enable.managed.roaming 1;
	$PROP ro.ril.enable.enhance.search 0;
#	$PROP ro.ril.fast.dormancy.rule 1;
	$PROP ro.ril.fd.scron.timeout 30;
	$PROP ro.ril.fd.scroff.timeout 10;
	$PROP ro.ril.emc.mode 2;
	$PROP ro.ril.att.feature 0;
	
	# Wireless Speed Tweaks
	$PROP net.tcp.buffersize.default=4096,87380,256960,4096,16384,256960;
	$PROP net.tcp.buffersize.wifi=4096,87380,256960,4096,16384,256960;
	$PROP net.tcp.buffersize.umts=4096,87380,256960,4096,16384,256960;
	$PROP net.tcp.buffersize.gprs=4096,87380,256960,4096,16384,256960;
	$PROP net.tcp.buffersize.edge=4096,87380,256960,4096,16384,256960;
	$PROP net.ipv4.tcp_ecn=0;
	$PROP net.ipv4.route.flush=1;
	$PROP net.ipv4.tcp_rfc1337=1;
	$PROP net.ipv4.ip_no_pmtu_disc=0;
	$PROP net.ipv4.tcp_sack=1;
	$PROP net.ipv4.tcp_fack=1;
	$PROP net.ipv4.tcp_window_scaling=1;
	$PROP net.ipv4.tcp_timestamps=1;
	$PROP net.ipv4.tcp_rmem=4096 39000 187000;
	$PROP net.ipv4.tcp_wmem=4096 39000 187000;
	$PROP net.ipv4.tcp_mem=187000 187000 187000;
	$PROP net.ipv4.tcp_no_metrics_save=1;
	$PROP net.ipv4.tcp_moderate_rcvbuf=1;

	echo "0" > /proc/sys/net/ipv4/tcp_timestamps;
	echo "1" > /proc/sys/net/ipv4/tcp_tw_reuse;
	echo "1" > /proc/sys/net/ipv4/tcp_sack;
	echo "1" > /proc/sys/net/ipv4/tcp_dsack;
	echo "1" > /proc/sys/net/ipv4/tcp_tw_recycle;
	echo "1" > /proc/sys/net/ipv4/tcp_window_scaling;
	echo "5" > /proc/sys/net/ipv4/tcp_keepalive_probes;
	echo "30" > /proc/sys/net/ipv4/tcp_keepalive_intvl;
	echo "30" > /proc/sys/net/ipv4/tcp_fin_timeout;
	echo "1" > /proc/sys/net/ipv4/tcp_moderate_rcvbuf;
	echo "1" > /proc/sys/net/ipv4/route/flush;
	echo "6144" > /proc/sys/net/ipv4/udp_rmem_min;
	echo "6144" > /proc/sys/net/ipv4/udp_wmem_min;
	echo "1" > /proc/sys/net/ipv4/tcp_rfc1337;
	echo "0" > /proc/sys/net/ipv4/ip_no_pmtu_disc;
	echo "0" > /proc/sys/net/ipv4/tcp_ecn;
	echo "6144 87380 2097152" > /proc/sys/net/ipv4/tcp_wmem;
	echo "6144 87380 2097152" > /proc/sys/net/ipv4/tcp_rmem;
	echo "1" > /proc/sys/net/ipv4/tcp_fack;
	echo "2" > /proc/sys/net/ipv4/tcp_synack_retries;
	echo "2" > /proc/sys/net/ipv4/tcp_syn_retries;
	echo "1" > /proc/sys/net/ipv4/tcp_no_metrics_save;
	echo "1800" > /proc/sys/net/ipv4/tcp_keepalive_time;
	echo "0" > /proc/sys/net/ipv4/ip_forward;
	echo "0" > /proc/sys/net/ipv4/conf/default/accept_source_route;
	echo "0" > /proc/sys/net/ipv4/conf/all/accept_source_route;
	echo "0" > /proc/sys/net/ipv4/conf/all/accept_redirects;
	echo "0" > /proc/sys/net/ipv4/conf/default/accept_redirects;
	echo "0" > /proc/sys/net/ipv4/conf/all/secure_redirects;
	echo "0" > /proc/sys/net/ipv4/conf/default/secure_redirects;
	echo "0" > /proc/sys/net/ipv4/ip_dynaddr;
	echo "1440000" > /proc/sys/net/ipv4/tcp_max_tw_buckets;
	echo "57344 57344 524288" > /proc/sys/net/ipv4/tcp_mem;
	echo "1440000" > /proc/sys/net/ipv4/tcp_max_tw_buckets;
	echo "2097152" > /proc/sys/net/core/rmem_max;
	echo "2097152" > /proc/sys/net/core/wmem_max;
	echo "262144" > /proc/sys/net/core/rmem_default;
	echo "262144" > /proc/sys/net/core/wmem_default;
	echo "20480" > /proc/sys/net/core/optmem_max;
	echo "2500" > /proc/sys/net/core/netdev_max_backlog;
	echo "50" > /proc/sys/net/unix/max_dgram_qlen;

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

WIFI_PM()
{
	local state="$1";
	if [ "${state}" == "sleep" ]; then
		if [ "$wifi_pwr" == on ]; then
			if [ -e /sys/module/dhd/parameters/wifi_pm ]; then
				echo "1" > /sys/module/dhd/parameters/wifi_pm;
			fi;
		fi;

		if [ "$supplicant_scan_interval" -le 180 ]; then
			$PROP wifi.supplicant_scan_interval 360;
		fi;
	elif [ "${state}" == "awake" ]; then
		if [ -e /sys/module/dhd/parameters/wifi_pm ]; then
			echo "0" > /sys/module/dhd/parameters/wifi_pm;
		fi;

		$PROP wifi.supplicant_scan_interval $supplicant_scan_interval;
	fi;

	log -p i -t $FILE_NAME "*** WIFI_PM ***: ${state}";
}

LOGGER()
{
	local state="$1";
	if [ "${state}" == "awake" ]; then
		if [ "$android_logger" == auto ] || [ "$android_logger" == debug ]; then
			if [ -e /dev/log-sleep ] && [ ! -e /dev/log ]; then
				mv /dev/log-sleep/ /dev/log/
			fi;
		fi;
	elif [ "${state}" == "sleep" ]; then
		if [ "$android_logger" == auto ] || [ "$android_logger" == disabled ]; then
			if [ -e /dev/log ]; then
				mv /dev/log/ /dev/log-sleep/;
			fi;
		fi;
	fi;

	log -p i -t $FILE_NAME "*** LOGGER ***: ${state}";
}

GESTURES()
{
	local state="$1";
	if [ "${state}" == "awake" ]; then
		if [ "$gesture_tweak" == on ]; then
			echo "1" > /sys/devices/virtual/misc/touch_gestures/gestures_enabled;
			pkill -f "/data/gesture_set.sh";
			pkill -f "/sys/devices/virtual/misc/touch_gestures/wait_for_gesture";
			nohup /sbin/busybox sh /data/gesture_set.sh;
		fi;
	elif [ "${state}" == "sleep" ]; then
		if [ `pgrep -f "/data/gesture_set.sh" | wc -l` != 0 ] || [ `pgrep -f "/sys/devices/virtual/misc/touch_gestures/wait_for_gesture" | wc -l` != 0 ] || [ "$gesture_tweak" == off ]; then
			pkill -f "/data/gesture_set.sh";
			pkill -f "/sys/devices/virtual/misc/touch_gestures/wait_for_gesture";
		fi;
		echo "0" > /sys/devices/virtual/misc/touch_gestures/gestures_enabled;
	fi;

	log -p i -t $FILE_NAME "*** GESTURE ***: ${state}";
}


# ==============================================================
# KSM-TWEAKS
# ==============================================================
if [ "$cortexbrain_ksm_control" == on ]; then
	KSM_MONITOR_INTERVAL=60;
	KSM_NPAGES_BOOST=300;
	KSM_NPAGES_DECAY=50;

	KSM_NPAGES_MIN=32;
	KSM_NPAGES_MAX=1000;
	KSM_SLEEP_MSEC=200;
	KSM_SLEEP_MIN=2000;

	KSM_THRES_COEF=30;
	KSM_THRES_CONST=2048;

	npages=0;
	total=`awk '/^MemTotal:/ {print $2}' /proc/meminfo`;
	thres=$(( $total * $KSM_THRES_COEF / 100 ));
	if [ $KSM_THRES_CONST -gt $thres ]; then
		thres=$KSM_THRES_CONST;
	fi;
	total=$(( $total / 1024 ));
	sleep=$(( $KSM_SLEEP_MSEC * 16 * 1024 / $total ));
	if [ $sleep -le $KSM_SLEEP_MIN ]; then
		sleep=$KSM_SLEEP_MIN;
	fi;

	KSMCTL() {
		case x${1} in
			xstop)
				log -p i -t $FILE_NAME "*** ksm: stop ***";
				echo 0 > /sys/kernel/mm/ksm/run;
			;;
			xstart)
				log -p i -t $FILE_NAME "*** ksm: start ${2} ${3} ***";
				echo ${2} > /sys/kernel/mm/ksm/pages_to_scan;
				echo ${3} > /sys/kernel/mm/ksm/sleep_millisecs;
				echo 1 > /sys/kernel/mm/ksm/run;
				renice 10 -p "`pidof ksmd`";
			;;
		esac
	}

	FREE_MEM() {
		awk '/^(MemFree|Buffers|Cached):/ {free += $2}; END {print free}' /proc/meminfo;
	}

	INCREASE_NPAGES() {
		local delta=${1:-0};
		npages=$(( $npages + $delta ));
		if [ $npages -lt $KSM_NPAGES_MIN ]; then
			npages=$KSM_NPAGES_MIN;
		elif [ $npages -gt $KSM_NPAGES_MAX ]; then
			npages=$KSM_NPAGES_MAX;
		fi;
		echo $npages;
	}

	ADJUST_KSM() {
		local free=`FREE_MEM`;
		if [ $free -gt $thres ]; then
			log -p i -t $FILE_NAME "*** ksm: $free > $thres ***";
			npages=`INCREASE_NPAGES ${KSM_NPAGES_BOOST}`;
			KSMCTL "stop";
			return 1;
		else
			npages=`INCREASE_NPAGES $KSM_NPAGES_DECAY`;
			log -p i -t $FILE_NAME "*** ksm: $free < $thres ***";
			KSMCTL "start" $npages $sleep;
			return 0;
		fi;
	}

	(while [ 1 ]; do
		cat /sys/power/wait_for_fb_wake;
		sleep $KSM_MONITOR_INTERVAL &
		wait $!;
		ADJUST_KSM;
	done &);
fi;

WIFI_TIMEOUT_TWEAKS()
{
RETURN_VALUE=$($sqlite /data/data/com.android.providers.settings/databases/settings.db "select value from secure where name='wifi_idle_ms'");
echo "Current wifi_idle_ms value: $RETURN_VALUE";
if [ $RETURN_VALUE='' ] 
then
   echo "Creating row with wifi_idle_ms value: $wifi_idle_wait";
   $sqlite /data/data/com.android.providers.settings/databases/settings.db "insert into secure (name, value) values ('wifi_idle_ms', $wifi_idle_wait )"
    log -p i -t $FILE_NAME "*** Creating row with wifi_idle_ms value: $wifi_idle_wait ***";
else
   echo "Updating wifi_idle_ms value from $RETURN_VALUE to $wifi_idle_wait";
   $sqlite /data/data/com.android.providers.settings/databases/settings.db "update secure set value=$wifi_idle_wait where name='wifi_idle_ms'"
   log -p i -t $FILE_NAME "*** Updating wifi_idle_ms value from $RETURN_VALUE to $wifi_idle_wait ***";
fi;
}
if [ "$cortexbrain_wifi" == on ]; then
WIFI_TIMEOUT_TWEAKS;
fi;
# please don't kill "cortexbrain"
DONT_KILL_CORTEX()
{
	PIDOFCORTEX=`pgrep -f "/sbin/ext/cortexbrain-tune.sh"`;
	for i in $PIDOFCORTEX; do
		echo "-950" > /proc/${i}/oom_score_adj;
	done;

	log -p i -t $FILE_NAME "*** DONT_KILL_CORTEX ***";
}

MOUNT_SD_CARD()
{
if [ "$auto_mount_sd" == on ]; then
		$PROP persist.sys.usb.config mass_storage,adb;
	if [ -e /dev/block/vold/179:49 ]; then
		echo "/dev/block/vold/179:49" > /sys/devices/virtual/android_usb/android0/f_mass_storage/lun1/file;
	fi;
	log -p i -t $FILE_NAME "*** MOUNT_SD_CARD ***";
fi;
}
MOUNT_SD_CARD;
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

MALI_TIMEOUT()
{
	local state="$1";
	if [ "${state}" == "awake" ]; then
		echo "$mali_gpu_utilization_timeout" > /sys/module/mali/parameters/mali_gpu_utilization_timeout;
	elif [ "${state}" == "sleep" ]; then
		echo "300" > /sys/module/mali/parameters/mali_gpu_utilization_timeout;
	elif [ "${state}" == "performance" ]; then
		echo "100" > /sys/module/mali/parameters/mali_gpu_utilization_timeout;
	fi;

	log -p i -t $FILE_NAME "*** MALI_TIMEOUT: ${state} ***";
}

# boost CPU power for fast and no lag wakeup
MEGA_BOOST_CPU_TWEAKS()
{
if [ "$cortexbrain_cpu_boost" == on ]; then

echo "performance" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor;
CPU_GOV_TWEAKS "performance";

MALI_TIMEOUT "performance";

	# bus freq to 400MHZ in low load
echo "30" > /sys/devices/system/cpu/busfreq/dmc_max_threshold;
echo "30" > /sys/devices/system/cpu/busfreq/max_cpu_threshold;
echo "30" > /sys/devices/system/cpu/busfreq/up_cpu_threshold;

echo "1400000" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq;
echo "1400000" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq;
if [ "$mali_resume_enable" == on ]; then
echo "$gpu_res_freq" > /sys/module/mali/parameters/step0_clk;
fi;
log -p i -t $FILE_NAME "*** MEGA_BOOST_CPU_TWEAKS ***";
fi;
}


# set less brightnes if battery is low
# (works only without "auto_brightness" for now?!)
SYNC_BRIGHTNESS()
{
if [ "$cortexbrain_auto_sync_brightness" == on ]; then
LEVEL=`cat /sys/class/power_supply/battery/capacity`;
MAX_BRIGHTNESS=`cat /sys/class/backlight/panel/max_brightness`;
OLD_BRIGHTNESS=`cat /sys/class/backlight/panel/brightness`;
NEW_BRIGHTNESS=$(( MAX_BRIGHTNESS*LEVEL/100 ));
if [ "$NEW_BRIGHTNESS" -le "$OLD_BRIGHTNESS" ]; then
echo "$NEW_BRIGHTNESS" > /sys/class/backlight/panel/brightness;
fi;
log -p i -t $FILE_NAME "*** SYNC_BRIGHTNESS ***";
fi;
}

# set less brightnes
# (works only without "auto_brightness" for now?!)
LESS_BRIGHTNESS()
{
if [ "$cortexbrain_auto_less_brightness" == on ]; then
MAX_BRIGHTNESS=`cat /sys/class/backlight/panel/max_brightness`;
OLD_BRIGHTNESS=`cat /sys/class/backlight/panel/brightness`;
NEW_BRIGHTNESS=$(( MAX_BRIGHTNESS-cortexbrain_less_brightness ));
if [ "$NEW_BRIGHTNESS" -ge "0" ]; then
echo "$NEW_BRIGHTNESS" > /sys/class/backlight/panel/brightness;
fi;
log -p i -t $FILE_NAME "*** LESS_BRIGHTNESS ***";
fi;
}
# set swappiness in case that no root installed, and zram used or disk swap used
SWAPPINESS()
{
	SWAP_CHECK=`free | grep Swap | awk '{ print $2 }'`;
	if [ "$zram" == 4 ] || [ "$SWAP_CHECK" == 0 ]; then
		echo "0" > /proc/sys/vm/swappiness;
	else
		echo "$swappiness" > /proc/sys/vm/swappiness;
	fi;
log -p i -t $FILE_NAME "*** SWAPPINESS: $swappiness ***";
}

TUNE_IPV6()
{
	CISCO_VPN=`find /data/data/com.cisco.anyconnec* | wc -l`;
	if [ "$cortexbrain_ipv6" == on ] || [ "$CISCO_VPN" != 0 ]; then
		echo "0" > /proc/sys/net/ipv6/conf/wlan0/disable_ipv6;
		$BB sysctl -w net.ipv6.conf.all.disable_ipv6=0;
		log -p i -t $FILE_NAME "*** TUNE_IPV6 ***: enabled";
	else
		echo "1" > /proc/sys/net/ipv6/conf/wlan0/disable_ipv6;
		$BB sysctl -w net.ipv6.conf.all.disable_ipv6=1;
		log -p i -t $FILE_NAME "*** TUNE_IPV6 ***: disabled";
	fi;
}

KERNEL_SCHED()
{
	local state="$1";

	if [ "${state}" == "awake" ]; then
		echo "0" > /proc/sys/kernel/sched_child_runs_first;
		echo "1000000" > /proc/sys/kernel/sched_latency_ns;
		echo "100000" > /proc/sys/kernel/sched_min_granularity_ns;
		echo "2000000" > /proc/sys/kernel/sched_wakeup_granularity_ns;
	elif [ "${state}" == "sleep" ]; then
		echo "1" > /proc/sys/kernel/sched_child_runs_first;
		echo "10000000" > /proc/sys/kernel/sched_latency_ns;
		echo "1500000" > /proc/sys/kernel/sched_min_granularity_ns;
		echo "2000000" > /proc/sys/kernel/sched_wakeup_granularity_ns;
	fi;
	echo "-1" > /proc/sys/kernel/sched_rt_runtime_us;

	log -p i -t $FILE_NAME "*** KERNEL_SCHED ***: ${state}";
}
SEEDER()
{
if [ "$cortexbrain_seeder_entropy" == on ]; then
	local state="$1";
	if [ "${state}" == "awake" ]; then
		$BB sh /sbin/ext/seed.sh > /dev/null 2>&1;
	elif [ "${state}" == "sleep" ]; then
		killall -9 rngd;
	fi;
	log -p i -t $FILE_NAME "*** SEEDER ***: ${state}";
fi;
}

LOWMMKILLER()
{
        local state="$1";
        if [ "${state}" == "awake" ]; then
                /res/uci.sh oom_config $oom_config;
        elif [ "${state}" == "sleep" ]; then
                /res/uci.sh oom_config_sleep $oom_config_sleep;
        fi;

        log -p i -t $FILE_NAME "*** LOWMMKILLER ***: ${state}";
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

GAMMA_FIX()
{
	echo "$min_gamma" > /sys/class/misc/brightness_curve/min_gamma;
	echo "$max_gamma" > /sys/class/misc/brightness_curve/max_gamma;

	log -p i -t $FILE_NAME "*** GAMMA_FIX: min: $min_gamma max: $max_gamma ***: done";
}
# ==============================================================
# TWEAKS: if Screen-ON
# ==============================================================
AWAKE_MODE()
{
	IO_TWEAKS;

	LOGGER "awake";

	GAMMA_FIX;

	KERNEL_SCHED "awake";

	WAKEUP_DELAY;
	
	MEGA_BOOST_CPU_TWEAKS;
	
	
	if [ "$cortexbrain_ksm_control" == on ]; then
		ADJUST_KSM;
	fi;

	
	GESTURES "awake";
	
	WAKEUP_BOOST_DELAY;
	
	echo "$AWAKE_LAPTOP_MODE" > /proc/sys/vm/laptop_mode;
	
	if [ "$cortexbrain_wifi" == on ]; then
	$IWCONFIG $INTERFACE frag 2345;
	$IWCONFIG $INTERFACE rts 2346;
	$IWCONFIG $INTERFACE txpower $cortexbrain_wifi_tx;
	fi;
	
	if [ "$cortexbrain_cpu_boost" == on ]; then
	echo "$scaling_governor" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor;
	fi;

	WIFI_PM "awake";
	
	TUNE_IPV6;

	CPU_GOV_TWEAKS "awake";

	# set I/O-Scheduler
	echo "$scheduler" > /sys/block/mmcblk0/queue/scheduler;
	echo "$scheduler" > /sys/block/mmcblk1/queue/scheduler;
	
	if [ "$mali_resume_enable" == on ]; then
	echo "$GPUFREQ1" > /sys/module/mali/parameters/step0_clk;
	fi;
	echo "50" > /proc/sys/vm/vfs_cache_pressure;

	if [ "$cortexbrain_cpu_boost" == on ]; then
	# set CPU speed
	echo "$scaling_min_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq;
	echo "$scaling_max_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq;
	fi;

	# set wifi.supplicant_scan_interval
	$PROP wifi.supplicant_scan_interval $supplicant_scan_interval;
	
	if [ "$cortexbrain_cpu_boost" == on ]; then
	# bus freq back to normal
	echo "$dmc_max_threshold" > /sys/devices/system/cpu/busfreq/dmc_max_threshold;
	echo "$max_cpu_threshold" > /sys/devices/system/cpu/busfreq/max_cpu_threshold;
	echo "$up_cpu_threshold" > /sys/devices/system/cpu/busfreq/up_cpu_threshold;
	MALI_TIMEOUT "awake";
	fi;
	
	# set the vibrator - force in case it's has been reseted
	echo "$pwm_val" > /sys/vibrator/pwm_val;

	ENABLE_NMI;

	SYNC_BRIGHTNESS;
	LESS_BRIGHTNESS;

	DONT_KILL_CORTEX;
	
	SWAPPINESS;
	
	SEEDER "awake";

	LOWMMKILLER "awake";

	log -p i -t $FILE_NAME "*** AWAKE Normal Mode ***";
}

# ==============================================================
# TWEAKS: if Screen-OFF
# ==============================================================
SLEEP_MODE()
{
	WAKEUP_DELAY_SLEEP;

	# we only read the config when screen goes off ...
	PROFILE=`cat /data/.siyah/.active.profile`;
	. /data/.siyah/$PROFILE.profile;

	if [ "$cortexbrain_cpu_boost" == on ]; then
		# set CPU-Governor
	echo "$deep_sleep" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor;
	echo "$standby_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq;
		# reduce deepsleep CPU speed, SUSPEND mode
	echo "$scaling_min_suspend_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq;
	echo "$scaling_max_suspend_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq;
	fi;


	# set CPU-Tweak
	CPU_GOV_TWEAKS "sleep";
	
	if [ "$cortexbrain_cpu_boost" == on ]; then
	# bus freq to min 100Mhz
	echo "80" > /sys/devices/system/cpu/busfreq/dmc_max_threshold;
	echo "80" > /sys/devices/system/cpu/busfreq/max_cpu_threshold;
	echo "80" > /sys/devices/system/cpu/busfreq/up_cpu_threshold;
	MALI_TIMEOUT "sleep";
	fi;
	if [ "$cortexbrain_wifi" == on ]; then
	$IWCONFIG $INTERFACE frag 2345;
	$IWCONFIG $INTERFACE rts 2346;
	$IWCONFIG $INTERFACE txpower $cortexbrain_wifi_tx;
	fi;
	
	echo "$SLEEP_LAPTOP_MODE" > /proc/sys/vm/laptop_mode;

	KERNEL_SCHED "sleep";

	GESTURES "sleep";

	TUNE_IPV6;

	BATTERY_TWEAKS;

	CROND_SAFETY;
	
	if [ "$cortexbrain_ksm_control" == on ]; then
		KSMCTL "stop";
	else
		echo 2 > /sys/kernel/mm/ksm/run;
	fi;

	SWAPPINESS;
	
	WIFI_PM "sleep";

		# set wifi.supplicant_scan_interval
		if [ "$supplicant_scan_interval" -le 180 ]; then
			$PROP wifi.supplicant_scan_interval 360;
		fi;
		
			# set disk I/O sched to noop simple and battery saving.
		echo "$sleep_scheduler" > /sys/block/mmcblk0/queue/scheduler;
		echo "$sleep_scheduler" > /sys/block/mmcblk1/queue/scheduler;

		# set battery value
		echo "50" > /proc/sys/vm/vfs_cache_pressure; # default: 100

		DISABLE_NMI;

		LOWMMKILLER "sleep";

		LOGGER "sleep";

        SEEDER "sleep";

		log -p i -t $FILE_NAME "*** SLEEP mode ***";

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

