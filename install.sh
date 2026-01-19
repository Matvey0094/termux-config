#!/data/data/com.termux/files/usr/bin/sh
set -eu

# ──────────────────────────────── UI ────────────────────────────────
ESC="$(printf '\033')"
RST="${ESC}[0m"
BOLD="${ESC}[1m"
DIM="${ESC}[2m"

C_CYAN="${ESC}[38;5;51m"
C_PURP="${ESC}[38;5;141m"
C_PINK="${ESC}[38;5;205m"
C_GRAY="${ESC}[38;5;245m"
C_OK="${ESC}[38;5;82m"
C_WARN="${ESC}[38;5;220m"
C_BAD="${ESC}[38;5;196m"

# tag COLOR LABEL
tag()  { printf "%s%s[%s]%s " "$1" "$BOLD" "$2" "$RST"; }
info() { tag "$C_CYAN" "INFO"; printf "%s\n" "$*"; }
ok()   { tag "$C_OK"   " OK "; printf "%s\n" "$*"; }
warn() { tag "$C_WARN" "WARN"; printf "%s\n" "$*"; }
fail() { tag "$C_BAD"  "FAIL"; printf "%s\n" "$*"; exit 1; }

step_i=0
STEP_TOTAL=10
step() {
  step_i=$((step_i + 1))
  printf "\n%s%s[%d/%d]%s %s%s%s\n" \
    "$C_PURP" "$BOLD" "$step_i" "$STEP_TOTAL" "$RST" \
    "$C_PINK" "$1" "$RST"
}

have() { command -v "$1" >/dev/null 2>&1; }

prompt_yn() {
  # prompt_yn "Question" "default(Y|N)"
  q="$1"
  d="${2:-N}"
  case "$d" in
    Y|y) hint=" [Y/n]"; def=Y ;;
    *)   hint=" [y/N]"; def=N ;;
  esac

  while :; do
    printf "%s?%s %s%s: %s" "$C_PURP" "$RST" "$q" "$hint" "$C_PINK"
    read ans || ans=""
    printf "%s" "$RST"
    [ -z "$ans" ] && ans="$def"
    case "$ans" in
      Y|y) return 0 ;;
      N|n) return 1 ;;
    esac
  done
}

maybe_backup() {
  # maybe_backup /path/to/file
  f="$1"
  [ "${DO_BACKUP:-0}" = "1" ] || return 0
  [ -f "$f" ] || return 0
  ts="$(date +%Y%m%d-%H%M%S)"
  cp -f "$f" "${f}.bak-${ts}" || true
  ok "Backup: ${f}.bak-${ts}"
}

# ─────────────────────────────── Settings ───────────────────────────────
GH_USER="Matvey0094"
GH_REPO="termux-config"
GH_BRANCH="main"

RAW_BASE="https://raw.githubusercontent.com/${GH_USER}/${GH_REPO}/${GH_BRANCH}"

REPO_CFG_PATH=".config/fastfetch/config.jsonc"
REPO_LOGO_PATH=".config/fastfetch/logo.txt"
REPO_NANORC_PATH=".config/.nanorc"

CFG_DIR="${HOME}/.config/fastfetch"
CFG_FILE="${CFG_DIR}/config.jsonc"
LOGO_FILE="${CFG_DIR}/logo.txt"
NANORC_FILE="${HOME}/.nanorc"

TERMUX_DIR="${HOME}/.termux"
FONT_FILE="${TERMUX_DIR}/font.ttf"
FONT_URL="https://raw.githubusercontent.com/ryanoasis/nerd-fonts/master/patched-fonts/Inconsolata/InconsolataNerdFontMono-Regular.ttf"

ZSHRC="${HOME}/.zshrc"
ZSH_PATH="${PREFIX}/bin/zsh"

PKGS="curl git nano fastfetch zsh wget bat eza vivid"

# ─────────────────────────────── Banner ───────────────────────────────
printf "%s\n" "${C_PURP}${BOLD}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${RST}"
printf "%s\n" "${C_PURP}${BOLD}┃   fastfetch / Termux — one-shot installer (cyber edition)            ┃${RST}"
printf "%s\n" "${C_PURP}${BOLD}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${RST}"
printf "%sRepo:%s %s/%s (%s)%s\n" "$DIM" "$RST" "$GH_USER" "$GH_REPO" "$GH_BRANCH" "$RST"

# ───────────────────────────── Installer options ─────────────────────────────
step "Installer options"
if prompt_yn "Create backups of existing files before overwriting?" "Y"; then
  DO_BACKUP=1
  ok "Backups: enabled"
else
  DO_BACKUP=0
  warn "Backups: disabled"
fi

if prompt_yn "Run pkg update/upgrade? (recommended sometimes, slower)" "N"; then
  DO_UPDATE=1
  ok "System update: enabled"
else
  DO_UPDATE=0
  warn "System update: disabled"
fi

# ───────────────────────────── Packages ─────────────────────────────
step "Install required packages (only missing, silent)"
info "Packages wanted: $PKGS"

missing=""
for p in $PKGS; do
  if dpkg -s "$p" >/dev/null 2>&1; then
    :
  else
    missing="${missing} ${p}"
  fi
done

if [ "${DO_UPDATE:-0}" = "1" ]; then
  pkg update -y >/dev/null 2>&1 || true
  pkg upgrade -y >/dev/null 2>&1 || true
fi

if [ -n "${missing# }" ]; then
  info "Missing:${missing}"
  # shellcheck disable=SC2086
  pkg install -y $missing >/dev/null 2>&1 || fail "pkg install failed"
  ok "Installed missing packages"
else
  ok "All packages already installed"
fi

# ───────────────────────────── zsh default ─────────────────────────────
step "Set zsh as default (Termux)"
[ -x "$ZSH_PATH" ] || fail "zsh not found at: $ZSH_PATH"
mkdir -p "$TERMUX_DIR"
ln -sf "$ZSH_PATH" "${TERMUX_DIR}/shell" || fail "Failed to set ~/.termux/shell"
ok "Default shell set to zsh for new Termux sessions"
warn "Close ALL Termux sessions and reopen the app to apply"

# ───────────────────────────── zshrc managed block ─────────────────────────────
step "Configure zsh (aliases + colors, clean managed block)"
maybe_backup "$ZSHRC"
touch "$ZSHRC"

# remove previous managed block (if exists)
sed -i '/^# ── termux managed start ──$/,/^# ── termux managed end ──$/d' "$ZSHRC" 2>/dev/null || true

cat >> "$ZSHRC" <<'EOF'

# ── termux managed start ──
# aliases
alias cat='bat'
alias ls='eza -lah --icons --group-directories-first --git --no-time'
alias la='eza -lah --icons --group-directories-first --git --time-style=long-iso'
alias apt='nala'

# colors
export LS_COLORS="$(vivid generate zenburn)"
export EZA_COLORS="da=38;5;205:hd=38;5;141:sn=38;5;110:uu=38;5;250:gu=38;5;250"
# ── termux managed end ──
EOF

ok "Updated ~/.zshrc (managed block refreshed)"
warn "Apply now: source ~/.zshrc"

# ───────────────────────────── MOTD ─────────────────────────────
step "Disable Termux welcome message (MOTD)"
touch "${HOME}/.hushlogin"
MOTD_USR="${PREFIX}/etc/motd"
MOTD_TERMUX="${PREFIX}/etc/motd.sh"
[ -f "$MOTD_USR" ] && : > "$MOTD_USR" || true
[ -f "$MOTD_TERMUX" ] && : > "$MOTD_TERMUX" || true
ok "Welcome message disabled"

# ───────────────────────────── Font ─────────────────────────────
step "Install Nerd Font (Inconsolata Mono)"
maybe_backup "$FONT_FILE"
mkdir -p "$TERMUX_DIR"
curl -fsSL "$FONT_URL" -o "$FONT_FILE" || fail "Font download failed"
if have termux-reload-settings; then
  termux-reload-settings >/dev/null 2>&1 || true
fi
ok "Font installed to ~/.termux/font.ttf"
warn "If icons still look like squares: fully close Termux and open again"

# ───────────────────────────── Config dir ─────────────────────────────
step "Prepare fastfetch config directory"
mkdir -p "$CFG_DIR"
ok "Dir ready: $CFG_DIR"

# ───────────────────────────── Backups (optional) ─────────────────────────────
step "Backup existing config/logo/nanorc (optional)"
maybe_backup "$CFG_FILE"
maybe_backup "$LOGO_FILE"
maybe_backup "$NANORC_FILE"

# ───────────────────────────── Downloads ─────────────────────────────
step "Download config, logo, nanorc from GitHub"
CFG_URL="${RAW_BASE}/${REPO_CFG_PATH}"
LOGO_URL="${RAW_BASE}/${REPO_LOGO_PATH}"
NANORC_URL="${RAW_BASE}/${REPO_NANORC_PATH}"

info "config: $CFG_URL"
curl -fsSL "$CFG_URL" -o "$CFG_FILE" || fail "Download failed: config.jsonc (check repo path/branch)"
info "logo:   $LOGO_URL"
curl -fsSL "$LOGO_URL" -o "$LOGO_FILE" || fail "Download failed: logo.txt (check repo path/branch)"
info "nanorc: $NANORC_URL"
curl -fsSL "$NANORC_URL" -o "$NANORC_FILE" || fail "Download failed: .nanorc (check repo path/branch)"

ok "Fastfetch + Nano config installed"

# ───────────────────────────── Test run ─────────────────────────────
step "Test run fastfetch (shows errors if any)"
if have fastfetch; then
  out="$(fastfetch --show-errors 2>&1)" || {
    warn "fastfetch returned non-zero. Output:"
    printf "%s\n" "$out"
    warn "Config path: $CFG_FILE"
    exit 0
  }
  ok "fastfetch executed"
else
  warn "fastfetch not found after install"
fi

printf "\n%s%s✔ DONE%s %s\n" "$C_OK" "$BOLD" "$RST" "${C_GRAY}Fastfetch: ${CFG_FILE}${RST}"
printf "%s\n" "${DIM}Nano: ${NANORC_FILE}${RST}"
printf "%s\n" "${DIM}Tip: source ~/.zshrc  (and restart Termux to switch shell)${RST}"
