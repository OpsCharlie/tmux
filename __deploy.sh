#!/bin/bash
set -e

P=$1
DIR=$(dirname "$(readlink -f "$0")")
# set manual for use with ansible
DIR=/home/carl/tmux

if [ -z "$P" ]; then
    echo copy files to homedir
    rsync -a --delete "$DIR/tmux/" ~/.tmux/
    cp $DIR/tmux.conf ~/.tmux.conf

    exit $?
fi

if [ "$(sed "s/.*\(:\).*/\1/g" <<<$P)" = ":" ]; then
    echo "Usage:"
    echo "$0               to deploy local"
    echo "$0 user@host     to deploy remote"
    exit 1
fi

rsync -rptvz --delete --exclude ".git" "$DIR"/tmux/ "$P":~/.tmux
rsync -rptvz --delete --exclude ".git" "$DIR"/tmux.conf "$P":~/.tmux.conf


#echo '
#PROMPT_COMMAND="history -a;$PROMPT_COMMAND"
#export TERM=xterm-256color
#'

