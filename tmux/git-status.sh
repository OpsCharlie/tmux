#!/usr/bin/env bash

if [ $2 = "1" ]; then
    COLOR='#[fg=green]'
else
    COLOR='#[fg=colour244]'
fi

function _GITSTATUS {
    local branch="$(git branch 2>/dev/null | grep '^*' | colrm 1 2)"

    if [ -n "${branch}" ]; then
        local git_status="$(git status --porcelain -b 2>/dev/null)"
        local letters="$( echo "${git_status}" | grep --regexp=' \w ' | sed -e 's/^\s\?\(\w\)\s.*$/\1/' )"
        local untracked="$( echo "${git_status}" | grep -F '?? ' | sed -e 's/^\?\(\?\)\s.*$/\1/' )"
        local status_line="$( echo -e "${letters}\n${untracked}" | sort | uniq | tr -d '[:space:]' )"
        STATUS="- (${branch}"
        if [ -n "${status_line}" ]; then
            STATUS+="- ${status_line}"
        fi
        STATUS+=")"
    fi

    printf -- "${COLOR}${STATUS}"
}


exec 301>/tmp/git-status.sh || exit 1
flock -n 301 || exit 1
cd $1
_GITSTATUS
