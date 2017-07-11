#!/bin/bash

COL=$(tmux list-windows | head -1 | sed 's/.*\[\([0-9]\{1,4\}\)x[0-9]\{1,4\}\].*/\1/g')

u=
idle=
str=


if [ "$COL" -gt 75 ]; then
    if [ -r /proc/uptime ]; then
        read u idle < /proc/uptime
        u=${u%.*}
        if [ "$u" -gt 86400 ]; then
            str="$(($u / 86400))d$((($u % 86400) / 3600))h"
        elif [ "$u" -gt 3600 ]; then
            str="$(($u / 3600))h$((($u % 3600) / 60))m"
        elif [ "$u" -gt 60 ]; then
            str="$(($u / 60))m"
        else
            str="${u}s"
        fi
    else
        str=$(uptime | sed -e "s/.* up *//" -e "s/ *days, */d/" -e "s/:/h/" -e "s/,.*/m/")
    fi
    [ -n "$str" ] || exit
    printf "%s ⡇ " "${str}"
fi
