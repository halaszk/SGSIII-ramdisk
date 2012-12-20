#!/sbin/busybox sh

mount -o remount,rw /
mount -o remount,rw /system
x=1;
while [ $x -le 5 ]
do
	for i in `find /proc -maxdepth 1 -type d`; do
		if [ -f  $i/oom_score ]; then
				echo "-17" > $i/oom_adj;
				echo "0" > $i/oom_score;
		fi;
	done | sort -n -k2;
	sleep 4;
done;