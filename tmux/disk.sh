#!/bin/bash

LC_NUMERIC="en_US.UTF-8"

for i in $(df -h | grep -v '/dev/loop' | awk '{ print $5 }'  | grep -v "Use%" | tr -d "%"); do
    if [ "$i" -gt "90" ]; then
        X=""
        echo -ne "#[default]#[fg=red]DF!!#[default]#[fg=colour136] ⡇ "
        break
    fi
done


cache=/tmp/disk.tmux
if [ ! -e $cache ]; then
    SEC1="$(date +'%s')"
    R1=
    W1=

    for DEV in $(ls --ignore=loop* /sys/block/); do
        R1=$((R1 + $(awk '{print $3}' /sys/block/$DEV/stat)))
        W1=$((W1 + $(awk '{print $7}' /sys/block/$DEV/stat)))
    done
else
    read SEC1 R1 W1 < $cache
fi


SEC2="$(date +'%s')"
R2=
W2=

for DEV in $(ls --ignore=loop* /sys/block/); do
    R2=$((R2 + $(awk '{print $3}' /sys/block/$DEV/stat)))
    W2=$((W2 + $(awk '{print $7}' /sys/block/$DEV/stat)))
done
echo "$SEC2 $R2 $W2" > $cache

SEC=$(bc <<< "$SEC2 - $SEC1")


RBPS=$(bc <<< "($R2 - $R1) / $SEC")
WBPS=$(bc <<< "($W2 - $W1) / $SEC")
RRBPS=$RBPS
RWBPS=$WBPS


unitr="B"
unitw="B"
if (( $(bc <<< "$WBPS > 1000000") )); then
    RWBPS=$(bc <<< "$WBPS/1000000")
    unitw="GB"
elif (( $(bc <<< "$WBPS > 1000") )); then
    RWBPS=$(bc <<< "$WBPS/1000")
    unitw="MB"
fi

if (( $(bc <<< "$RWBPS > 1000000") )); then
    RRBPS=$(bc <<< "$RBPS/1000000")
    unitt="GB"
elif (( $(bc <<< "$WBPS > 1000") )); then
    RRBPS=$(bc <<< "$WBPS/1000")
    unitt="MB"
fi

printf "IO: ◂%3.0f%2s ▸%3.0f%2s ⡇ " "$RRBPS" $unitr "$RWBPS" $unitw

