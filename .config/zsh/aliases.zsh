# ── fastfetch autostart ──
[ -t 1 ] && command -v fastfetch >/dev/null 2>&1 && { clear; fastfetch; }

command -v eza >/dev/null && alias ls='eza -lh --icons --group-directories-first --git --no-time' && alias la='eza -lah --icons --group-directories-first --git --time-style=long-iso'
command -v bat >/dev/null && alias cat='bat -p'

alias ..='cd ..'
alias ...='cd ../..'



# colors
command -v vivid >/dev/null 2>&1 && export LS_COLORS="$(viv
id generate zenburn)"
export EZA_COLORS="da=38;5;205:hd=38;5;141:sn=38;5;110:uu=3
8;5;250:gu=38;5;250"