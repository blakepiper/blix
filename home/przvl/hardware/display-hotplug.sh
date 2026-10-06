#!/usr/bin/env bash
set -u

[[ -n ${DISPLAY:-} ]] || exit 0

runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
pid_path="$runtime_dir/blix-display-hotplug-$UID.pid"
display_layout=${BLIX_DISPLAY_LAYOUT:-extend}
primary_output=${BLIX_PRIMARY_OUTPUT:?BLIX_PRIMARY_OUTPUT must name the primary monitor}
primary_rotation=${BLIX_PRIMARY_ROTATION:-normal}
display_dpi=${BLIX_DISPLAY_DPI:-}
external_output=${BLIX_EXTERNAL_OUTPUT:-}
read -r -a additional_external_outputs <<< "${BLIX_ADDITIONAL_EXTERNAL_OUTPUTS:-}"
mirror_mode=${BLIX_MIRROR_MODE:-1920x1080}
mirror_rate=${BLIX_MIRROR_RATE:-}
primary_scale_from=${BLIX_PRIMARY_SCALE_FROM:-}
wallpaper=${BLIX_WALLPAPER:-}
once_mode=0
[[ ${1:-} == --once ]] && once_mode=1

if (( ! once_mode )) && [[ -r $pid_path ]]; then
  read -r old_pid < "$pid_path" || old_pid=''
  if [[ $old_pid =~ ^[0-9]+$ ]] && [[ $old_pid != "$$" ]] && kill -0 "$old_pid" 2>/dev/null; then
    exit 0
  fi
fi
if (( ! once_mode )); then
  printf '%s\n' "$$" > "$pid_path" 2>/dev/null || exit 0
fi

display_monitor_pid=''
cleanup() {
  [[ -z $display_monitor_pid ]] || kill "$display_monitor_pid" 2>/dev/null || true
  (( once_mode )) || rm -f "$pid_path"
}
trap cleanup EXIT INT TERM

apply_wallpaper() {
  [[ -n $wallpaper && -r $wallpaper ]] || return 0
  command -v feh >/dev/null 2>&1 || return 0
  feh --no-fehbg --bg-fill "$wallpaper" >/dev/null 2>&1 || true
}

last_display_state=''

# Set the caller's mode_args to a preferred/configured mode and its highest
# numeric rate. A preferred (+) or active (*) marker is not a refresh cap.
select_output_mode() {
  local query=$1 output=$2 requested_mode=${3:-} fixed_rate=${4:-}
  local mode='' rate=''
  read -r mode rate < <(LC_ALL=C awk -v output="$output" -v wanted="$requested_mode" '
    /^[^[:space:]]/ { active = ($1 == output && $2 == "connected"); next }
    active {
      max = 0; best = ""; preferred = 0
      for (i = 2; i <= NF; i++) {
        token = $i
        if (token !~ /^[0-9]+(\.[0-9]+)?[+*]*$/) continue
        if (token ~ /\+/) preferred = 1
        gsub(/[+*]/, "", token)
        if (token + 0 > max) { max = token + 0; best = token }
      }
      if (best == "") next
      if (wanted != "") {
        if ($1 == wanted && max > chosen_max) {
          chosen = $1; chosen_rate = best; chosen_max = max
        }
      } else if (chosen == "" || (preferred && !chosen_preferred)) {
        chosen = $1; chosen_rate = best; chosen_preferred = preferred
      }
    }
    END { if (chosen != "") print chosen, chosen_rate }
  ' <<< "$query") || true

  mode_args=(--auto)
  if [[ -n $requested_mode ]]; then
    mode_args=(--mode "$requested_mode")
  elif [[ -n $mode ]]; then
    mode_args=(--mode "$mode")
  fi
  [[ -z $fixed_rate ]] || rate=$fixed_rate
  [[ -z $rate ]] || mode_args+=(--rate "$rate")
  return 0
}

apply_output_mode() {
  local query=$1 output=$2 requested_mode=$3 fixed_rate=$4
  local -a mode_args=()
  shift 4
  select_output_mode "$query" "$output" "$requested_mode" "$fixed_rate"
  xrandr --output "$output" "${mode_args[@]}" "$@" && return 0

  # Advertised timings can exceed a dock's bandwidth once other outputs are
  # active. Retry at the same resolution without forcing the rejected rate.
  if [[ -z $fixed_rate ]] && (( ${#mode_args[@]} >= 3 )) && [[ ${mode_args[-2]} == --rate ]]; then
    echo "Retrying $output with an automatic refresh rate." >&2
    xrandr --output "$output" "${mode_args[@]:0:${#mode_args[@]}-2}" "$@"
  else
    return 1
  fi
}

configure_external_monitor() {
  command -v xrandr >/dev/null 2>&1 || return 0

  local outputs output status _rest pattern matched primary_connected=false display_state=''
  local -a connected=() disconnected=() mode_args=()
  outputs=$(LC_ALL=C xrandr --query 2>/dev/null) || return 0
  while read -r output status _rest; do
    [[ $status == connected || $status == disconnected ]] || continue
    if [[ $output == "$primary_output" ]]; then
      [[ $status != connected ]] || primary_connected=true
      display_state+="$output $status;"
      continue
    fi
    matched=0
    if [[ $display_layout == extend || $output == "$external_output" ]]; then
      matched=1
    else
      for pattern in "${additional_external_outputs[@]}"; do
        # Deliberately interpret the configured connector as a shell glob.
        # shellcheck disable=SC2053
        if [[ $output == $pattern ]]; then
          matched=1
          break
        fi
      done
    fi
    (( matched )) || continue

    display_state+="$output $status;"
    if [[ $status == connected ]]; then
      connected+=("$output")
    else
      disconnected+=("$output")
    fi
  done <<< "$outputs"

  if ! "$primary_connected"; then
    # Reapply rotation and scaling when the primary panel reconnects, even if
    # the other connectors have not changed. Keep other displays untouched.
    last_display_state=''
    printf 'Primary monitor %s is not connected; leaving the display layout unchanged.\n' "$primary_output" >&2
    return 0
  fi

  # Reconsider newly advertised rates, while ignoring changes to the active
  # (*) marker caused by our own modeset and duplicate dock notifications.
  local requested_mode='' fixed_rate=''
  if [[ $display_layout == mirror ]] && (( ${#connected[@]} )); then
    requested_mode=$mirror_mode
    fixed_rate=$mirror_rate
  fi
  for output in "$primary_output" "${connected[@]}"; do
    select_output_mode "$outputs" "$output" "$requested_mode" "$fixed_rate"
    display_state+="$output ${mode_args[*]};"
  done

  # A dock emits multiple notifications for one connection change. Mode and
  # property changes must not cause another reset of an already configured
  # connection. Remember disconnections too, so reconnecting resets once.
  [[ $display_state != "$last_display_state" ]] || return 0
  last_display_state=$display_state

  for output in "${disconnected[@]}"; do
    xrandr --output "$output" --off || true
  done

  if [[ $display_layout == extend ]]; then
    local previous_output=$primary_output
    if [[ -n $primary_scale_from ]]; then
      apply_output_mode "$outputs" "$primary_output" '' '' --rotate "$primary_rotation" --scale-from "$primary_scale_from" --pos 0x0 --primary || return 0
    else
      apply_output_mode "$outputs" "$primary_output" '' '' --rotate "$primary_rotation" --scale 1x1 --pos 0x0 --primary || return 0
    fi
    for output in "${connected[@]}"; do
      apply_output_mode "$outputs" "$output" '' '' --scale 1x1 --right-of "$previous_output" || return 0
      previous_output=$output
    done
  elif (( ${#connected[@]} )); then
    apply_output_mode "$outputs" "$primary_output" "$mirror_mode" "$mirror_rate" \
      --rotate "$primary_rotation" --scale 1x1 --pos 0x0 --primary || return 0
    for output in "${connected[@]}"; do
      # A reconnect can retain an active CRTC with a black screen. Reset once
      # for the new connection, never once per queued dock notification.
      xrandr --output "$output" --off || true
      # Use the 8-bit link setting that recovers the dock's HDMI monitor.
      # Keep enabling the display if an older driver lacks this property.
      xrandr --output "$output" --set "max bpc" 8 || true
      apply_output_mode "$outputs" "$output" "$mirror_mode" "$mirror_rate" \
        --scale 1x1 --same-as "$primary_output" || true
    done
    xset dpms force on || true
  else
    if [[ -n $primary_scale_from ]]; then
      apply_output_mode "$outputs" "$primary_output" '' '' --rotate "$primary_rotation" --scale-from "$primary_scale_from" --pos 0x0 --primary || true
    else
      apply_output_mode "$outputs" "$primary_output" '' '' --rotate "$primary_rotation" --scale 1x1 --pos 0x0 --primary || true
    fi
  fi
  [[ -z $display_dpi ]] || xrandr --dpi "$display_dpi" || true
  apply_wallpaper
}

configure_external_monitor
[[ ${1:-} == --once ]] && exit 0

watch_display() {
  local line action='' hotplug=''
  while IFS= read -r line; do
    if [[ -z $line ]]; then
      if [[ $action == change && $hotplug == 1 ]]; then
        sleep 1
        configure_external_monitor
      fi
      action=''
      hotplug=''
    elif [[ $line == ACTION=* ]]; then
      action=${line#ACTION=}
    elif [[ $line == HOTPLUG=* ]]; then
      hotplug=${line#HOTPLUG=}
    fi
  done
}

udevadm monitor --udev --property --subsystem-match=drm 2>/dev/null | watch_display &
display_monitor_pid=$!
wait "$display_monitor_pid"
