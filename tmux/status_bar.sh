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


COL=$(tmux list-windows | head -1 | sed 's/.*\[\([0-9]\{1,4\}\)x[0-9]\{1,4\}\].*/\1/g')
LC_NUMERIC="en_US.UTF-8"



_updates_available () {

    if [  -n "$(uname -a | grep Ubuntu)" ]; then
        CACHE=/tmp/updates.tmux

        [ -e $CACHE ] ||  /usr/lib/update-notifier/apt-check &>$CACHE

        if test $(find $CACHE -mmin +10); then
            /usr/lib/update-notifier/apt-check &>$CACHE
        fi

        UPDATES=$(cut -d';' -f1 $CACHE)
        SECUPDS=$(cut -d';' -f2 $CACHE)

        if [ $UPDATES -ne 0 ]; then
            printf "%d! " $UPDATES
        fi

        if [ $SECUPDS -ne 0 ]; then
            printf "#[default]#[fg=red]"; printf "%d!! " $SECUPDS; printf "#[default]#[fg=colour136]";
        fi

        if [[ $UPDATES -ne 0 ]] || [[ $SECUPDS -ne 0 ]]; then
            echo -ne "⡇ "
        fi
    fi

}	# ----------  end of function updates_available  ----------




_uptime () {

    U=
    IDLE=
    STR=

    if [ "$COL" -gt 75 ]; then
        if [ -r /proc/uptime ]; then
            read U IDLE < /proc/uptime
            U=${U%.*}
            if [ "$U" -gt 86400 ]; then
                STR="$(($U / 86400))d$((($U % 86400) / 3600))h"
            elif [ "$U" -gt 3600 ]; then
                STR="$(($U / 3600))h$((($U % 3600) / 60))m"
            elif [ "$U" -gt 60 ]; then
                STR="$(($U / 60))m"
            else
                STR="${U}s"
            fi
        else
            STR=$(uptime | sed -e "s/.* up *//" -e "s/ *days, */d/" -e "s/:/h/" -e "s/,.*/m/")
        fi
        [ -n "$STR" ] || exit
        printf "%s ⡇ " "${STR}"
    fi

}	# ----------  end of function uptime  ----------



_reboot () {

    REBOOT_FLAG="/var/run/reboot-required"
    [ -e "$REBOOT_FLAG" ] && printf "%s" "⟳  ⡇ "

}	# ----------  end of function reboot  ----------



_cpu () {

    USED_MEM=$(awk '/MemTotal/ {T=$2}; /MemFree/ {F=$2}; /Buffers/ {B=$2}; /^Cached/ {C=$2} END {print (T-F-B-C)/T*100}' /proc/meminfo)
    LOADAVG=$(cut -d' ' -f1 /proc/loadavg)
    NUMLOADAVG=$(nproc)

    if [ $COL -gt 74 ]; then
        USERS=$(users | tr " " "\n" | uniq | wc -l)     # uniq logged on users
        [[ $USERS -ne 1 ]] && printf "U:%d ⡇ " $USERS
        if (( $(echo "$LOADAVG > $NUMLOADAVG" | bc) )); then
            printf "L:"; printf "#[default]#[fg=red]"; printf "%.2f" $LOADAVG; printf "#[default]#[fg=colour136]"
        else
            printf "L:%.2f" $LOADAVG
        fi

        if (( $(echo "$USED_MEM > 80" | bc ) )); then
            printf " M:"; printf "#[default]#[fg=red]"; printf "%.f%%" $USED_MEM; printf "#[default]#[fg=colour136]"; printf " ⡇ "
        else
            printf " M:%.f%% ⡇ " $USED_MEM
        fi

    else
        if (( $(echo "$LOADAVG > $NUMLOADAVG" | bc ) )); then
            printf "L:"; printf "#[default]#[fg=red]"; printf "%.2f" $LOADAVG; printf "#[default]#[fg=colour136]"; printf " ⡇ "
        else
            printf "L:%.2f ⡇ " $LOADAVG
        fi
    fi
}	# ----------  end of function cpu  ----------



_disk () {

    for I in $(df -h | egrep -v '/dev/loop|@' | awk '{ print $5 }'  | grep -v "Use%" | tr -d "%"); do
        if [ "$I" -gt "90" ]; then
            X=""
            echo -ne "#[default]#[fg=red]DF!!#[default]#[fg=colour136] ⡇ "
            break
        fi
    done


    CACHE=/tmp/disk.tmux
    if [ ! -e $CACHE ]; then
        SEC1="$(date +'%s')"
        R1=
        W1=

        for DEV in $(ls /sys/block/ | egrep -v "ram|loop|md|dm-|sr"); do
            R1=$((R1 + $(awk '{print $3}' /sys/block/$DEV/stat)))
            W1=$((W1 + $(awk '{print $7}' /sys/block/$DEV/stat)))
        done
    else
        read SEC1 R1 W1 < $CACHE
    fi


    SEC2="$(date +'%s')"
    R2=
    W2=

    for DEV in $(ls /sys/block/ | egrep -v "ram|loop|md|dm-|sr"); do
        R2=$((R2 + $(awk '{print $3}' /sys/block/$DEV/stat)))
        W2=$((W2 + $(awk '{print $7}' /sys/block/$DEV/stat)))
    done
    echo "$SEC2 $R2 $W2" > $CACHE

    SEC=$(echo "$SEC2 - $SEC1" | bc)


    RBPS=$(echo "($R2 - $R1) / $SEC" | bc )
    WBPS=$(echo "($W2 - $W1) / $SEC" | bc )
    RRBPS=$RBPS
    RWBPS=$WBPS


    UNITR="B"
    UNITW="B"
    if (( $(echo "$WBPS > 1000000" | bc ) )); then
        RWBPS=$(echo "$WBPS/1000000" | bc )
        UNITW="GB"
    elif (( $(echo "$WBPS > 1000" | bc ) )); then
        RWBPS=$(echo "$WBPS/1000" | bc )
        UNITW="MB"
    fi

    if (( $(echo "$RWBPS > 1000000" | bc ) )); then
        RRBPS=$(echo "$RBPS/1000000" | bc )
        UNITT="GB"
    elif (( $(echo "$WBPS > 1000" | bc ) )); then
        RRBPS=$(echo "$WBPS/1000" | bc )
        UNITT="MB"
    fi

    printf "IO: ◂%3.0f%2s ▸%3.0f%2s ⡇ " "$RRBPS" $UNITR "$RWBPS" $UNITW

}	# ----------  end of function disk  ----------


_netspeed () {

    CACHE=/tmp/netspeed.tmux

    IF=$(ip route get 8.8.8.8 | head -n1 | cut -d' ' -f5)
    IP=$(/sbin/ip address show $IF | awk '/inet / {print $2}')
    IP=${IP%%/*}
    DEVS="$(ls -d /sys/class/net/* | grep -v lo)"

    if [ ! -e $CACHE ]; then
        SEC1="$(date +'%s')"
        R1=0
        T1=0
        for DEV in $DEVS; do
            R1=$((R1 + $(cat $DEV/statistics/rx_bytes)))
        done
        for DEV in $DEVS; do
            T1=$((T1 + $(cat $DEV/statistics/tx_bytes)))
        done
        sleep 1
    else
        read SEC1 R1 T1 < $CACHE
    fi

    SEC2="$(date +'%s')"
    R2=0
    T2=0
    for DEV in $DEVS; do
        R2=$((R2 + $(cat $DEV/statistics/rx_bytes)))
    done
    for DEV in $DEVS; do
        T2=$((T2 + $(cat $DEV/statistics/tx_bytes)))
    done
    echo "$SEC2 $R2 $T2" > $CACHE

    SEC=$(echo "$SEC2 - $SEC1" | bc )

    TBPS=$(echo "($T2 - $T1) * 8 / $SEC" | bc ) # convert bytes in bits
    RBPS=$(echo "($R2 - $R1) * 8 / $SEC" | bc ) # convert bytes in bits

    RTBPS=$TBPS                                 # Result TX bps
    RRBPS=$RBPS                                 # Result RX bps
    UNITT="b"                                   # Unit TX
    UNITR="b"                                   # Unit RX

    TKBPS=$(( TBPS / 1000 ))                    # TX Kbps base-10 units
    RKBPS=$(( RBPS / 1000 ))                    # RX Kbps base-10 units

    TMBPS=$(( TBPS / 1000000 ))                 # TX Mbps base-10 units
    RMBPS=$(( RBPS / 1000000 ))                 # RX Mbps base-10 units

    if [[ $TMBPS != 0 ]]; then
        RTBPS=$TMBPS
        UNITT="Mb"
    elif [[ $TKBPS != 0 ]]; then
        RTBPS=$TKBPS
        UNITT="Kb"
    fi

    if [[ $RMBPS != 0 ]]; then
        RRBPS=$RMBPS
        UNITR="Mb"
    elif [[ $RKBPS != 0 ]]; then
        RRBPS=$RKBPS
        UNITR="Kb"
    fi

    IF="${IF:0:5}"
    if [ "$COL" -gt 101 ]; then
        if [ "$COL" -gt 119 ]; then
            printf "%s: %s ▾%3.0f%2s ▴%3.0f%2s" $IF $IP $RRBPS $UNITR $RTBPS $UNITT
        else
            printf "%s ▾%3.0f%2s ▴%3.0f%2s" $IP $RRBPS $UNITR $RTBPS $UNITT
        fi
    else
        printf "▾%3.0f%2s ▴%3.0f%2s" $RRBPS $UNITR $RTBPS $UNITT
    fi
}	# ----------  end of function netspeed  ----------



_temp () {

    if [ "$COL" -gt 110 ]; then
        case "$OSTYPE" in
            linux-gnu)
                if which sensors > /dev/null; then
                    T=$(sensors | awk '/^Core/ {print $3;}')
                    if [ ! -z "$T" ]; then
                        echo "$T" | grep -oEi '[0-9]+.[0-9]+' | awk '{TOTAL+=$1; COUNT+=1} END {printf "%d%s", TOTAL/COUNT, "°C ⡇ "}'
                    fi
                else
                    echo -n ""
                fi
                ;;
        esac
    fi
}	# ----------  end of function _temp  ----------



_battery () {

    if [ "$COL" -gt 125 ]; then
        if [ -d /sys/class/power_supply/BAT0 ]; then
            awk -F"=" '/^POWER_SUPPLY_(CHARGE|ENERGY)_NOW/ {N=$2}; /^POWER_SUPPLY_(CHARGE|ENERGY)_FULL=/ {F=$2}; END {P=N/F*100; if (P < 99) printf "B: %d%% ⡇ ",P}' /sys/class/power_supply/BAT0/uevent
        else
            echo -n ""
        fi
    fi
}	# ----------  end of function _battery  ----------


umask 111
exec 300>/tmp/lock_$(basename $0).pid || exit 1
flock -n 300 || exit 1
_temp
_battery
_updates_available
_uptime
_reboot
_cpu
_disk
_netspeed
