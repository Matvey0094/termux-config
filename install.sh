#!/data/data/com.termux/files/usr/bin/sh
set -eu

# ──────────────────────────────── UI ────────────────────────────────
ESC="$(printf '\033')"
RST="${ESC}[0m"
DIM="${ESC}[2m"
BOLD="${ESC}[1m"

C_CYAN="${ESC}[38;5;51m"
C_PURP="${ESC}[38;5;141m"
C_PINK="${ESC}[38;5;205m"
C_GRAY="${ESC}[38;5;245m"
C_OK="${ESC}[38;5;82m"
C_WARN="${ESC}[38;5;220m"
C_BAD="${ESC}[38;5;196m"

# Colorized bracketed tag: [OK], [INFO] etc. Brackets are colored too.
tag()  { printf "%s%s[%s%s%s]%s " "$BOLD" "$1" "$RST" "$BOLD" "$1" "$RST" "$RST"; }
info() { tag "$C_CYAN"; printf "%sINFO%s %s\n" "$BOLD" "$RST" "$*"; }
ok()   { tag "$C_OK";   printf "%s OK %s %s\n" "$BOLD" "$RST" "$*"; }
warn() { tag "$C_WARN"; printf "%sWARN%s %s\n" "$BOLD" "$RST" "$*"; }
fail() { tag "$C_BAD";  printf "%sFAIL%s %s\n" "$BOLD" "$RST" "$*"; exit 1; }

step_i=0
STEP_TOTAL=10
step() {
  step_i=$((step_i + 1))
  printf "\n%s%s[%d/%d]%s %s%s%s\n" \
    "$C_PURP" "$BOLD" "$step_i" "$STEP_TOTAL" "$RST" \
    "$C_PINK" "$1" "$RST"
}

have() { command -v "$1" >/dev/null 2>&1; }

# Prompt helper (works in sh). Default = second arg (y/n).
ask_yn() {
  prompt="$1"
  def="${2:-y}"
  while :; do
    if [ "$def" = "y" ]; then
      printf "%s%s?%s %s [Y/n]: %s" "$C_PURP" "$BOLD" "$RST" "$prompt" "$RST"
    else
      printf "%s%s?%s %s [y/N]: %s" "$C_PURP" "$BOLD" "$RST" "$prompt" "$RST"
    fi
    IFS= read -r ans || ans=""
    [ -n "$ans" ] || ans="$def"
    case "$ans" in
      y|Y) return 0 ;;
      n|N) return 1 ;;
    esac
  done
}

backup_if_exists() {
  f="$1"
  [ -f "$f" ] || return 0
  [ "${DO_BACKUP:-0}" = "1" ] || { warn "Backup disabled: $f"; return 0; }
  ts="$(date +%Y%m%d-%H%M%S)"
  cp -f "$f" "${f}.bak-${ts}" || true
  ok "Backup: ${f}.bak-${ts}"
}

# Check if a Termux package is installed
pkg_installed() {
  pkg_name="$1"
  dpkg -s "$pkg_name" >/dev/null 2>&1
}

# Install only missing packages, optionally update/upgrade first
install_pkgs() {
  missing=""
  for p in $PKGS; do
    if pkg_installed "$p"; then
      :
    else
      missing="$missing $p"
    fi
  done

  if [ -z "${missing# }" ] && [ -z "$missing" ]; then
    ok "All packages already installed"
    return 0
  fi

  warn "Missing packages:${missing}"
  if [ "${DO_UPGRADE:-0}" = "1" ]; then
    info "Updating repositories (silent)…"
    pkg update -y >/dev/null 2>&1 || true
    info "Upgrading installed packages (silent)…"
    pkg upgrade -y >/dev/null 2>&1 || true
  else
    warn "Skipping pkg update/upgrade"
  fi

  info "Installing missing packages (silent)…"
  # shellcheck disable=SC2086
  pkg install -y $missing >/dev/null 2>&1 || fail "pkg install failed"
  ok "Missing packages installed"
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

PKGS="curl git nano fastfetch zsh wget bat eza vivid"

# ─────────────────────────────── Banner ───────────────────────────────
printf "%s\n" "${C_PURP}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${RST}"
printf "%s\n" "${C_PURP}${BOLD}║        fastfetch / Termux — one-shot installer (cyber edition)       ║${RST}"
printf "%s\n" "${C_PURP}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${RST}"
printf "%s%sRepo:%s %s/%s (%s)\n%s" "$DIM" "$C_GRAY" "$RST" "$GH_USER" "$GH_REPO" "$GH_BRANCH" "$RST"

# ─────────────────────────────── Questions ──────────────────────────────
step "Installer options"
if ask_yn "Create backups of existing files before overwriting?" "y"; then
  DO_BACKUP=1; ok "Backups: enabled"
else
  DO_BACKUP=0; warn "Backups: disabled"
fi

if ask_yn "Run pkg update/upgrade? (recommended sometimes, slower)" "n"; then
  DO_UPGRADE=1; ok "System update: enabled"
else
  DO_UPGRADE=0; warn "System update: disabled"
fi

# ─────────────────────────────── Steps ────────────────────────────────

step "Install required packages (only missing, silent)"
info "Packages wanted: $PKGS"
install_pkgs

step "Set zsh as default (Termux)"
ZSH_PATH="${PREFIX}/bin/zsh"
[ -x "$ZSH_PATH" ] || fail "zsh not found at: $ZSH_PATH"
mkdir -p "${HOME}/.termux"
ln -sf "$ZSH_PATH" "${HOME}/.termux/shell" || fail "Failed to set ~/.termux/shell"
ok "Default shell set to zsh for new Termux sessions"
warn "Close ALL Termux sessions and reopen the app to apply"

step "Configure zsh (aliases + colors)"
ZSHRC="${HOME}/.zshrc"
touch "$ZSHRC"

cat >> "$ZSHRC" <<'EOF'

# ── termux managed start ──
# aliases
alias cat='bat'
alias ls='eza -lah --icons --group-directories-first --git --no-time'
alias la='eza -lah --icons --group-directories-first --git --time-style=long-iso'

# colors
export LS_COLORS="$(vivid generate zenburn)"
export EZA_COLORS="da=38;5;205:hd=38;5;141:sn=38;5;110:uu=38;5;250:gu=38;5;250"
# ── termux managed end ──
EOF

ok "Updated ~/.zshrc"
warn "Apply now: source ~/.zshrc"

step "Disable Termux welcome message (MOTD)"
touch "${HOME}/.hushlogin"
MOTD_USR="${PREFIX}/etc/motd"
MOTD_TERMUX="${PREFIX}/etc/motd.sh"
[ -f "$MOTD_USR" ] && : > "$MOTD_USR" || true
[ -f "$MOTD_TERMUX" ] && : > "$MOTD_TERMUX" || true
ok "Welcome message disabled"

step "Install Nerd Font (Inconsolata Mono)"
mkdir -p "$TERMUX_DIR"
backup_if_exists "$FONT_FILE"
curl -fsSL "$FONT_URL" -o "$FONT_FILE" || fail "Font download failed"
if have termux-reload-settings; then
  termux-reload-settings >/dev/null 2>&1 || true
fi
ok "Font installed to ~/.termux/font.ttf"
warn "If icons still look like squares: fully close Termux and open again"

step "Prepare fastfetch config directory"
mkdir -p "$CFG_DIR"
ok "Dir ready: $CFG_DIR"

step "Backup existing config/logo/nanorc (optional)"
backup_if_exists "$CFG_FILE"
backup_if_exists "$LOGO_FILE"
backup_if_exists "$NANORC_FILE"

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

step "Test run (non-fatal)"
if have fastfetch; then
  fastfetch --show-errors >/dev/null 2>&1 || true
  ok "fastfetch executed"
else
  warn "fastfetch not found after install"
fi

# ─────────────────────────────── Autostart ─────────────────────────────
if [ "${AUTO:-0}" = "1" ]; then
  step "Enable fastfetch autostart"
  PROFILE="${HOME}/.profile"
  touch "$PROFILE"
  if ! grep -q "fastfetch autostart" "$PROFILE" 2>/dev/null; then
    cat >> "$PROFILE" <<'EOF'

# ── fastfetch autostart ──
[ -t 1 ] && command -v fastfetch >/dev/null 2>&1 && { clear; fastfetch; }
EOF
    ok "Added autostart to ~/.profile"
  else
    ok "Autostart already present in ~/.profile"
  fi
fi

printf "\n%s%s✔ DONE%s %s\n" "$C_OK" "$BOLD" "$RST" "${C_GRAY}Fastfetch: ${CFG_FILE}${RST}"
printf "%s\n" "${DIM}Nano: ${NANORC_FILE}${RST}"
printf "%s\n" "${DIM}Run: fastfetch${RST}"
