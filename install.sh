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

tag()  { printf "%s[%s%s%s]%s " "$DIM" "$BOLD" "$1" "$DIM" "$RST"; }
info() { tag "${C_CYAN}INFO"; printf "%s\n" "$*"; }
ok()   { tag "${C_OK} OK ";  printf "%s\n" "$*"; }
warn() { tag "${C_WARN}WARN";printf "%s\n" "$*"; }
fail() { tag "${C_BAD}FAIL"; printf "%s\n" "$*"; exit 1; }

step_i=0
STEP_TOTAL=8
step() {
  step_i=$((step_i + 1))
  printf "\n%s%s[%d/%d]%s %s%s%s\n" \
    "$C_PURP" "$BOLD" "$step_i" "$STEP_TOTAL" "$RST" \
    "$C_PINK" "$1" "$RST"
}

have() { command -v "$1" >/dev/null 2>&1; }
backup_if_exists() {
  f="$1"
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

PKGS="curl git nano fastfetch zsh wget bat eza"

# ─────────────────────────────── Banner ───────────────────────────────
printf "%s\n" "${C_PURP}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${RST}"
printf "%s\n" "${C_PURP}${BOLD}║        fastfetch / Termux — one-shot installer (cyber edition)       ║${RST}"
printf "%s\n" "${C_PURP}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${RST}"
printf "%s%sRepo:%s %s/%s (%s)\n%s" "$DIM" "$C_GRAY" "$RST" "$GH_USER" "$GH_REPO" "$GH_BRANCH" "$RST"

# ─────────────────────────────── Steps ────────────────────────────────

step "Install required packages (silent)"
info "Packages: $PKGS"
# shellcheck disable=SC2086
pkg update -y >/dev/null 2>&1 || true
pkg upgrade -y >/dev/null 2>&1 || true
# shellcheck disable=SC2086
pkg install -y $PKGS >/dev/null 2>&1 || fail "pkg install failed"
ok "Packages installed"

step "Set zsh as default (Termux)"
ZSH_PATH="${PREFIX}/bin/zsh"

[ -x "$ZSH_PATH" ] || fail "zsh not found at: $ZSH_PATH"

mkdir -p "${HOME}/.termux"
ln -sf "$ZSH_PATH" "${HOME}/.termux/shell" || fail "Failed to set ~/.termux/shell"

ok "Default shell set to zsh for new Termux sessions"
warn "Close ALL Termux sessions and reopen the app to apply"

# 2) Add aliases for zsh
ZSHRC="${HOME}/.zshrc"
touch "$ZSHRC"
if ! grep -q "termux aliases" "$ZSHRC" 2>/dev/null; then
  cat >> "$ZSHRC" <<'EOF'

# ── termux aliases ──
alias cat='bat'
alias ls='eza'
EOF
  ok "Aliases added to ~/.zshrc (cat->bat, ls->eza)"
else
  ok "Aliases already present in ~/.zshrc"
fi

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

step "Backup existing config/logo/nanorc (if any)"
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
  printf "\n%s%s[AUTO]%s %s\n" "$C_PURP" "$BOLD" "$RST" "${C_PINK}Enabling autostart…${RST}"

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

  BASHRC="${HOME}/.bashrc"
  touch "$BASHRC"
  if ! grep -q "fastfetch autostart" "$BASHRC" 2>/dev/null; then
    cat >> "$BASHRC" <<'EOF'

# ── fastfetch autostart ──
[ -t 1 ] && command -v fastfetch >/dev/null 2>&1 && { clear; fastfetch; }
EOF
    ok "Added autostart to ~/.bashrc"
  else
    ok "Autostart already present in ~/.bashrc"
  fi

  warn "Restart Termux to apply autostart"
fi

printf "\n%s%s✔ DONE%s %s\n" "$C_OK" "$BOLD" "$RST" "${C_GRAY}Fastfetch: ${CFG_FILE}${RST}"
printf "%s\n" "${DIM}Nano: ${NANORC_FILE}${RST}"
printf "%s\n" "${DIM}Run: fastfetch${RST}"
