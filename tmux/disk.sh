#!/bin/bash


LC_NUMERIC="en_US.UTF-8"
for i in $(df -h | awk '{ print $5 }'  | grep -v "Use%" | tr -d "%"); do
    if [ "$i" -gt "90" ]; then
        X=""
        echo -ne "#[default]#[fg=red]DF!!#[default]#[fg=colour136] ⡇ "
        break
    fi
done

io_line_count=`iostat -d -x -m | wc -l` ;
iostat -d -x -m 1 2 -z | tail -n +$io_line_count | grep -e "^sd[a-z].*\|^.\?vd.*\|^nvm" | awk 'BEGIN{rsum=0; wsum=0}{ rsum+=$6; wsum+=$7} END {printf "IO: ◂%.1fMB ▸%.1fMB ⡇ ", rsum, wsum}'
