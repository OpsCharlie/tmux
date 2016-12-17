#!/bin/bash

LC_NUMERIC="en_US.UTF-8"

cache=/tmp/netspeed.tmux

IF=$(ip route get 8.8.8.8 | head -n1 | cut -d' ' -f5)
IP=$(/sbin/ip address show $IF | awk '/inet / {print $2}')
IP=${IP%%/*}
COL=$(tmux list-windows | head -1 | sed 's/.*\[\([0-9]\{1,4\}\)x[0-9]\{1,4\}\].*/\1/g')

unitr="kb"
unitt="kb"

R1=
T1=
for DEV in /sys/class/net/*; do
    R1=$((R1 + $(cat $DEV/statistics/rx_bytes)))
done
for DEV in /sys/class/net/*; do
    T1=$((T1 + $(cat $DEV/statistics/tx_bytes)))
done

sleep 1

R2=
T2=
for DEV in /sys/class/net/*; do
    R2=$((R2 + $(cat $DEV/statistics/rx_bytes)))
done
for DEV in /sys/class/net/*; do
    T2=$((T2 + $(cat $DEV/statistics/tx_bytes)))
done

TKBPS=$(bc <<< "($T2 - $T1) * 8 / 1024")
RKBPS=$(bc <<< "($R2 - $R1) * 8 / 1024")
if (( $(bc <<< "$TKBPS < 0") )); then TKBPS=0; fi
if (( $(bc <<< "$RKBPS < 0") )); then RKBPS=0; fi


if (( $(bc <<< "$TKBPS > 1048576") )); then
    TKBPS=$(awk "BEGIN { print $TKBPS/1024/1024  }")
    unitt="Gb"
elif (( $(bc <<< "$TKBPS > 1024") )); then
    TKBPS=$(awk "BEGIN { print $TKBPS/1024  }")
    unitt="Mb"
fi

if (( $(bc <<< "$RKBPS > 1048576") )); then
    RKBPS=$(awk "BEGIN { print $TKBPS/1024/1024  }")
    unitr="Gb"
elif (( $(bc <<< "$RKBPS > 1024") )); then
    RKBPS=$(awk "BEGIN { print $RKBPS/1024  }")
    unitr="Mb"
fi

if [ "$COL" -gt 101 ]; then
    if [ "$COL" -gt 119 ]; then
        printf "%s: %s ▾%5.1f%s ▴%5.1f%s" $IF $IP $RKBPS $unitr $TKBPS $unitt
    else
        printf "%s ▾%5.1f%s ▴%5.1f%s" $IP $RKBPS $unitr $TKBPS $unitt
    fi
else
    printf "▾%5.1f%s ▴%5.1f%s" $RKBPS $unitr $TKBPS $unitt
fi
