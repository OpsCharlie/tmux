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

COL=$(tmux display -p "#{window_width}" 2>/dev/null || echo 180)
export LC_NUMERIC=C
CACHE_DIR="/tmp/tmux-$UID"
CACHE_TTL=10 # Cache for 10 seconds

/usr/bin/mkdir -p "$CACHE_DIR"

_cache() {
  local key="$1"
  local ttl="$2"
  local cmd="$3"
  local cache_file="$CACHE_DIR/$key"
  local NOW
  NOW=$(/usr/bin/date +%s)

  if [[ -f "$cache_file" ]]; then
    mtime=$(/usr/bin/stat -c %Y "$cache_file" 2>/dev/null) || mtime=0
    if ((NOW - mtime < ttl)); then
      /usr/bin/cat "$cache_file"
      return
    fi
  fi

  /bin/bash -c "CACHE_DIR=\$1; $cmd" _ "$CACHE_DIR" >"$cache_file" 
  /usr/bin/cat "$cache_file"
}


_updates_available() {
  [[ ! -d /etc/lsb-release ]] || return

  _cache "updates" 900 "
        CACHE=\"\$CACHE_DIR/updates.tmux\"
        /usr/lib/update-notifier/apt-check 2>\$CACHE
        IFS=';' read -r UPDATES SECUPDS < \"\$CACHE\" 2>/dev/null || { UPDATES=0; SECUPDS=0; }
        if [[ \$UPDATES -ne 0 ]]; then
            printf \"%d! \" \"\$UPDATES\"
        fi
        if [[ \$SECUPDS -ne 0 ]]; then
            printf \"#[default]#[fg=red]%d!! #[default]#[fg=colour136]\" \"\$SECUPDS\"
        fi
        if [[ \$UPDATES -ne 0 ]] || [[ \$SECUPDS -ne 0 ]]; then
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
  [[ -e "/var/run/reboot-required" ]] && printf "%s" "⟳ ⡇ "
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
  local SEC2 R2 W2 SEC1 R1 W1 RBPS WBPS RDISK WDISK

  SEC2=$(/usr/bin/date +%s)
  R2=0
  W2=0

  for DEV in /sys/block/sd*/stat /sys/block/nvme*/stat /sys/block/dm-*/stat; do
    [[ -r $DEV ]] || continue
    if read -r _ _ r _ _ _ w _ _ _ <"$DEV"; then
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
  RBPS=${RBPS:-0}
  WBPS=${WBPS:-0}

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
  local IF IP SEC2 R2 T2 SEC1 R1 T1 RBPS TBPS RNET TNET

  read -r IF IP <<<"$(_get_netinfo)"
  [[ -z "$IF" ]] && return

  SEC2=$(/usr/bin/date +%s)
  read -r R2 2>/dev/null <"/sys/class/net/$IF/statistics/rx_bytes"
  read -r T2 2>/dev/null <"/sys/class/net/$IF/statistics/tx_bytes"
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

  if [[ -d /sys/class/power_supply/BAT0 ]]; then
    _cache "battery" 60 "
            /usr/bin/awk -F= '
            /_NOW/ {N=\$2}
            /_FULL/ {F=\$2}
            END {
                if (N && F) {
                    P=N/F*100
                    if (P < 99) printf \"B: %d%% ⡇ \", P
                }
            }' /sys/class/power_supply/BAT0/uevent 2>/dev/null || echo ''
        "
  fi
}

exec 300>/tmp/lock_"$(/usr/bin/basename "$0")".pid || exit 1
/usr/bin/flock -n 300 || exit 1

segments=(_temp _battery _updates_available _uptime _reboot _cpu _disk_warn _disk _netspeed)
declare -A results

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
echo -n "${results[_temp]}${results[_battery]}${results[_updates_available]}${results[_uptime]}${results[_reboot]}${results[_cpu]}${results[_disk_warn]}${results[_disk]}${results[_netspeed]}"
