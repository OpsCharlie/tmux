#!/bin/bash

P=$1
DIR=$(dirname "$(readlink -f "$0")")

if [ -z "$P" ]; then
    echo copy files to homedir
    mv ~/.tmux ~/.tmux.bak
    mv ~/.tmux.conf ~/.tmux.conf.bak
    cp -r "$DIR"/tmux ~/.tmux
    X="$(tmux -V)"
    [[ "$X" == "tmux 1.6" || "$X" == "tmux 1.8" ]] && cp "$DIR"/tmux/tmux.conf_1_6 ~/.tmux.conf
    [[ "$X" == "tmux 2.0" ]] && cp "$DIR"/tmux/tmux.conf_2_0 ~/.tmux.conf
    [[ "$X" == "tmux 2.1" ]] && cp "$DIR"/tmux/tmux.conf_2_1 ~/.tmux.conf
    [[ "$X" == "tmux 2.2" ]] && cp "$DIR"/tmux/tmux.conf_2_2 ~/.tmux.conf
    exit $?
fi

if [ "$(expr match "$P" '.*\(:\)')" = ":" ]; then
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

ssh "$P" '[[ "$(tmux -V)" == "tmux 1.6" ]] && cp ~/.tmux/tmux.conf_1_6 ~/.tmux.conf'
ssh "$P" '[[ "$(tmux -V)" == "tmux 1.8" ]] && cp ~/.tmux/tmux.conf_1_6 ~/.tmux.conf'
ssh "$P" '[[ "$(tmux -V)" == "tmux 2.0" ]] && cp ~/.tmux/tmux.conf_2_O ~/.tmux.conf'
ssh "$P" '[[ "$(tmux -V)" == "tmux 2.1" ]] && cp ~/.tmux/tmux.conf_2_1 ~/.tmux.conf'
ssh "$P" '[[ "$(tmux -V)" == "tmux 2.2" ]] && cp ~/.tmux/tmux.conf_2_2 ~/.tmux.conf'



