#!/usr/bin/env bash
set -euo pipefail

battery=""
battery_eta=""
format_minutes() {
  local minutes=$1
  printf '%dh %02dm' "$((minutes / 60))" "$((minutes % 60))"
}

for supply in /sys/class/power_supply/*; do
  [[ -f "$supply/type" && -f "$supply/capacity" ]] || continue
  [[ $(<"$supply/type") == Battery ]] || continue
  [[ ! -f "$supply/scope" || $(<"$supply/scope") == System ]] || continue
  battery=$(<"$supply/capacity")
  status=$(<"$supply/status")
  energy_now=0 energy_full=0 power_now=0
  charge_now=0 charge_full=0 current_now=0
  [[ ! -f "$supply/energy_now" ]] || energy_now=$(<"$supply/energy_now")
  [[ ! -f "$supply/energy_full" ]] || energy_full=$(<"$supply/energy_full")
  [[ ! -f "$supply/power_now" ]] || power_now=$(<"$supply/power_now")
  [[ ! -f "$supply/charge_now" ]] || charge_now=$(<"$supply/charge_now")
  [[ ! -f "$supply/charge_full" ]] || charge_full=$(<"$supply/charge_full")
  [[ ! -f "$supply/current_now" ]] || current_now=$(<"$supply/current_now")
  remaining=0
  if [[ $status == Discharging ]]; then
    if (( power_now > 0 && energy_now > 0 )); then
      remaining=$((energy_now * 60 / power_now))
    elif (( current_now > 0 && charge_now > 0 )); then
      remaining=$((charge_now * 60 / current_now))
    fi
    if (( remaining > 0 )); then
      battery_eta="~$(format_minutes "$remaining") remaining"
    else
      battery_eta="Time remaining unavailable"
    fi
  elif [[ $status == Charging ]]; then
    if (( power_now > 0 && energy_full > energy_now )); then
      remaining=$(((energy_full - energy_now) * 60 / power_now))
    elif (( current_now > 0 && charge_full > charge_now )); then
      remaining=$(((charge_full - charge_now) * 60 / current_now))
    fi
    if (( remaining > 0 )); then
      battery_eta="~$(format_minutes "$remaining") until full"
    else
      battery_eta="Charging"
    fi
  elif [[ $status == Full ]]; then
    battery_eta="Fully charged"
  else
    battery_eta="$status"
  fi
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

printf 'battery=%s\nbattery_eta=%s\nbrightness=%s\n' "$battery" "$battery_eta" "$brightness"
