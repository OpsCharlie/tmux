#!/bin/bash
#===============================================================================
#
#          FILE: status_bar.sh
#
#         USAGE: in tmux config
#
#   DESCRIPTION: script to generate statusbar in tmux (performance optimized)
#
#  REQUIREMENTS: /usr/bin/awk, gnu find, tmux
#          BUGS: ---
#         NOTES: Optimized for performance with caching and parallel execution
#        AUTHOR: Carl Verstraete
#  ORGANIZATION:
#       CREATED: 26-11-18 13:18:56
#      REVISION: 31-01-26
#===============================================================================

COL=$(tmux display -p "#{client_width}" 2>/dev/null || echo 180)
export LC_NUMERIC=C
# Deliberately not /tmp/tmux-$UID: that is tmux's own socket directory
CACHE_DIR="/tmp/tmux-status-$UID"
CACHE_TTL=10 # Cache for 10 seconds

/usr/bin/mkdir -p "$CACHE_DIR"

_cache() {
  local key="$1"
  local ttl="$2"
  local cmd="$3"
  local cache_file="$CACHE_DIR/$key"
  local NOW mtime tmp
  NOW=$(/usr/bin/date +%s)

  if [[ -f "$cache_file" ]]; then
    mtime=$(/usr/bin/stat -c %Y "$cache_file" 2>/dev/null) || mtime=0
    if ((NOW - mtime < ttl)); then
      /usr/bin/cat "$cache_file"
      return
    fi
  fi

  # Write to a temp file and move it into place only on success, so a failed or
  # interrupted command cannot cache an empty result for the rest of the TTL.
  # The move is also atomic, so a concurrent reader never sees a partial file.
  tmp=$(/usr/bin/mktemp "$cache_file.XXXXXX") || return
  if /bin/bash -c "CACHE_DIR=\$1; $cmd" _ "$CACHE_DIR" >"$tmp"; then
    /bin/mv -f "$tmp" "$cache_file"
    /usr/bin/cat "$cache_file"
  else
    /bin/rm -f "$tmp"
    [[ -f "$cache_file" ]] && /usr/bin/cat "$cache_file"
  fi
}


_updates_available() {
  _cache "updates" 900 "
     if command -v pacman >/dev/null; then
       yay_installed=\"false\"
       paru_installed=\"false\"
       if command -v yay >/dev/null; then
         yay_installed=\"true\"
       fi
       if command -v paru >/dev/null; then
         paru_installed=\"true\"
       fi
       if [[ \$yay_installed == \"true\" ]] && [[ \$paru_installed == \"false\" ]]; then
         aur_helper=\"yay\"
       elif [[ \$yay_installed == \"false\" ]] && [[ \$paru_installed == \"true\" ]]; then
         aur_helper=\"paru\"
       else
         aur_helper=\"yay\"
       fi
       UPDATES_aur=\$(\$aur_helper -Qum | wc -l)
       UPDATES_pacman=\$(checkupdates | wc -l)
       UPDATES=\$((UPDATES_aur+UPDATES_pacman))
     elif command -v dnf >/dev/null; then
       UPDATES=\$(dnf check-update -q | grep -c '^[a-z0-9]')
     elif command -v apt >/dev/null; then
       UPDATES=\$(apt list --upgradable 2>/dev/null | tail -n +2 | wc -l)
     else
       UPDATES=0
     fi
     if [[ \$UPDATES -ne 0 ]]; then
       printf \"%d! ⡇ \" \"\$UPDATES\"
     else
       echo -ne \"⡇ \"
     fi
    "
}


_uptime() {
  if [[ $COL -gt 75 ]]; then
    /usr/bin/awk '{d=int($1/86400); if(d>1) printf "%dd ", d; printf "%dh%dm ⡇ ", int($1%86400/3600), int($1%3600/60)}' /proc/uptime
  fi
}


_reboot() {
  # The answer only changes on a kernel upgrade, and `file` on the kernel image
  # is the most expensive thing here, so do not run it every status interval.
  _cache "reboot" 300 "
     if [[ -e /run/reboot-required ]]; then
       printf '%s' '⟳ ⡇ '
     elif ! file /boot/vmlinuz* 2>/dev/null | grep -q \"\$(uname -r)\"; then
       printf '%s' '⟳ ⡇ '
     fi
    "
}


_cpu() {
  USED_MEM=$(/usr/bin/awk '/MemTotal/ {t=$2} /MemAvailable/ {a=$2} END { if (t && a) printf "%.0f", (t-a)/t*100; else print 0 }' /proc/meminfo)
  USERS=$(/usr/bin/who | /usr/bin/awk '!seen[$1]++ {count++} END {print count+0}')

  read -r LOADAVG _ </proc/loadavg
  NUMLOADAVG=$(/usr/bin/getconf _NPROCESSORS_ONLN 2>/dev/null)

  if [[ $COL -gt 74 ]]; then
    [[ $USERS -ne 1 ]] && printf "U:%d ⡇ " "$USERS"
    /usr/bin/awk -v l="$LOADAVG" -v n="$NUMLOADAVG" 'BEGIN {if (l > n) printf "L:#[default]#[fg=red]%.2f#[default]#[fg=colour136] ⡇ ", l; else printf "L:%.2f ⡇ ", l}'
    if ((USED_MEM > 80)); then
      printf "M:#[default]#[fg=red]%s%%#[default]#[fg=colour136] ⡇ " "$USED_MEM"
    else
      printf "M:%s%% ⡇ " "$USED_MEM"
    fi
  else
    /usr/bin/awk -v l="$LOADAVG" -v n="$NUMLOADAVG" 'BEGIN {if (l > n) printf "L:#[default]#[fg=red]%.2f#[default]#[fg=colour136] ⡇ ", l; else printf "L:%.2f ⡇ ", l}'
  fi
}


_disk() {
  local CACHE="$CACHE_DIR/disk.tmux"
  local SEC SEC2 R2 W2 SEC1 R1 W1 RBPS WBPS RDISK WDISK DEV

  SEC2=$(/usr/bin/date +%s)
  R2=0
  W2=0

  # Only physical devices: a `device` symlink excludes dm-* and loop*, which
  # are layered on top of the real disks and would be counted a second time.
  for DEV in /sys/block/*/; do
    [[ -e "$DEV/device" && -r "$DEV/stat" ]] || continue
    if read -r _ _ r _ _ _ w _ _ _ <"$DEV/stat"; then
      ((R2 += r, W2 += w))
    fi
  done

  # Read previous values from cache, or initialize
  if [[ ! -e $CACHE ]]; then
    echo "$SEC2 $R2 $W2" >"$CACHE"
    SEC1=$SEC2
    R1=$R2
    W1=$W2
  else
    read -r SEC1 R1 W1 <"$CACHE"
    echo "$SEC2 $R2 $W2" >"$CACHE"
  fi

  SEC=$((SEC2 - SEC1))
  ((SEC == 0)) && SEC=1 # avoid division by zero

  # Calculate bytes per second, with fallback
  RBPS=$(((R2 - R1) * 512 / SEC))
  WBPS=$(((W2 - W1) * 512 / SEC))
  # Guard against a stale cache producing negative deltas
  ((RBPS < 0)) && RBPS=0
  ((WBPS < 0)) && WBPS=0

  # Format for human-readable output
  RDISK=$(/usr/bin/numfmt --to=iec --suffix=B <<<"$RBPS")
  WDISK=$(/usr/bin/numfmt --to=iec --suffix=B <<<"$WBPS")
  RDISK=${RDISK:-0B}
  WDISK=${WDISK:-0B}

  printf "IO: ◂%5s ▸%5s ⡇ " "$RDISK" "$WDISK"
}


_disk_warn() {
  _cache "disk_usage" "$CACHE_TTL" "
     /usr/bin/df -h --output=target,pcent 2>/dev/null |
     /usr/bin/awk 'NR>1 && \$1 !~ /loop|efivars|@|\\/tmp\\/\\.mount/ && \$2+0>90 {printf \"#[default]#[fg=red]DF!!#[default]#[fg=colour136] ⡇\"; exit 0}'
     "
}


_get_netinfo() {
  _cache "netinfo" 30 "
    IF=\$(/usr/bin/ip route get 8.8.8.8 2>/dev/null | /usr/bin/awk '{for(i=1;i<=NF;i++) if (\$i==\"dev\") print \$(i+1); exit}')
    IP=\$(/usr/bin/ip -o -4 addr show \"\$IF\" 2>/dev/null | /usr/bin/awk '{split(\$4,a,\"/\"); print a[1]}')
    echo \"\$IF \$IP\"
  "
}


_netspeed() {
  local CACHE="$CACHE_DIR/netspeed.tmux"
  local IF IP SEC SEC2 R2 T2 SEC1 R1 T1 RBPS TBPS RNET TNET

  read -r IF IP <<<"$(_get_netinfo)"
  [[ -z "$IF" ]] && return

  SEC2=$(/usr/bin/date +%s)
  read -r R2 2>/dev/null <"/sys/class/net/$IF/statistics/rx_bytes" || R2=""
  read -r T2 2>/dev/null <"/sys/class/net/$IF/statistics/tx_bytes" || T2=""
  # Counters unreadable (e.g. cached IF went stale/away): skip this cycle
  # rather than emitting garbage/blank speeds.
  [[ -z "$R2" || -z "$T2" ]] && return
  if [[ ! -e $CACHE ]]; then
    echo "$SEC2 $R2 $T2" >"$CACHE"
    printf "▾0B/s ▴0B/s"
    return
  else
    read -r SEC1 R1 T1 <"$CACHE"
    echo "$SEC2 $R2 $T2" >"$CACHE"
  fi

  SEC=$((SEC2 - SEC1))
  ((SEC == 0)) && SEC=1 # avoid division by zero

  RBPS=$(((R2 - R1) / SEC))
  TBPS=$(((T2 - T1) / SEC))
  # Guard against a stale/truncated cache producing negative deltas
  ((RBPS < 0)) && RBPS=0
  ((TBPS < 0)) && TBPS=0

  RNET=$(/usr/bin/numfmt --to=iec --suffix=B/s <<<"$RBPS")
  TNET=$(/usr/bin/numfmt --to=iec --suffix=B/s <<<"$TBPS")

  IF="${IF:0:6}"
  if [[ "$COL" -gt 101 ]]; then
    if [[ "$COL" -gt 119 ]]; then
      printf "%s: %s ▾%7s ▴%7s" "$IF" "$IP" "$RNET" "$TNET"
    else
      printf "%s ▾%7s ▴%7s" "$IP" "$RNET" "$TNET"
    fi
  else
    printf "▾%7s ▴%7s" "$RNET" "$TNET"
  fi
}


_temp() {
  [[ "$COL" -le 110 ]] && return

  local temps=()
  case "$OSTYPE" in
    linux-gnu)
      for hw in /sys/class/hwmon/hwmon*; do
        [[ -d "$hw" && -f "$hw/name" ]] || continue
        name=$(<"$hw/name")
        case "$name" in
          coretemp | k10temp | zenpower)
            for temp_file in "$hw"/temp*_input; do
              [[ -f "$temp_file" ]] || continue
              temp=$(<"$temp_file")
              ((temp > 0)) && temps+=($((temp / 1000)))
            done
            ;;
        esac
      done

      # Fallback to thermal zones if no hwmon temps found
      if [[ ${#temps[@]} -eq 0 ]]; then
        for tz in /sys/class/thermal/thermal_zone*; do
          [[ -f "$tz/temp" ]] || continue
          temp=$(<"$tz/temp")
          ((temp > 0)) && temps+=($((temp / 1000)))
        done
      fi

      if [[ ${#temps[@]} -gt 0 ]]; then
        local total=0

        for t in "${temps[@]}"; do
          total=$((total + t))
        done
        /usr/bin/awk "BEGIN {printf \"%.1f°C ⡇ \", $total/${#temps[@]}}"
      fi
      ;;
  esac
}


_battery() {
  [[ "$COL" -le 125 ]] && return

  if [[ -r /sys/class/power_supply/BAT0/capacity ]]; then
    # `capacity` is the percentage the kernel already computed. Deriving it from
    # uevent is fragile: /_NOW/ also matches VOLTAGE_NOW and /_FULL/ also
    # matches CHARGE_FULL_DESIGN, so the result depends on field ordering.
    _cache "battery" 60 "
            read -r P </sys/class/power_supply/BAT0/capacity
            [[ \$P -lt 99 ]] && printf 'B: %d%% ⡇ ' \"\$P\"
            exit 0
        "
  fi
}

LAST_OUTPUT="$CACHE_DIR/last_output"

# The lock lives in the per-user cache dir: a fixed name in shared /tmp would be
# owned by whoever ran first, and every other user would fail to open it.
exec 300>"$CACHE_DIR/status_bar.lock" || exit 1
if ! /usr/bin/flock -n 300; then
  # A previous run is still going (a slow `checkupdates`, say). Reprint its
  # output rather than exiting empty, which would blank the status bar.
  [[ -f "$LAST_OUTPUT" ]] && /usr/bin/cat "$LAST_OUTPUT"
  exit 0
fi

segments=(_temp _battery _updates_available _uptime _reboot _cpu _disk_warn _disk _netspeed)
declare -A results
declare -A pids

# Run each segment in the background, redirecting output to a temp file
for seg in "${segments[@]}"; do
  tmpfile="$CACHE_DIR/${seg}.out"
  "$seg" >"$tmpfile" 2>&1 &
  pids["$seg"]=$!
done

# Wait for all to finish
for seg in "${segments[@]}"; do
  wait "${pids[$seg]}"
  results[$seg]=$(<"$CACHE_DIR/${seg}.out")
done

# Combine results in desired order
output="${results[_temp]}${results[_battery]}${results[_updates_available]}${results[_uptime]}${results[_reboot]}${results[_cpu]}${results[_disk_warn]}${results[_disk]}${results[_netspeed]}"
printf '%s' "$output" | /usr/bin/tee "$LAST_OUTPUT"
