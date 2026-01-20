#!/data/data/com.termux/files/usr/bin/sh
set -eu

# ──────────────────────────────── UI / THEME ────────────────────────────────
ESC="$(printf '\033')"
RST="${ESC}[0m"
BOLD="${ESC}[1m"
DIM="${ESC}[2m"

C_PURP="${ESC}[38;5;141m"
C_PINK="${ESC}[38;5;205m"
C_CYAN="${ESC}[38;5;51m"
C_GRAY="${ESC}[38;5;245m"
C_OK="${ESC}[38;5;82m"
C_WARN="${ESC}[38;5;220m"
C_BAD="${ESC}[38;5;196m"

# tag COLOR "TEXT"
tag() {
  c="$1"; t="$2"
  # brackets + text = same color (fixes your “[ OK ]” bracket not colored)
  printf "%s[%s%s%s]%s " "$c" "$BOLD" "$t" "$c" "$RST"
}
info() { tag "$C_CYAN" "INFO"; printf "%s\n" "$*"; }
ok()   { tag "$C_OK"   " OK "; printf "%s\n" "$*"; }
warn() { tag "$C_WARN" "WARN"; printf "%s\n" "$*"; }
fail() { tag "$C_BAD"  "FAIL"; printf "%s\n" "$*"; exit 1; }

hr() { printf "%s%s%s\n" "$C_PURP" "$1" "$RST"; }

# ──────────────────────────────── SETTINGS ────────────────────────────────
GH_USER="${GH_USER:-Matvey0094}"
GH_REPO="${GH_REPO:-termux-config}"
GH_BRANCH="${GH_BRANCH:-main}"

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

ZSH_PATH="${PREFIX}/bin/zsh"
ZSHRC="${HOME}/.zshrc"

# Want packages (we will install only missing)
PKGS="curl git nano fastfetch zsh wget bat eza vivid termux-tools"

# Logs (silent install writes here)
LOG_DIR="${HOME}/.cache/termux-config"
TS="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="${LOG_DIR}/install-${TS}.log"

mkdir -p "$LOG_DIR"

have() { command -v "$1" >/dev/null 2>&1; }

# Spinner runner: runs command silently, logs full output, shows spinner
run_silent() {
  desc="$1"; shift
  # shellcheck disable=SC2120
  printf "%s" ""
  printf "%s" "" >/dev/null 2>&1 || true

  # start cmd in background
  (
    # log header
    {
      printf "\n===== %s =====\n" "$desc"
      printf "+ %s\n" "$*"
    } >>"$LOG_FILE"
    "$@" >>"$LOG_FILE" 2>&1
  ) &
  pid=$!

  spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  i=1

  printf "%s" "" >/dev/null 2>&1 || true
  while kill -0 "$pid" 2>/dev/null; do
    ch="$(printf "%s" "$spin" | cut -c "$i")"
    printf "\r%s%s%s %s%s%s" "$DIM" "$C_GRAY" "$ch" "$RST" "$DIM" "$desc…$RST"
    i=$((i + 1))
    [ "$i" -gt 10 ] && i=1
    sleep 0.08
  done

  wait "$pid" || return 1
  printf "\r%s%s✔%s %s\n" "$C_OK" "$BOLD" "$RST" "$desc"
  return 0
}

backup_if_exists() {
  f="$1"
  [ -f "$f" ] || return 0
  b="${f}.bak-${TS}"
  cp -f "$f" "$b" >>"$LOG_FILE" 2>&1 || true
  ok "Backup: $b"
}

# ──────────────────────────────── Center Logo + Left Menu ────────────────────────────────
# Needs: POSIX sh + tput (termux-tools)
cols() { tput cols 2>/dev/null || printf "80"; }

# center_print COLOR "text"
center_print() {
  c="$1"; s="$2"
  w="$(cols)"
  len="${#s}"
  pad=$(( (w - len) / 2 ))
  [ "$pad" -lt 0 ] && pad=0
  printf "%s%*s%s%s\n" "$c" "$pad" "" "$s" "$RST"
}

# Simple "gradient" across lines (pink -> orange -> yellow vibe)
G1="${ESC}[38;5;205m"  # pink
G2="${ESC}[38;5;212m"
G3="${ESC}[38;5;214m"
G4="${ESC}[38;5;220m"  # yellow

draw_logo() {
  printf "\n"
  center_print "$G1$BOLD" "███████╗██╗   ██╗███╗   ███╗██████╗ ██╗  ██╗ ██████╗ ██╗  ██╗██╗   ██╗"
  center_print "$G2$BOLD" "██╔════╝╚██╗ ██╔╝████╗ ████║██╔══██╗██║  ██║██╔═══██╗██║  ██║╚██╗ ██╔╝"
  center_print "$G3$BOLD" "███████╗ ╚████╔╝ ██╔████╔██║██████╔╝███████║██║   ██║███████║ ╚████╔╝ "
  center_print "$G4$BOLD" "╚════██║  ╚██╔╝  ██║╚██╔╝██║██╔═══╝ ██╔══██║██║   ██║██╔══██║  ╚██╔╝  "
  center_print "$G3$BOLD" "███████║   ██║   ██║ ╚═╝ ██║██║     ██║  ██║╚██████╔╝██║  ██║   ██║   "
  center_print "$G2$BOLD" "╚══════╝   ╚═╝   ╚═╝     ╚═╝╚═╝     ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝   "
  printf "\n"
}

# Menu state
# (You can map these to your DO_* vars later)
MENU_ITEMS="Backups before overwrite|System update (pkg update/upgrade)|Enable fastfetch autostart|Apply zshrc now (exec zsh -l)|Start installer"
MENU_KEYS="DO_BACKUP|DO_UPDATE|DO_AUTOSTART|DO_APPLY_NOW|START"
DO_BACKUP=1
DO_UPDATE=0
DO_AUTOSTART=0
DO_APPLY_NOW=0

CUR=0

# Helpers
get_item() { printf "%s" "$MENU_ITEMS" | awk -F'|' -v i="$1" '{print $(i+1)}'; }
get_key()  { printf "%s" "$MENU_KEYS"  | awk -F'|' -v i="$1" '{print $(i+1)}'; }
items_count() { printf "%s" "$MENU_ITEMS" | awk -F'|' '{print NF}'; }

on_off() { [ "$1" -eq 1 ] && printf "ON" || printf "OFF"; }

draw_menu() {
  n="$(items_count)"
  printf "%sChoose:%s\n" "$C_CYAN$BOLD" "$RST"

  i=0
  while [ "$i" -lt "$n" ]; do
    label="$(get_item "$i")"
    key="$(get_key "$i")"

    # Determine state text
    state=""
    case "$key" in
      DO_BACKUP)     state="$(on_off "$DO_BACKUP")" ;;
      DO_UPDATE)     state="$(on_off "$DO_UPDATE")" ;;
      DO_AUTOSTART)  state="$(on_off "$DO_AUTOSTART")" ;;
      DO_APPLY_NOW)  state="$(on_off "$DO_APPLY_NOW")" ;;
      START)         state="" ;;
    esac

    # cursor marker + colors
    if [ "$i" -eq "$CUR" ]; then
      pointer="${C_PINK}${BOLD}>${RST}"
      linec="${C_PINK}${BOLD}"
    else
      pointer=" "
      linec="$RST"
    fi

    if [ "$key" = "START" ]; then
      printf " %s %s%s%s\n" "$pointer" "$linec" "$label" "$RST"
    else
      printf " %s %s%s%s %s[%s]%s\n" "$pointer" "$linec" "$label" "$RST" "$DIM$C_GRAY" "$state" "$RST"
    fi

    i=$((i + 1))
  done

  printf "\n%s%s%s\n" "$DIM$C_GRAY" "↕ navigate • Space toggle • Enter submit • q quit" "$RST"
}

# read single key (works in Termux)
read_key() {
  oldstty="$(stty -g)"
  stty -echo -icanon time 0 min 1 2>/dev/null || true
  k="$(dd bs=1 count=1 2>/dev/null || true)"
  # if it's ESC, read 2 more bytes for arrows
  if [ "$k" = "$(printf '\033')" ]; then
    k2="$(dd bs=1 count=2 2>/dev/null || true)"
    k="$k$k2"
  fi
  stty "$oldstty" 2>/dev/null || true
  printf "%s" "$k"
}

menu_ui() {
  while :; do
    clear
    draw_logo
    draw_menu

    key="$(read_key)"

    case "$key" in
      q) return 2 ;;                           # quit
      "$(printf '\033[A')") CUR=$((CUR - 1)) ;; # up
      "$(printf '\033[B')") CUR=$((CUR + 1)) ;; # down
      " ") # toggle
        case "$(get_key "$CUR")" in
          DO_BACKUP)    DO_BACKUP=$((1-DO_BACKUP)) ;;
          DO_UPDATE)    DO_UPDATE=$((1-DO_UPDATE)) ;;
          DO_AUTOSTART) DO_AUTOSTART=$((1-DO_AUTOSTART)) ;;
          DO_APPLY_NOW) DO_APPLY_NOW=$((1-DO_APPLY_NOW)) ;;
        esac
        ;;
      "$(printf '\n')"|"\r")
        [ "$(get_key "$CUR")" = "START" ] && return 0
        ;;
    esac

    n="$(items_count)"
    [ "$CUR" -lt 0 ] && CUR=0
    [ "$CUR" -ge "$n" ] && CUR=$((n-1))
  done
}

# Run menu and map vars to your installer flags
if menu_ui; then
  : # continue script
else
  exit_code=$?
  [ "$exit_code" -eq 2 ] && exit 0
fi

# ──────────────────────────────── STEPS ────────────────────────────────
STEP=0
STEP_TOTAL=9
step() {
  STEP=$((STEP + 1))
  printf "\n%s%s[%d/%d]%s %s%s%s\n" \
    "$C_PURP" "$BOLD" "$STEP" "$STEP_TOTAL" "$RST" \
    "$C_PINK" "$1" "$RST"
}

# 1) Optional update/upgrade
step "System update (optional)"
if [ "$DO_UPDATE" -eq 1 ]; then
  info "Running pkg update/upgrade (silent)…"
  run_silent "pkg update"   pkg update -y || warn "pkg update failed (see log)"
  run_silent "pkg upgrade"  pkg upgrade -y || warn "pkg upgrade failed (see log)"
  ok "System update done"
else
  warn "System update: skipped"
fi

# 2) Install packages (only missing, silent)
step "Install required packages (only missing, silent)"
missing=""
for p in $PKGS; do
  if ! dpkg -s "$p" >/dev/null 2>&1; then
    missing="${missing} $p"
  fi
done

if [ -z "${missing# }" ]; then
  ok "All packages already installed"
else
  info "Missing:${missing}"
  run_silent "pkg install" pkg install -y $missing || fail "pkg install failed (see log: $LOG_FILE)"
  ok "Packages installed"
fi

# 3) Set zsh as default
step "Set zsh as default (Termux)"
[ -x "$ZSH_PATH" ] || fail "zsh not found at: $ZSH_PATH"
mkdir -p "$TERMUX_DIR"
# (backup optional)
[ "$DO_BACKUP" -eq 1 ] && backup_if_exists "${TERMUX_DIR}/shell"
ln -sf "$ZSH_PATH" "${TERMUX_DIR}/shell" || fail "Failed to set ${TERMUX_DIR}/shell"
ok "Default shell set to zsh for new Termux sessions"
warn "Close ALL Termux sessions and reopen the app to apply"

# 4) Configure zshrc (managed block, backup optional)
step "Configure zsh (aliases + colors) — managed block"
if [ "$DO_BACKUP" -eq 1 ]; then
  backup_if_exists "$ZSHRC"
fi
touch "$ZSHRC"

# Remove previous managed block if exists
# (works even if block is absent)
sed -i '/^# ── termux managed start ──$/,/^# ── termux managed end ──$/d' "$ZSHRC" 2>/dev/null || true

# Append fresh managed block
cat >>"$ZSHRC" <<'EOF'

# ── termux managed start ──
# aliases
command -v bat  >/dev/null 2>&1 && alias cat='bat'
command -v eza  >/dev/null 2>&1 && alias ls='eza -lah --icons --group-directories-first --git --no-time'
command -v eza  >/dev/null 2>&1 && alias la='eza -lah --icons --group-directories-first --git --time-style=long-iso'
command -v nala >/dev/null 2>&1 && alias apt='nala'

# colors
command -v vivid >/dev/null 2>&1 && export LS_COLORS="$(vivid generate zenburn)"
export EZA_COLORS="da=38;5;205:hd=38;5;141:sn=38;5;110:uu=38;5;250:gu=38;5;250"
# ── termux managed end ──
EOF

ok "Updated ~/.zshrc (managed block)"

# 5) Disable Termux welcome message
step "Disable Termux welcome message (MOTD)"
touch "${HOME}/.hushlogin"
MOTD_USR="${PREFIX}/etc/motd"
MOTD_TERMUX="${PREFIX}/etc/motd.sh"
[ -f "$MOTD_USR" ] && : > "$MOTD_USR" || true
[ -f "$MOTD_TERMUX" ] && : > "$MOTD_TERMUX" || true
ok "Welcome message disabled"

# 6) Install Nerd Font
step "Install Nerd Font (Inconsolata Mono)"
mkdir -p "$TERMUX_DIR"
[ "$DO_BACKUP" -eq 1 ] && backup_if_exists "$FONT_FILE"
run_silent "Download font" curl -fSL "$FONT_URL" -o "$FONT_FILE" || fail "Font download failed (see log)"
if have termux-reload-settings; then
  run_silent "Apply Termux settings" termux-reload-settings || true
fi
ok "Font installed to ~/.termux/font.ttf"
warn "If icons still look like squares: fully close Termux and open again"

# 7) Prepare fastfetch config directory
step "Prepare fastfetch config directory"
mkdir -p "$CFG_DIR"
ok "Dir ready: $CFG_DIR"

# 8) Backup existing config/logo/nanorc (optional)
step "Backup existing config/logo/nanorc/zshrc (optional)"
if [ "$DO_BACKUP" -eq 1 ]; then
  backup_if_exists "$CFG_FILE"
  backup_if_exists "$LOGO_FILE"
  backup_if_exists "$NANORC_FILE"
  backup_if_exists "$ZSHRC"
  ok "Backups done"
else
  warn "Backups: disabled"
fi

# 9) Download files from GitHub
step "Download config, logo, nanorc from GitHub"
CFG_URL="${RAW_BASE}/${REPO_CFG_PATH}"
LOGO_URL="${RAW_BASE}/${REPO_LOGO_PATH}"
NANORC_URL="${RAW_BASE}/${REPO_NANORC_PATH}"

info "config: $CFG_URL"
run_silent "Download config.jsonc" curl -fSL "$CFG_URL" -o "$CFG_FILE" || fail "Download failed: config.jsonc (check repo path/branch)"

info "logo:   $LOGO_URL"
run_silent "Download logo.txt" curl -fSL "$LOGO_URL" -o "$LOGO_FILE" || fail "Download failed: logo.txt (check repo path/branch)"

info "nanorc: $NANORC_URL"
run_silent "Download .nanorc" curl -fSL "$NANORC_URL" -o "$NANORC_FILE" || fail "Download failed: .nanorc (check repo path/branch)"

ok "Fastfetch + Nano config installed"

# ──────────────────────────────── AUTOSTART (optional) ─────────────────────
if [ "$DO_AUTOSTART" -eq 1 ]; then
  step "Enable fastfetch autostart (zsh)"
  if ! grep -q "fastfetch autostart" "$ZSHRC" 2>/dev/null; then
    cat >>"$ZSHRC" <<'EOF'

# ── fastfetch autostart ──
[ -t 1 ] && command -v fastfetch >/dev/null 2>&1 && { clear; fastfetch; }
EOF
    ok "Added autostart to ~/.zshrc"
  else
    ok "Autostart already present in ~/.zshrc"
  fi
else
  step "Autostart"
  warn "Autostart: skipped"
fi

# ──────────────────────────────── TEST RUN ────────────────────────────────
step "Test run (shows output)"
if have fastfetch; then
  # show output to user; still log errors
  if fastfetch --show-errors 2>>"$LOG_FILE"; then
    ok "fastfetch executed"
  else
    warn "fastfetch failed (see log: $LOG_FILE)"
  fi
else
  warn "fastfetch not found after install"
fi

printf "\n"
tag "$C_OK" "DONE"
printf "%sFastfetch:%s %s\n" "$C_GRAY" "$RST" "$CFG_FILE"
printf "%sNano:%s     %s\n" "$C_GRAY" "$RST" "$NANORC_FILE"
printf "%sZshrc:%s    %s\n" "$C_GRAY" "$RST" "$ZSHRC"
printf "%sRun:%s      fastfetch\n" "$C_GRAY" "$RST"

if [ "$DO_APPLY_NOW" -eq 1 ]; then
  warn "Switching to zsh now (exec zsh -l)…"
  exec zsh -l
else
  warn "Apply now: open a NEW Termux session or run: source ~/.zshrc"
fi
