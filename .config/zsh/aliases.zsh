command -v eza >/dev/null && alias ls='eza -lh --icons --group-directories-first --git --no-time' && alias la='eza -lah --icons --group-directories-first --git --time-style=long-iso'
command -v bat >/dev/null && alias cat='bat -p'

alias ..='cd ..'
alias ...='cd ../..'