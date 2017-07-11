#!/bin/bash

TMP=/tmp/updates.tmux

[ -e $TMP ] ||  /usr/lib/update-notifier/apt-check &>$TMP

if test $(find $TMP -mmin +10 &>/dev/null); then
    /usr/lib/update-notifier/apt-check &>$TMP
fi

UPDATES=$(cat $TMP | cut -d';' -f1)
SECUPDS=$(cat $TMP | cut -d';' -f2)

if [ $UPDATES -ne 0 ]; then
    printf "%d! " $UPDATES
fi

if [ $SECUPDS -ne 0 ]; then
   printf "#[default]#[fg=red]"; printf "%d!! " $SECUPDS; printf "#[default]#[fg=colour136]"; 
fi

if [[ $UPDATES -ne 0 ]] || [[ $SECUPDS -ne 0 ]]; then
    echo -ne "⡇ "
fi

