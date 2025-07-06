#!/bin/bash
#===============================================================================
#
#          FILE: status_bar.sh
#
#         USAGE: in tmux config
#
#   DESCRIPTION: script to generate statusbar in tmux
#
#  REQUIREMENTS: bc, tmux
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: Carl Verstraete
#  ORGANIZATION:
#       CREATED: 26-11-18 13:18:56
#      REVISION:  ---
#===============================================================================


COL=$(tmux display -p "#{window_width}" 2>/dev/null || echo 80)
LC_NUMERIC="en_US.UTF-8"



_updates_available () {
    # Check for available system updates and print status

    if uname -a | grep -q Ubuntu; then
        CACHE=/tmp/updates.tmux

        [[ -e $CACHE ]] ||  /usr/lib/update-notifier/apt-check &>$CACHE

        if find "$CACHE" -mmin +10 > /dev/null; then
            /usr/lib/update-notifier/apt-check &>$CACHE
        fi

        UPDATES=$(cut -d';' -f1 $CACHE)
        SECUPDS=$(cut -d';' -f2 $CACHE)

        if [[ $UPDATES -ne 0 ]]; then
            printf "%d! " "$UPDATES"
        fi

        if [[ $SECUPDS -ne 0 ]]; then
            printf "#[default]#[fg=red]"; printf "%d!! " "$SECUPDS"; printf "#[default]#[fg=colour136]";
        fi

        if [[ $UPDATES -ne 0 ]] || [[ $SECUPDS -ne 0 ]]; then
            echo -ne "⡇ "
        fi
    fi

} # ----------  end of function updates_available  ----------




_uptime () {
    # Print system uptime in a human-readable format

    U=
    STR=

    if [[ $COL -gt 75 ]]; then
        if [[ -r /proc/uptime ]]; then
            read -r U _ < /proc/uptime
            U=${U%.*}
            if [[ $U -gt 86400 ]]; then
                STR="$((U / 86400))d$(((U % 86400) / 3600))h"
            elif [[ $U -gt 3600 ]]; then
                STR="$((U / 3600))h$(((U % 3600) / 60))m"
            elif [[ $U -gt 60 ]]; then
                STR="$((U / 60))m"
            else
                STR="${U}s"
            fi
        else
            STR=$(uptime | sed -e "s/.* up *//" -e "s/ *days, */d/" -e "s/:/h/" -e "s/,.*/m/")
        fi
        [ -n "$STR" ] || exit
        printf "%s ⡇ " "${STR}"
    fi

} # ----------  end of function uptime  ----------



_reboot () {
    # Indicate if a system reboot is required

    REBOOT_FLAG="/var/run/reboot-required"
    [[ -e "$REBOOT_FLAG" ]] && printf "%s" "⟳  ⡇ "

} # ----------  end of function reboot  ----------



_cpu () {
    # Print CPU load, memory usage, and user count

    USED_MEM=$(awk '/MemTotal/ {T=$2}; /MemFree/ {F=$2}; /Buffers/ {B=$2}; /^Cached/ {C=$2} END {print (T-F-B-C)/T*100}' /proc/meminfo)
    LOADAVG=$(cut -d' ' -f1 /proc/loadavg)
    NUMLOADAVG=$(getconf _NPROCESSORS_ONLN)


    if [[ $COL -gt 74 ]]; then
        USERS=$(users | tr " " "\n" | uniq | wc -l)     # uniq logged on users
        [[ $USERS -ne 1 ]] && printf "U:%d ⡇ " "$USERS"
        if (( $(echo "$LOADAVG > $NUMLOADAVG" | bc) )); then
            printf "L:"; printf "#[default]#[fg=red]"; printf "%.2f" "$LOADAVG"; printf "#[default]#[fg=colour136]"
        else
            printf "L:%.2f" "$LOADAVG"
        fi

        if (( $(echo "$USED_MEM > 80" | bc ) )); then
            printf " M:"; printf "#[default]#[fg=red]"; printf "%.f%%" "$USED_MEM"; printf "#[default]#[fg=colour136]"; printf " ⡇ "
        else
            printf " M:%.f%% ⡇ " "$USED_MEM"
        fi

    else
        if (( $(echo "$LOADAVG > $NUMLOADAVG" | bc ) )); then
            printf "L:"; printf "#[default]#[fg=red]"; printf "%.2f" "$LOADAVG"; printf "#[default]#[fg=colour136]"; printf " ⡇ "
        else
            printf "L:%.2f ⡇ " "$LOADAVG"
        fi
    fi
} # ----------  end of function cpu  ----------



_disk () {
    # Print disk usage warning and current disk IO rates

    for I in $(df -h | grep -Ev '/dev/loop|@|efivars|/tmp/.mount' | awk '{ print $5 }'  | grep -v "Use%" | tr -d "%"); do
        if [[ $I -gt 90 ]]; then
            echo -ne "#[default]#[fg=red]DF!!#[default]#[fg=colour136] ⡇ "
            break
        fi
    done

    CACHE=/tmp/disk.tmux
    if [[ ! -e $CACHE ]]; then
        SEC1="$(date +'%s')"
        R1=
        W1=

        for DEV in /sys/block/*; do
            [[ $DEV =~ ram|loop|md|dm-|sr ]] && continue
            R1=$((R1 + $(awk '{print $3}' "$DEV/stat")))
            W1=$((W1 + $(awk '{print $7}' "$DEV/stat")))
        done
    else
        read -r SEC1 R1 W1 < $CACHE
    fi

    SEC2="$(date +'%s')"
    R2=
    W2=

    for DEV in /sys/block/*; do
        [[ $DEV =~ ram|loop|md|dm-|sr ]] && continue
        R2=$((R2 + $(awk '{print $3}' "$DEV/stat")))
        W2=$((W2 + $(awk '{print $7}' "$DEV/stat")))
    done
    echo "$SEC2 $R2 $W2" > $CACHE

    # SEC=$(echo "$SEC2 - $SEC1" | bc)
    #
    #
    # RBPS=$(echo "($R2 - $R1) / $SEC" | bc )
    # WBPS=$(echo "($W2 - $W1) / $SEC" | bc )
    # RRBPS=$RBPS
    # RWBPS=$WBPS
    #
    #
    # UNITR="B"
    # UNITW="B"
    # if (( $(echo "$WBPS > 1000000" | bc ) )); then
    #     RWBPS=$(echo "$WBPS/1000000" | bc )
    #     UNITW="GB"
    # elif (( $(echo "$WBPS > 1000" | bc ) )); then
    #     RWBPS=$(echo "$WBPS/1000" | bc )
    #     UNITW="MB"
    # fi
    #
    # if (( $(echo "$RWBPS > 1000000" | bc ) )); then
    #     RRBPS=$(echo "$RBPS/1000000" | bc )
    #     UNITT="GB"
    # elif (( $(echo "$WBPS > 1000" | bc ) )); then
    #     RRBPS=$(echo "$WBPS/1000" | bc )
    #     UNITT="MB"
    # fi
    #
    # printf "IO: ◂%3.0f%2s ▸%3.0f%2s ⡇ " "$RRBPS" $UNITR "$RWBPS" $UNITW
 
    SEC=$((SEC2 - SEC1))
    SEC=${SEC:-1}  # avoid division by zero

    RBPS=$(( (R2 - R1) * 512 / SEC ))  # 512 bytes/block
    WBPS=$(( (W2 - W1) * 512 / SEC ))

    RDISK=$(echo "$RBPS" | numfmt --to=iec --suffix=B)
    WDISK=$(echo "$WBPS" | numfmt --to=iec --suffix=B)
    printf "IO: ◂%5s ▸%5s ⡇ " "$RDISK" "$WDISK"
} # ----------  end of function disk  ----------


_netspeed () {
    # Print current network speed (RX/TX) for main interface

    CACHE=/tmp/netspeed.tmux

    IF=$(ip route get 8.8.8.8 2>/dev/null | awk '{for(i=1;i<=NF;i++) if ($i=="dev") print $(i+1); exit}')
    IP=$(ip -oneline -family inet addr show "$IF" 2>/dev/null | awk '{split($4, a, "/"); print a[1]}')
    DEVS="$(ls -d /sys/class/net/* | grep -v lo)"

    if [[ ! -e $CACHE ]]; then
        SEC1="$(date +'%s')"
        R1=0
        T1=0
        for DEV in $DEVS; do
            R1=$((R1 + $(cat "$DEV"/statistics/rx_bytes)))
            T1=$((T1 + $(cat "$DEV"/statistics/tx_bytes)))
        done
        sleep 1
    else
        read -r SEC1 R1 T1 < $CACHE
    fi

    SEC2="$(date +'%s')"
    R2=0
    T2=0
    for DEV in $DEVS; do
        R2=$((R2 + $(cat "$DEV"/statistics/rx_bytes)))
        T2=$((T2 + $(cat "$DEV"/statistics/tx_bytes)))
    done
    echo "$SEC2 $R2 $T2" > $CACHE

    # SEC=$(echo "$SEC2 - $SEC1" | bc )
    #
    # TBPS=$(echo "($T2 - $T1) * 8 / $SEC" | bc ) # convert bytes in bits
    # RBPS=$(echo "($R2 - $R1) * 8 / $SEC" | bc ) # convert bytes in bits
    #
    # RTBPS=$TBPS                                 # Result TX bps
    # RRBPS=$RBPS                                 # Result RX bps
    # UNITT="b"                                   # Unit TX
    # UNITR="b"                                   # Unit RX
    #
    # TKBPS=$(( TBPS / 1000 ))                    # TX Kbps base-10 units
    # RKBPS=$(( RBPS / 1000 ))                    # RX Kbps base-10 units
    #
    # TMBPS=$(( TBPS / 1000000 ))                 # TX Mbps base-10 units
    # RMBPS=$(( RBPS / 1000000 ))                 # RX Mbps base-10 units
    #
    # if [[ $TMBPS != 0 ]]; then
    #     RTBPS=$TMBPS
    #     UNITT="Mb"
    # elif [[ $TKBPS != 0 ]]; then
    #     RTBPS=$TKBPS
    #     UNITT="Kb"
    # fi
    #
    # if [[ $RMBPS != 0 ]]; then
    #     RRBPS=$RMBPS
    #     UNITR="Mb"
    # elif [[ $RKBPS != 0 ]]; then
    #     RRBPS=$RKBPS
    #     UNITR="Kb"
    # fi
    #
    # IF="${IF:0:6}"
    # if [[ "$COL" -gt 101 ]]; then
    #     if [[ "$COL" -gt 119 ]]; then
    #         printf "%s: %s ▾%3.0f%2s ▴%3.0f%2s" "$IF" "$IP" "$RRBPS" "$UNITR" "$RTBPS" "$UNITT"
    #     else
    #         printf "%s ▾%3.0f%2s ▴%3.0f%2s" "$IP" "$RRBPS" "$UNITR" "$RTBPS" "$UNITT"
    #     fi
    # else
    #     printf "▾%3.0f%2s ▴%3.0f%2s" "$RRBPS" "$UNITR" "$RTBPS" "$UNITT"
    # fi
    SEC=$((SEC2 - SEC1))
    SEC=${SEC:-1}

    RBPS=$(( (R2 - R1) / SEC ))
    TBPS=$(( (T2 - T1) / SEC ))

    RNET=$(echo "$RBPS" | numfmt --to=iec --suffix=B/s)
    TNET=$(echo "$TBPS" | numfmt --to=iec --suffix=B/s)

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
} # ----------  end of function netspeed  ----------



_temp () {
    # Print average CPU temperature if available

    if [[ "$COL" -gt 110 ]]; then
        case "$OSTYPE" in
            linux-gnu)
                if command -v sensors > /dev/null; then
                    T=$(sensors | awk '/^Core/ {print $3;}')
                    if [[ -n $T ]]; then
                        echo "$T" | grep -oEi '[0-9]+.[0-9]+' | awk '{TOTAL+=$1; COUNT+=1} END {printf "%.1f°C ⡇ ", TOTAL/COUNT}'
                    fi
                else
                    echo -n ""
                fi
                ;;
        esac
    fi
} # ----------  end of function _temp  ----------



_battery () {
    # Print battery percentage if available

    if [[ "$COL" -gt 125 ]]; then
        if [[ -d /sys/class/power_supply/BAT0 ]]; then
            awk -F= '
            /_NOW/ {N=$2}
            /_FULL/ {F=$2}
            END {
                if (N && F) {
                    P=N/F*100
                    if (P < 99) printf "B: %d%% ⡇ ", P
                }
            }' /sys/class/power_supply/BAT0/uevent
        else
            echo -n ""
        fi
    fi
} # ----------  end of function _battery  ----------


umask 111
exec 300>/tmp/lock_"$(basename "$0")".pid || exit 1
flock -n 300 || exit 1
_temp
_battery
_updates_available
_uptime
_reboot
_cpu
_disk
_netspeed
