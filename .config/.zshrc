# ---------- basics ----------
export EDITOR=nano
export PAGER=less

# ---------- history ----------
HISTFILE="$HOME/.zsh_history"
HISTSIZE=20000
SAVEHIST=20000
setopt HIST_IGNORE_ALL_DUPS HIST_REDUCE_BLANKS SHARE_HISTORY INC_APPEND_HISTORY
setopt EXTENDED_HISTORY

# ---------- zinit ----------
ZINIT_HOME="${XDG_DATA_HOME}/zinit/zinit.git"
if [[ ! -f "${ZINIT_HOME}/zinit.zsh" ]]; then
  command mkdir -p "$(dirname "$ZINIT_HOME")"
  command git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi
source "${ZINIT_HOME}/zinit.zsh"

# ---------- plugins (via zinit) ----------
# autosuggestions
zinit light zsh-users/zsh-autosuggestions

# extra completions (must be before compinit)
zinit light zsh-users/zsh-completions

# fzf-tab (optional, needs `pkg install fzf`)
zinit light Aloxaf/fzf-tab

# syntax highlighting (must be loaded last among plugins)
zinit light zsh-users/zsh-syntax-highlighting

# ---------- completion ----------
autoload -Uz compinit
mkdir -p "${XDG_CONFIG_HOME}/zsh"
_compdump="${XDG_CONFIG_HOME}/zsh/zcompdump-${ZSH_VERSION}"
compinit -d "$_compdump"

# ---------- keybindings ----------
bindkey -e
bindkey '^R' history-incremental-search-backward

# ---------- prompt ----------
# starship (optional; needs `pkg install starship`)
command -v starship >/dev/null && eval "$(starship init zsh)"

# ---------- aliases ----------
source "$XDG_CONFIG_HOME/zsh/aliases.zsh" 2>/dev/null || true

# ---------- optional fzf config ----------
source "$XDG_CONFIG_HOME/zsh/fzf.zsh" 2>/dev/null || true

# fastfetch autostart (only interactive TTY)
[ -t 1 ] && command -v fastfetch >/dev/null 2>&1 && { clear; fastfetch; }

# colors (optional)
command -v vivid >/dev/null 2>&1 && export LS_COLORS="$(vivid generate zenburn)"
export EZA_COLORS="da=38;5;205:hd=38;5;141:sn=38;5;110:uu=38;5;250:gu=38;5;250"