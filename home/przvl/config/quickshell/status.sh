#!/usr/bin/env bash
set -euo pipefail

read_cpu() {
  local user nice system idle iowait irq softirq steal
  read -r _ user nice system idle iowait irq softirq steal _ _ < /proc/stat
  printf '%s %s\n' "$((user + nice + system + idle + iowait + irq + softirq + steal))" "$((idle + iowait))"
}

read -r total_before idle_before < <(read_cpu)
sleep 0.2
read -r total_after idle_after < <(read_cpu)
elapsed=$((total_after - total_before))
idle_elapsed=$((idle_after - idle_before))
cpu=0
if (( elapsed > 0 )); then
  cpu=$(((elapsed - idle_elapsed) * 100 / elapsed))
fi

mem_total=0
mem_available=0
while read -r key value _; do
  case "$key" in
    MemTotal:) mem_total=$value ;;
    MemAvailable:) mem_available=$value ;;
  esac
done < /proc/meminfo
ram_used=$(((mem_total - mem_available) / 1048576))
ram_total=$((mem_total / 1048576))

battery=""
for supply in /sys/class/power_supply/*; do
  [[ -f "$supply/type" && -f "$supply/capacity" ]] || continue
  [[ $(<"$supply/type") == Battery ]] || continue
  [[ ! -f "$supply/scope" || $(<"$supply/scope") == System ]] || continue
  battery=$(<"$supply/capacity")
  break
done

brightness=""
for device in /sys/class/backlight/*; do
  [[ -f "$device/brightness" && -f "$device/max_brightness" ]] || continue
  maximum=$(<"$device/max_brightness")
  if (( maximum > 0 )); then
    brightness=$(( $(<"$device/brightness") * 100 / maximum ))
  fi
  break
done

printf 'cpu=%s\nram=%s/%s\nbattery=%s\nbrightness=%s\n' \
  "$cpu" "$ram_used" "$ram_total" "$battery" "$brightness"
