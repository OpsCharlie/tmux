#!/bin/bash

LC_NUMERIC="en_US.UTF-8"

cache=/tmp/netspeed.tmux

IF=$(ip route get 8.8.8.8 | head -n1 | cut -d' ' -f5)
IP=$(/sbin/ip address show $IF | awk '/inet / {print $2}')
IP=${IP%%/*}
COL=$(tmux list-windows | head -1 | sed 's/.*\[\([0-9]\{1,4\}\)x[0-9]\{1,4\}\].*/\1/g')

if [ ! -e $cache ]; then
    SEC1="$(date +'%s')"
    R1=
    T1=
    for DEV in /sys/class/net/*; do
        R1=$((R1 + $(cat $DEV/statistics/rx_bytes)))
    done
    for DEV in /sys/class/net/*; do
        T1=$((T1 + $(cat $DEV/statistics/tx_bytes)))
    done
    sleep 1
else
    read SEC1 R1 T1 < $cache
fi

SEC2="$(date +'%s')"
R2=
T2=
for DEV in /sys/class/net/*; do
    R2=$((R2 + $(cat $DEV/statistics/rx_bytes)))
done
for DEV in /sys/class/net/*; do
    T2=$((T2 + $(cat $DEV/statistics/tx_bytes)))
done
echo "$SEC2 $R2 $T2" > $cache

SEC=$(bc <<< "$SEC2 - $SEC1")

TBPS=$(bc <<< "($T2 - $T1) * 8 / $SEC") # convert bytes in bits
RBPS=$(bc <<< "($R2 - $R1) * 8 / $SEC") # convert bytes in bits
if (( $(bc <<< "$TBPS < 0") )); then TBPS=0; fi
if (( $(bc <<< "$RBPS < 0") )); then RBPS=0; fi
RTBPS=$TBPS
RRBPS=$RBPS

# base-10 units
#1 kB = 1,000 bytes (Note: small k)
#1 MB = 1,000 kB = 1,000,000 bytes
unitr="b"
unitt="b"


if (( $(bc <<< "$TBPS > 1000000000") )); then
    RTBPS=$(bc <<< "$TBPS/1000000000")
    unitt="Gb"
elif (( $(bc <<< "$TBPS > 1000000") )); then
    RTBPS=$(bc <<< "$TBPS/1000000")
    unitt="Mb"
elif (( $(bc <<< "$TBPS > 1000") )); then
    RTBPS=$(bc <<< "$TBPS/1000")
    unitt="Kb"
fi


if (( $(bc <<< "$RBPS > 1000000000") )); then
    RRBPS=$(bc <<< "$RBPS/1000000000")
    unitt="Gb"
elif (( $(bc <<< "$RBPS > 1000000") )); then
    RRBPS=$(bc <<< "$RBPS/1000000")
    unitt="Mb"
elif (( $(bc <<< "$RBPS > 1000") )); then
    RRBPS=$(bc <<< "$RBPS/1000")
    unitt="Kb"
fi



if [ "$COL" -gt 101 ]; then
    if [ "$COL" -gt 119 ]; then
        printf "%s: %s ▾%3.0f%2s ▴%3.0f%2s" $IF $IP $RRBPS $unitr $RTBPS $unitt
    else
        printf "%s ▾%3.0f%2s ▴%3.0f%2s" $IP $RRBPS $unitr $RTBPS $unitt
    fi
else
    printf "▾%3.0f%2s ▴%3.0f%2s" $RRBPS $unitr $RTBPS $unitt
fi
