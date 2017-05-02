#!/bin/bash
set -e

P=$1
DIR=$(dirname "$(readlink -f "$0")")

if [ -z "$P" ]; then
    echo copy files to homedir
    rsync -a --delete "$DIR/tmux/" ~/.tmux/
    X="$(tmux -V)"
    case "$X" in
        "tmux 1.6" | "tmux 1.8") cp "$DIR"/tmux/tmux.conf_1_6 ~/.tmux.conf ;;
        "tmux 2.0") cp "$DIR"/tmux/tmux.conf_2_0 ~/.tmux.conf ;;
        "tmux 2.1") cp "$DIR"/tmux/tmux.conf_2_1 ~/.tmux.conf ;;
        "tmux 2.2") cp "$DIR"/tmux/tmux.conf_2_2 ~/.tmux.conf ;;
    esac
    sed -e "s|set-option -g prefix C-a|set-option -g prefix C-b|g" -e "s|bind C-a    send-prefix|bind C-b    send-prefix|g" -e "s|bind a      send-key C-a|bind b      send-key C-b|g" -e "s|bind b      set status|#bind b      set status|g" -e "s|bind    r       source-file ~/.tmux.conf|bind    r       source-file ~/.tmux.ssh.conf|g" ~/.tmux.conf > ~/.tmux.ssh.conf

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

ssh "$P" 'X="$(tmux -V)"; case "$X" in "tmux 1.6" | "tmux 1.8") cp ~/.tmux/tmux.conf_1_6 ~/.tmux.conf ;; "tmux 2.0") cp ~/.tmux/tmux.conf_2_0 ~/.tmux.conf ;; "tmux 2.1") cp ~/.tmux/tmux.conf_2_1 ~/.tmux.conf ;; "tmux 2.2") cp ~/.tmux/tmux.conf_2_2 ~/.tmux.conf ;; esac; sed -e "s|set-option -g prefix C-a|set-option -g prefix C-b|g" -e "s|bind C-a    send-prefix|bind C-b    send-prefix|g" -e "s|bind a      send-key C-a|bind b      send-key C-b|g" -e "s|bind b      set status|#bind b      set status|g" -e "s|bind    r       source-file ~/.tmux.conf|bind    r       source-file ~/.tmux.ssh.conf|g" ~/.tmux.conf > ~/.tmux.ssh.conf'
