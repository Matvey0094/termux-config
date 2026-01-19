#!/data/data/com.termux/files/usr/bin/sh
set -eu

# ╔══════════════════════════════════════════════════════════════════════╗
# ║ fastfetch / Termux — one-shot installer                               ║
# ╚══════════════════════════════════════════════════════════════════════╝

# === GitHub repo settings (EDIT ME) ======================================
GH_USER="Matvey0094"
GH_REPO="termux-config"
GH_BRANCH="main"

RAW_BASE="https://raw.githubusercontent.com/${GH_USER}/${GH_REPO}/${GH_BRANCH}"

# Repo file layout (you keep files in repo under .config/fastfetch/)
REPO_CFG_PATH=".config/fastfetch/config.jsonc"
REPO_LOGO_PATH=".config/fastfetch/logo.txt"

CFG_DIR="${HOME}/.config/fastfetch"
CFG_FILE="${CFG_DIR}/config.jsonc"
LOGO_FILE="${CFG_DIR}/logo.txt"

PKGS="curl git nano fastfetch"

have() { command -v "$1" >/dev/null 2>&1; }

echo "[1/6] Installing required packages…"
# shellcheck disable=SC2086
pkg install -y $PKGS

echo "[2/7] Installing Inconsolata Nerd Font Mono…"

TERMUX_DIR="${HOME}/.termux"
FONT_FILE="${TERMUX_DIR}/font.ttf"
mkdir -p "$TERMUX_DIR"

REG_URL="https://raw.githubusercontent.com/ryanoasis/nerd-fonts/master/patched-fonts/Inconsolata/InconsolataNerdFontMono-Regular.ttf"

# backup existing font
if [ -f "$FONT_FILE" ]; then
  ts="$(date +%Y%m%d-%H%M%S)"
  cp -f "$FONT_FILE" "${FONT_FILE}.bak-${ts}" || true
fi

curl -fsSL "$REG_URL" -o "$FONT_FILE"

# apply (Termux)
if command -v termux-reload-settings >/dev/null 2>&1; then
  termux-reload-settings || true
fi

echo "[FONT] Done. If you don't see changes: fully restart Termux."

echo "[3/7] Setting up storage access…"
# this will ask Android permission (safe to re-run)
if have termux-setup-storage; then
  termux-setup-storage || true
fi

echo "[4/7] Preparing config directory…"
mkdir -p "$CFG_DIR"

echo "[5/7] Backing up existing files (if any)…"
ts="$(date +%Y%m%d-%H%M%S)"
[ -f "$CFG_FILE" ] && cp -f "$CFG_FILE" "${CFG_FILE}.bak-${ts}"
[ -f "$LOGO_FILE" ] && cp -f "$LOGO_FILE" "${LOGO_FILE}.bak-${ts}"

echo "[5/6] Downloading config & logo from GitHub…"
curl -fsSL "${RAW_BASE}/${REPO_CFG_PATH}" -o "$CFG_FILE"
curl -fsSL "${RAW_BASE}/${REPO_LOGO_PATH}" -o "$LOGO_FILE"

echo "[7/7] Test run…"
fastfetch || true

# ===== Autostart (AUTO=1) ===============================================
if [ "${AUTO:-0}" = "1" ]; then
  echo "[AUTO] Enabling autostart…"

  # bash
  BASHRC="${HOME}/.bashrc"
  touch "$BASHRC"
  if ! grep -q "fastfetch" "$BASHRC" 2>/dev/null; then
    {
      echo ""
      echo "# ── fastfetch autostart ──"
      echo "clear"
      echo "fastfetch"
    } >> "$BASHRC"
  fi

echo "[AUTO] Done. Restart Termux."
fi
