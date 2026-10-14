#!/system/bin/sh
# Samples the reproduction app's memory every $2 s (default 10) for $1
# samples (default 60), one line per sample:
#
#   T <epoch> pid=<pid> avail=<kB> anon=<kB> file=<kB> gpu_kb=<kB>
#
# gpu_kb is the Mali kbase driver's own count for the app's process: the
# used_pages of every GPU context it lists for that pid, times 4 KB. On this
# kernel kbase also charges those pages to the process's RssFile, so the two
# move together.
#
# Needs root (it reads the driver's table and the app's /proc entry):
#
#   adb push gpu-mem-sampler.sh /data/local/tmp/
#   adb shell "su -c 'nohup sh /data/local/tmp/gpu-mem-sampler.sh 60 10 >/dev/null 2>&1 &'"
#   adb shell am start -n dev.repro.hcpp_leak/.MainActivity
#   ... wait for the app to log "REPRO done" ...
#   adb shell su -c cat /data/local/tmp/gpu-mem.txt > gpu-mem.txt
PKG=dev.repro.hcpp_leak
OUT=/data/local/tmp/gpu-mem.txt
N=${1:-60}
EVERY=${2:-10}
: > $OUT
i=0
while [ $i -lt $N ]; do
  pid=$(pidof $PKG)
  avail=
  while read -r k v _; do
    [ "$k" = "MemAvailable:" ] && { avail=$v; break; }
  done < /proc/meminfo
  line="T $(date +%s) pid=$pid avail=$avail"
  if [ -n "$pid" ]; then
    anon= file=
    while read -r k v _; do
      case $k in
        RssAnon:) anon=$v ;;
        RssFile:) file=$v ;;
      esac
    done < /proc/$pid/status
    gpu=0
    while read -r ctx p pages _; do
      [ "$p" = "$pid" ] && gpu=$((gpu + pages))
    done < /sys/class/misc/mali0/device/gpu_memory
    line="$line anon=$anon file=$file gpu_kb=$((gpu * 4))"
  fi
  echo "$line" >> $OUT
  i=$((i + 1))
  sleep $EVERY
done
echo END >> $OUT
