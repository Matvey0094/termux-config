#!/usr/bin/env bash
set -euo pipefail
umask 022

# termux-config - install.sh
# Main installer/configurator for this repository.
# Idempotent, scalable, safe (explicit backups), Termux-friendly.

[[ -n "${BASH_VERSION:-}" ]] || { echo "Run with bash"; exit 1; }

# ========================= ui_* =========================
ui_is_tty() { [[ -t 0 && -t 1 ]]; }
ui_have() { command -v "$1" >/dev/null 2>&1; }

ui_color_init() {
  local esc
  esc="$(printf '\033')"
  UI_RST="${esc}[0m"
  UI_BOLD="${esc}[1m"
  UI_DIM="${esc}[2m"

  UI_CYAN="${esc}[38;5;51m"
  UI_PURP="${esc}[38;5;141m"
  UI_PINK="${esc}[38;5;205m"
  UI_GRAY="${esc}[38;5;245m"
  UI_OK="${esc}[38;5;82m"
  UI_WARN="${esc}[38;5;220m"
  UI_BAD="${esc}[38;5;196m"
}

ui_tag() { local c="$1" t="$2"; printf "%s[%s%s%s]%s " "$c" "$UI_BOLD" "$t" "$c" "$UI_RST"; }
ui_info() { ui_tag "$UI_CYAN" "INFO"; printf "%s\n" "$*"; }
ui_ok()   { ui_tag "$UI_OK"   " OK "; printf "%s\n" "$*"; }
ui_warn() { ui_tag "$UI_WARN" "WARN"; printf "%s\n" "$*"; }
ui_fail() { ui_tag "$UI_BAD"  "FAIL"; printf "%s\n" "$*"; exit 1; }

ui_hr() { printf "%s%s%s\n" "$UI_PURP" "${1:-----------------------------------------}" "$UI_RST"; }

ui_detect_backend() {
  # Priority: whiptail/dialog (menus) > gum (nice prompts) > plain
  if ui_is_tty && ui_have whiptail; then UI_BACKEND="whiptail"
  elif ui_is_tty && ui_have dialog; then UI_BACKEND="dialog"
  elif ui_is_tty && ui_have gum; then UI_BACKEND="gum"
  else UI_BACKEND="plain"
  fi
}

ui_select_one() {
  # ui_select_one "Title" default option1 option2 ...
  local title="$1" def="$2"; shift 2
  local -a opts=("$@")
  local choice=""

  case "$UI_BACKEND" in
    whiptail)
      local -a menu=() o
      for o in "${opts[@]}"; do menu+=("$o" ""); done
      choice="$(whiptail --title "termux-config" --menu "$title" 18 70 10 "${menu[@]}" 3>&1 1>&2 2>&3)" || return 1
      ;;
    dialog)
      local -a menu=() o
      for o in "${opts[@]}"; do menu+=("$o" ""); done
      choice="$(dialog --clear --stdout --title "termux-config" --menu "$title" 18 70 10 "${menu[@]}")" || return 1
      ;;
    gum)
      choice="$(printf "%s\n" "${opts[@]}" | gum choose --header "$title" --selected "$def")" || return 1
      ;;
    plain|*)
      printf "%s\n" "$title"
      local i=1 o
      for o in "${opts[@]}"; do
        if [[ "$o" == "$def" ]]; then
          printf "  %2d) [default] %s\n" "$i" "$o"
        else
          printf "  %2d) %s\n" "$i" "$o"
        fi
        ((i++))
      done
      printf "Select [default: %s]: " "$def"
      local ans
      IFS= read -r ans || true
      if [[ -z "${ans:-}" ]]; then choice="$def"
      elif [[ "$ans" =~ ^[0-9]+$ ]] && (( ans>=1 && ans<=${#opts[@]} )); then choice="${opts[ans-1]}"
      else choice="$ans"
      fi
      ;;
  esac

  printf "%s" "$choice"
}

ui_confirm() {
  local prompt="$1"
  case "$UI_BACKEND" in
    whiptail) whiptail --title "termux-config" --yesno "$prompt" 10 70 ;;
    dialog)   dialog --clear --stdout --title "termux-config" --yesno "$prompt" 10 70 ;;
    gum)      gum confirm "$prompt" ;;
    plain|*)
      printf "%s [y/N]: " "$prompt"
      local ans
      IFS= read -r ans || true
      [[ "${ans:-}" =~ ^([yY]|yes|YES)$ ]]
      ;;
  esac
}

# Multi-select with defaults via UI_MULTI_DEFAULT[tag]=1
ui_select_multi_plain() {
  local title="$1"; shift
  local -a tags=("$@")
  local -A state=()
  local t
  for t in "${tags[@]}"; do state["$t"]="${UI_MULTI_DEFAULT[$t]:-0}"; done

  while :; do
    ui_hr
    printf "%s\n" "$title"
    local i=1
    for t in "${tags[@]}"; do
      local mark="[ ]"
      [[ "${state[$t]}" == "1" ]] && mark="[*]"
      printf "  %2d) %s %s\n" "$i" "$mark" "$t"
      ((i++))
    done
    printf "\nToggle numbers (e.g. 1 4 7), Enter to continue: "
    local line
    IFS= read -r line || true
    [[ -z "${line// }" ]] && break
    local n
    for n in $line; do
      [[ "$n" =~ ^[0-9]+$ ]] || continue
      (( n>=1 && n<=${#tags[@]} )) || continue
      t="${tags[n-1]}"
      state["$t"]=$((1 - state["$t"]))
    done
  done

  local -a selected=()
  for t in "${tags[@]}"; do [[ "${state[$t]}" == "1" ]] && selected+=("$t"); done
  printf "%s" "${selected[*]:-}"
}

ui_select_multi() {
  local title="$1"; shift
  local -a tags=("$@")
  local -a selected=()

  case "$UI_BACKEND" in
    whiptail)
      local -a items=() t
      for t in "${tags[@]}"; do
        local st="OFF"
        [[ "${UI_MULTI_DEFAULT[$t]:-0}" == "1" ]] && st="ON"
        items+=("$t" "" "$st")
      done
      local out
      out="$(whiptail --title "termux-config" --checklist "$title" 20 78 12 "${items[@]}" 3>&1 1>&2 2>&3)" || return 1
      out="${out//\"/}"
      # shellcheck disable=SC2206
      selected=($out)
      ;;
    dialog)
      local -a items=() t
      for t in "${tags[@]}"; do
        local st="off"
        [[ "${UI_MULTI_DEFAULT[$t]:-0}" == "1" ]] && st="on"
        items+=("$t" "" "$st")
      done
      local out
      out="$(dialog --clear --stdout --title "termux-config" --checklist "$title" 20 78 12 "${items[@]}")" || return 1
      out="${out//\"/}"
      # shellcheck disable=SC2206
      selected=($out)
      ;;
    gum)
      # gum: filter with no limit -> returns multiple lines
      local out
      out="$(printf "%s\n" "${tags[@]}" | gum filter --no-limit --placeholder "$title (type to filter, Enter to select many)")" || true
      mapfile -t selected < <(printf "%s\n" "$out" | sed '/^$/d')
      ;;
    plain|*)
      local out
      out="$(ui_select_multi_plain "$title" "${tags[@]}")"
      # shellcheck disable=SC2206
      selected=($out)
      ;;
  esac

  printf "%s" "${selected[*]:-}"
}

# ========================= repo/paths =========================
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
TERMUX_DIR="${HOME}/.termux"
FASTFETCH_DIR="${XDG_CONFIG_HOME}/fastfetch"
CACHE_DIR="${HOME}/.cache/termux-config"
mkdir -p "$CACHE_DIR"

repo_try_writable_dir() {
  local d="$1"
  mkdir -p "$d" 2>/dev/null && [[ -w "$d" ]] && { printf "%s" "$d"; return 0; }
  return 1
}

LOGS_DIR=""
BACKUPS_DIR=""
if LOGS_DIR="$(repo_try_writable_dir "${REPO_ROOT}/logs")"; then :; else LOGS_DIR="$(repo_try_writable_dir "${CACHE_DIR}/logs")"; fi
if BACKUPS_DIR="$(repo_try_writable_dir "${REPO_ROOT}/backups")"; then :; else BACKUPS_DIR="$(repo_try_writable_dir "${CACHE_DIR}/backups")"; fi

RUN_TS="$(date +%F_%H-%M-%S)"
LOG_FILE="${LOGS_DIR}/install-$(date +%F).log"

repo_pick_first_existing() {
  local base="$1"; shift
  local p
  for p in "$@"; do
    [[ -f "${base}/${p}" ]] && { printf "%s" "${base}/${p}"; return 0; }
  done
  return 1
}

# ========================= fastfetch_* =========================
fastfetch_set_sources_by_device() {
  local device="$1"
  if [[ "$device" == "mobile" ]]; then
    SRC_FASTFETCH_CFG="$(repo_pick_first_existing "$REPO_ROOT" ".config/fastfetch/config.phone.jsonc" "config.phone.jsonc")"
    SRC_FASTFETCH_LOGO="$(repo_pick_first_existing "$REPO_ROOT" ".config/fastfetch/logo.phone.txt" "logo.phone.txt")"
  else
    SRC_FASTFETCH_CFG="$(repo_pick_first_existing "$REPO_ROOT" ".config/fastfetch/config.jsonc" "config.jsonc")"
    SRC_FASTFETCH_LOGO="$(repo_pick_first_existing "$REPO_ROOT" ".config/fastfetch/logo.txt" "logo.txt")"
  fi
}

# ========================= copy_* =========================
copy_install_file() {
  local src="$1" dst="$2" mode="${3:-644}"
  [[ -f "$src" ]] || ui_fail "Source file missing: $src"
  mkdir -p "$(dirname -- "$dst")"
  if ui_have install; then
    install -m "$mode" "$src" "$dst"
  else
    cp -f "$src" "$dst"
    chmod "$mode" "$dst" 2>/dev/null || true
  fi
}

# ========================= backup_* =========================
BACKUP_SESSION_DIR=""

backup_rel_path() {
  local p="$1"
  if [[ "$p" == "$HOME/"* ]]; then
    printf "home/%s" "${p#"$HOME/"}"
  elif [[ -n "${PREFIX:-}" && "$p" == "$PREFIX/"* ]]; then
    printf "prefix/%s" "${p#"$PREFIX/"}"
  else
    printf "root/%s" "${p#/}"
  fi
}

backup_init_session() {
  BACKUP_SESSION_DIR="${BACKUPS_DIR}/${RUN_TS}"
  mkdir -p "$BACKUP_SESSION_DIR"
}

backup_file() {
  local src="$1"
  [[ -e "$src" ]] || return 0
  local rel dst
  rel="$(backup_rel_path "$src")"
  dst="${BACKUP_SESSION_DIR}/${rel}"
  mkdir -p "$(dirname -- "$dst")"
  cp -a "$src" "$dst"
  ui_ok "Backup: $rel"
}

# ========================= pkg_* =========================
pkg_is_termux() { [[ -n "${PREFIX:-}" ]] && [[ -x "${PREFIX}/bin/pkg" ]]; }

pkg_is_installed() {
  local p="$1"
  if ui_have dpkg; then
    dpkg -s "$p" >/dev/null 2>&1
  elif ui_have pkg; then
    pkg list-installed "$p" >/dev/null 2>&1
  else
    return 1
  fi
}

pkg_update_upgrade() {
  pkg_is_termux || ui_fail "This step requires Termux (pkg)."
  ui_info "pkg update"
  pkg update -y
  ui_info "pkg upgrade"
  pkg upgrade -y
}

pkg_install_missing() {
  pkg_is_termux || ui_fail "This step requires Termux (pkg)."
  local -a want=("$@") missing=()
  local p
  for p in "${want[@]}"; do pkg_is_installed "$p" || missing+=("$p"); done
  if ((${#missing[@]}==0)); then
    ui_ok "Packages: already installed"
    return 0
  fi
  ui_info "Installing: ${missing[*]}"
  pkg install -y "${missing[@]}"
  ui_ok "Packages installed"
}

# ========================= fonts_* (Nerd Fonts) =========================
FONTS_CACHE_DIR="${CACHE_DIR}/cache"
mkdir -p "$FONTS_CACHE_DIR"
FONTS_LIST_FILE="${FONTS_CACHE_DIR}/nerd-fonts.list"
FONTS_LIST_TTL_SEC=$((7*24*60*60))

_fonts_stat_mtime() {
  # portable-ish: GNU stat in Termux supports -c %Y. If not, return 0.
  stat -c %Y "$1" 2>/dev/null || echo 0
}

fonts_fetch_list() {
  local now mtime age
  now="$(date +%s)"
  if [[ -f "$FONTS_LIST_FILE" ]]; then
    mtime="$(_fonts_stat_mtime "$FONTS_LIST_FILE")"
    age=$((now - mtime))
    if (( age < FONTS_LIST_TTL_SEC )); then
      cat "$FONTS_LIST_FILE"
      return 0
    fi
  fi

  ui_info "Fetching Nerd Fonts list (GitHub API)..."
  local api="https://api.github.com/repos/ryanoasis/nerd-fonts/contents/patched-fonts?ref=master"
  local tmp
  tmp="$(mktemp)"
  if ! curl -fsSL "$api" -o "$tmp"; then
    rm -f "$tmp"
    ui_warn "GitHub API unavailable; using cached list if present."
    [[ -f "$FONTS_LIST_FILE" ]] && { cat "$FONTS_LIST_FILE"; return 0; }
    return 1
  fi

  awk '
    /"name"[[:space:]]*:/ {
      gsub(/.*"name"[[:space:]]*:[[:space:]]*"/,"");
      gsub(/".*/,"");
      name=$0
    }
    /"type"[[:space:]]*:[[:space:]]*"dir"/ {
      if (name != "") print name
      name=""
    }
  ' "$tmp" | sort -u | tee "$FONTS_LIST_FILE" >/dev/null

  rm -f "$tmp"
  cat "$FONTS_LIST_FILE"
}

fonts_pick_family() {
  local -a list=()
  mapfile -t list < <(fonts_fetch_list)
  ((${#list[@]}==0)) && ui_fail "Could not load Nerd Fonts list."

  if ui_have fzf && ui_is_tty; then
    printf "%s\n" "${list[@]}" | fzf --prompt="Nerd Font family > "
    return 0
  fi
  if ui_have gum && ui_is_tty; then
    printf "%s\n" "${list[@]}" | gum filter --placeholder="Nerd Font family (type to filter)..."
    return 0
  fi

  # plain: filter then choose
  local q
  while :; do
    printf "Search Nerd Fonts (empty -> first 30): "
    IFS= read -r q || true
    local -a filtered=()
    if [[ -z "${q:-}" ]]; then
      filtered=("${list[@]:0:30}")
    else
      mapfile -t filtered < <(printf "%s\n" "${list[@]}" | grep -i -- "$q" | head -n 50 || true)
    fi
    ((${#filtered[@]}==0)) && { ui_warn "No matches."; continue; }

    ui_hr
    local i=1 f
    for f in "${filtered[@]}"; do printf "  %2d) %s\n" "$i" "$f"; ((i++)); done
    printf "Pick number (empty -> re-search): "
    local n
    IFS= read -r n || true
    [[ -z "${n:-}" ]] && continue
    if [[ "$n" =~ ^[0-9]+$ ]] && (( n>=1 && n<=${#filtered[@]} )); then
      printf "%s" "${filtered[n-1]}"
      return 0
    fi
    ui_warn "Invalid selection."
  done
}

fonts_sparse_fetch_family_dir() {
  local family="$1"
  local tmp
  tmp="$(mktemp -d)"
  (
    cd "$tmp"
    git clone --quiet --depth 1 --filter=blob:none --sparse https://github.com/ryanoasis/nerd-fonts.git nerd-fonts >/dev/null 2>&1 \
      || git clone --quiet --depth 1 --sparse https://github.com/ryanoasis/nerd-fonts.git nerd-fonts >/dev/null 2>&1
    cd nerd-fonts
    git sparse-checkout set "patched-fonts/$family" >/dev/null 2>&1
  )
  printf "%s" "$tmp/nerd-fonts/patched-fonts/$family"
}

fonts_pick_font_file() {
  local family_dir="$1"
  local -a files=()
  mapfile -t files < <(find "$family_dir" -type f \( -iname '*.ttf' -o -iname '*.otf' \) | sort)
  ((${#files[@]}==0)) && ui_fail "No .ttf/.otf found in: $family_dir"

  local preferred=""
  preferred="$(printf "%s\n" "${files[@]}" | grep -E -m1 'NerdFontMono-.*Regular\.(ttf|otf)$' || true)"
  [[ -z "$preferred" ]] && preferred="$(printf "%s\n" "${files[@]}" | grep -E -m1 'NerdFont-.*Regular\.(ttf|otf)$' || true)"
  [[ -z "$preferred" ]] && preferred="${files[0]}"

  if ui_have fzf && ui_is_tty; then
    (printf "%s\n" "${files[@]}" | sed "s|^$family_dir/||") \
      | fzf --prompt="Pick font file > " --header="Default: $(basename "$preferred")" \
      | awk -v base="$family_dir" '{print base "/" $0}'
    return 0
  fi
  if ui_have gum && ui_is_tty; then
    (printf "%s\n" "${files[@]}" | sed "s|^$family_dir/||") \
      | gum filter --placeholder="Pick font file (default: $(basename "$preferred"))" \
      | awk -v base="$family_dir" '{print base "/" $0}'
    return 0
  fi

  printf "Default font file: %s\n" "$(basename "$preferred")"
  if ui_confirm "Use default font file?"; then
    printf "%s" "$preferred"
    return 0
  fi

  ui_hr
  local i=1 f
  for f in "${files[@]:0:50}"; do printf "  %2d) %s\n" "$i" "$(basename "$f")"; ((i++)); done
  printf "Pick number (1-%d): " "$((i-1))"
  local n
  IFS= read -r n || true
  if [[ "$n" =~ ^[0-9]+$ ]] && (( n>=1 && n<i )); then
    printf "%s" "${files[n-1]}"
    return 0
  fi

  ui_warn "Invalid selection; using default."
  printf "%s" "$preferred"
}

fonts_install_to_termux() {
  local font_file="$1"
  mkdir -p "$TERMUX_DIR"
  local dst="${TERMUX_DIR}/font.ttf"

  if [[ -f "$dst" ]] && cmp -s "$font_file" "$dst"; then
    ui_ok "Font already up-to-date: $dst"
    return 0
  fi

  copy_install_file "$font_file" "$dst" 644
  ui_ok "Installed font: $dst"

  if ui_have termux-reload-settings; then
    termux-reload-settings >/dev/null 2>&1 || true
    ui_ok "Applied Termux settings (termux-reload-settings)"
  else
    ui_warn "termux-reload-settings not found (restart Termux to apply font)"
  fi
}

# ========================= tables (scalable) =========================
declare -a PKG_ORDER=(
  curl git wget nano zsh fastfetch
  starship bat eza vivid
  fzf ripgrep jq python
  openssh tmux
  dialog gum
)
declare -A PKG_DEFAULT=(
  [curl]=1 [git]=1 [wget]=1 [nano]=1 [zsh]=1 [fastfetch]=1
  [starship]=1 [bat]=1 [eza]=1 [vivid]=1
  [fzf]=0 [ripgrep]=0 [jq]=0 [python]=0 [openssh]=0 [tmux]=0
  [dialog]=0 [gum]=0
)

# Copy table: key -> dst, sources resolved below (supports canonical + flat layout)
declare -a COPY_KEYS=( zshrc aliases starship nanorc eza_theme fastfetch_cfg fastfetch_logo )
declare -A COPY_DST=(
  [zshrc]="${HOME}/.zshrc"
  [aliases]="${XDG_CONFIG_HOME}/zsh/aliases.zsh"
  [starship]="${XDG_CONFIG_HOME}/starship.toml"
  [nanorc]="${HOME}/.nanorc"
  [eza_theme]="${XDG_CONFIG_HOME}/eza/theme.yml"
  [fastfetch_cfg]="${FASTFETCH_DIR}/config.jsonc"
  [fastfetch_logo]="${FASTFETCH_DIR}/logo.txt"
)
declare -A COPY_SRC=()

copy_resolve_sources() {
  COPY_SRC[zshrc]="$(repo_pick_first_existing "$REPO_ROOT" ".zshrc" "zshrc")"
  COPY_SRC[aliases]="$(repo_pick_first_existing "$REPO_ROOT" ".config/zsh/aliases.zsh" "aliases.zsh")"
  COPY_SRC[starship]="$(repo_pick_first_existing "$REPO_ROOT" ".config/starship.toml" "starship.toml")"
  COPY_SRC[nanorc]="$(repo_pick_first_existing "$REPO_ROOT" ".nanorc" "nanorc" ".config/.nanorc")"
  COPY_SRC[eza_theme]="$(repo_pick_first_existing "$REPO_ROOT" ".config/eza/theme.yml" "theme.yml")"
  COPY_SRC[fastfetch_cfg]="${SRC_FASTFETCH_CFG:-}"
  COPY_SRC[fastfetch_logo]="${SRC_FASTFETCH_LOGO:-}"
}

# Backup menu candidates (only existing are shown)
declare -a BACKUP_KEYS_ALL=( zshrc aliases starship nanorc eza_theme fastfetch_cfg fastfetch_logo termux_font termux_shell )
declare -A BACKUP_DESC=(
  [zshrc]="$HOME/.zshrc"
  [aliases]="$XDG_CONFIG_HOME/zsh/aliases.zsh"
  [starship]="$XDG_CONFIG_HOME/starship.toml"
  [nanorc]="$HOME/.nanorc"
  [eza_theme]="$XDG_CONFIG_HOME/eza/theme.yml"
  [fastfetch_cfg]="$FASTFETCH_DIR/config.jsonc"
  [fastfetch_logo]="$FASTFETCH_DIR/logo.txt"
  [termux_font]="$TERMUX_DIR/font.ttf"
  [termux_shell]="$TERMUX_DIR/shell"
)

backup_path_by_key() {
  local k="$1"
  case "$k" in
    termux_font)  printf "%s" "${TERMUX_DIR}/font.ttf" ;;
    termux_shell) printf "%s" "${TERMUX_DIR}/shell" ;;
    *)            printf "%s" "${COPY_DST[$k]}" ;;
  esac
}

backup_existing_keys() {
  local -a keys=()
  local k p
  for k in "${BACKUP_KEYS_ALL[@]}"; do
    p="$(backup_path_by_key "$k")"
    [[ -e "$p" ]] && keys+=("$k")
  done
  printf "%s" "${keys[*]:-}"
}

# ========================= state/options =========================
DEVICE_TYPE="${DEVICE_TYPE:-tablet}"     # tablet|mobile
DO_UPDATE="${DO_UPDATE:-0}"
DO_SET_ZSH_DEFAULT="${DO_SET_ZSH_DEFAULT:-1}"
DO_DISABLE_MOTD="${DO_DISABLE_MOTD:-1}"
DO_INSTALL_FONT="${DO_INSTALL_FONT:-0}"
DO_TEST_FASTFETCH="${DO_TEST_FASTFETCH:-1}"

FONT_FAMILY="${FONT_FAMILY:-}"
FONT_PICK_MODE="now"  # now|after

SELECTED_PKGS=()
declare -A BACKUP_SELECTED=()

PLAN_PKGS_MISSING=()
PLAN_COPY_KEYS=()
PLAN_BACKUP_PATHS=()
PLAN_NOTES=()

# ========================= plan =========================
plan_build() {
  PLAN_PKGS_MISSING=()
  PLAN_COPY_KEYS=()
  PLAN_BACKUP_PATHS=()
  PLAN_NOTES=()

  local p
  for p in "${SELECTED_PKGS[@]}"; do pkg_is_installed "$p" || PLAN_PKGS_MISSING+=("$p"); done

  local k src dst
  for k in "${COPY_KEYS[@]}"; do
    src="${COPY_SRC[$k]:-}"
    dst="${COPY_DST[$k]:-}"
    if [[ -z "$src" || ! -f "$src" ]]; then
      PLAN_NOTES+=("Missing source for '$k' (skipped)")
      continue
    fi
    if [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
      continue
    fi
    PLAN_COPY_KEYS+=("$k")
    if [[ "${BACKUP_SELECTED[$k]:-0}" == "1" ]] && [[ -e "$dst" ]]; then
      PLAN_BACKUP_PATHS+=("$dst")
    fi
  done

  if [[ "$DO_SET_ZSH_DEFAULT" == "1" ]]; then
    local shell_path="${TERMUX_DIR}/shell"
    local target="${PREFIX:-/data/data/com.termux/files/usr}/bin/zsh"
    if [[ -L "$shell_path" ]] && [[ "$(readlink "$shell_path")" == "$target" ]]; then
      :
    else
      [[ "${BACKUP_SELECTED[termux_shell]:-0}" == "1" ]] && [[ -e "$shell_path" ]] && PLAN_BACKUP_PATHS+=("$shell_path")
      PLAN_NOTES+=("Will set default shell to zsh (Termux)")
    fi
  fi

  if [[ "$DO_INSTALL_FONT" == "1" ]]; then
    [[ "${BACKUP_SELECTED[termux_font]:-0}" == "1" ]] && [[ -e "${TERMUX_DIR}/font.ttf" ]] && PLAN_BACKUP_PATHS+=("${TERMUX_DIR}/font.ttf")
    if [[ "$FONT_PICK_MODE" == "after" ]]; then
      PLAN_NOTES+=("Nerd Font selection will run after package install (fzf/gum).")
    else
      [[ -n "${FONT_FAMILY:-}" ]] && PLAN_NOTES+=("Nerd Font family: $FONT_FAMILY")
    fi
  fi
}

# ========================= execution =========================
copy_apply_all() {
  local k src dst
  for k in "${COPY_KEYS[@]}"; do
    src="${COPY_SRC[$k]:-}"
    dst="${COPY_DST[$k]:-}"

    [[ -n "$src" && -f "$src" ]] || { ui_warn "Skip (missing src): $k"; continue; }

    if [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
      ui_ok "Up-to-date: $dst"
      continue
    fi

    if [[ "${BACKUP_SELECTED[$k]:-0}" == "1" ]] && [[ -e "$dst" ]]; then
      backup_file "$dst"
    fi

    copy_install_file "$src" "$dst" 644
    ui_ok "Installed: $dst"
  done
}

termux_set_default_shell_zsh() {
  [[ "$DO_SET_ZSH_DEFAULT" == "1" ]] || return 0
  pkg_is_termux || { ui_warn "Not Termux; skip default shell."; return 0; }

  local zsh_path="${PREFIX}/bin/zsh"
  [[ -x "$zsh_path" ]] || ui_fail "zsh not found: $zsh_path"

  mkdir -p "$TERMUX_DIR"
  local shell_file="${TERMUX_DIR}/shell"

  if [[ -L "$shell_file" ]] && [[ "$(readlink "$shell_file")" == "$zsh_path" ]]; then
    ui_ok "Default shell already set: $shell_file -> $zsh_path"
    return 0
  fi

  [[ "${BACKUP_SELECTED[termux_shell]:-0}" == "1" ]] && [[ -e "$shell_file" ]] && backup_file "$shell_file"
  ln -sf "$zsh_path" "$shell_file"
  ui_ok "Default shell set: $shell_file -> $zsh_path"
  ui_warn "Close ALL Termux sessions and reopen Termux to apply shell change."
}

termux_disable_motd() {
  [[ "$DO_DISABLE_MOTD" == "1" ]] || return 0
  pkg_is_termux || { ui_warn "Not Termux; skip MOTD changes."; return 0; }

  touch "${HOME}/.hushlogin"
  local motd="${PREFIX}/etc/motd"
  local motd_sh="${PREFIX}/etc/motd.sh"
  [[ -f "$motd" ]] && : > "$motd" || true
  [[ -f "$motd_sh" ]] && : > "$motd_sh" || true
  ui_ok "Termux welcome message disabled (.hushlogin + empty motd)"
}

fastfetch_test_run() {
  [[ "$DO_TEST_FASTFETCH" == "1" ]] || return 0
  if ui_have fastfetch; then
    ui_hr
    ui_info "fastfetch test run:"
    fastfetch --show-errors || ui_warn "fastfetch returned non-zero"
  else
    ui_warn "fastfetch not found; skip test."
  fi
}

# ========================= UI flow =========================
ui_show_banner() {
  ui_hr
  printf "%s%s termux-config installer %s\n" "$UI_PINK" "$UI_BOLD" "$UI_RST"
  printf "%sRepo:%s    %s\n" "$UI_GRAY" "$UI_RST" "$REPO_ROOT"
  printf "%sLogs:%s    %s\n" "$UI_GRAY" "$UI_RST" "$LOGS_DIR"
  printf "%sBackups:%s %s\n" "$UI_GRAY" "$UI_RST" "$BACKUPS_DIR"
  ui_hr
}

ui_collect_device() {
  DEVICE_TYPE="$(ui_select_one "Select device type (affects fastfetch config)" "$DEVICE_TYPE" tablet mobile)" || ui_fail "Canceled."
}

ui_collect_packages() {
  declare -gA UI_MULTI_DEFAULT=()
  local p
  for p in "${PKG_ORDER[@]}"; do UI_MULTI_DEFAULT["$p"]="${PKG_DEFAULT[$p]:-0}"; done

  local out
  out="$(ui_select_multi "Select packages to install (only missing will be installed)" "${PKG_ORDER[@]}")" || ui_fail "Canceled."
  # shellcheck disable=SC2206
  SELECTED_PKGS=(${out:-})
  ((${#SELECTED_PKGS[@]}==0)) && ui_warn "No packages selected; some steps may be skipped."
}

ui_collect_backups() {
  local keys_str out
  keys_str="$(backup_existing_keys)"
  # shellcheck disable=SC2206
  local -a existing=(${keys_str:-})
  if ((${#existing[@]}==0)); then
    ui_ok "No existing files to backup."
    return 0
  fi

  declare -gA UI_MULTI_DEFAULT=()
  local k
  for k in "${existing[@]}"; do UI_MULTI_DEFAULT["$k"]=1; done

  out="$(ui_select_multi "Select what to backup (only existing files are shown)" "${existing[@]}")" || ui_fail "Canceled."
  out="${out:-}"

  for k in "${existing[@]}"; do BACKUP_SELECTED["$k"]=0; done
  # shellcheck disable=SC2206
  local -a sel=($out)
  for k in "${sel[@]}"; do BACKUP_SELECTED["$k"]=1; done
}

ui_collect_toggles() {
  ui_hr
  ui_info "Options:"
  ui_confirm "Run system update (pkg update/upgrade)?" && DO_UPDATE=1 || DO_UPDATE=0
  ui_confirm "Set zsh as default shell (~/.termux/shell)?" && DO_SET_ZSH_DEFAULT=1 || DO_SET_ZSH_DEFAULT=0
  ui_confirm "Disable Termux welcome message (MOTD + .hushlogin)?" && DO_DISABLE_MOTD=1 || DO_DISABLE_MOTD=0
  ui_confirm "Install Nerd Font to ~/.termux/font.ttf?" && DO_INSTALL_FONT=1 || DO_INSTALL_FONT=0
  ui_confirm "Run fastfetch test at the end?" && DO_TEST_FASTFETCH=1 || DO_TEST_FASTFETCH=0
}

ui_collect_font_choice_if_needed() {
  [[ "$DO_INSTALL_FONT" == "1" ]] || return 0

  # If no fzf/gum now, but user selected them for install, defer choice until after pkg install.
  if ! ui_have fzf && ! ui_have gum; then
    local p want=0
    for p in "${SELECTED_PKGS[@]}"; do [[ "$p" == "fzf" || "$p" == "gum" ]] && want=1; done
    if (( want == 1 )); then
      FONT_PICK_MODE="after"
      return 0
    fi
  fi

  FONT_FAMILY="$(fonts_pick_family)"
  ui_ok "Selected Nerd Font family: $FONT_FAMILY"
}

ui_print_plan() {
  ui_hr
  printf "%s%s INSTALL PLAN %s\n" "$UI_PINK" "$UI_BOLD" "$UI_RST"
  ui_hr

  printf "%sDevice:%s %s\n" "$UI_GRAY" "$UI_RST" "$DEVICE_TYPE"
  printf "%sUpdate:%s %s\n" "$UI_GRAY" "$UI_RST" "$([[ "$DO_UPDATE" == "1" ]] && echo ON || echo OFF)"
  printf "%sZsh default:%s %s\n" "$UI_GRAY" "$UI_RST" "$([[ "$DO_SET_ZSH_DEFAULT" == "1" ]] && echo ON || echo OFF)"
  printf "%sDisable MOTD:%s %s\n" "$UI_GRAY" "$UI_RST" "$([[ "$DO_DISABLE_MOTD" == "1" ]] && echo ON || echo OFF)"
  printf "%sInstall Nerd Font:%s %s\n" "$UI_GRAY" "$UI_RST" "$([[ "$DO_INSTALL_FONT" == "1" ]] && echo ON || echo OFF)"
  printf "%sTest fastfetch:%s %s\n" "$UI_GRAY" "$UI_RST" "$([[ "$DO_TEST_FASTFETCH" == "1" ]] && echo ON || echo OFF)"
  ui_hr

  printf "%sPackages selected:%s %s\n" "$UI_GRAY" "$UI_RST" "${SELECTED_PKGS[*]:-(none)}"
  printf "%sPackages to install:%s %s\n" "$UI_GRAY" "$UI_RST" "${PLAN_PKGS_MISSING[*]:-(none)}"
  ui_hr

  if ((${#PLAN_COPY_KEYS[@]}==0)); then
    ui_ok "Configs: everything up-to-date"
  else
    ui_info "Configs to install/update:"
    local k
    for k in "${PLAN_COPY_KEYS[@]}"; do
      printf "  - %s -> %s\n" "${COPY_SRC[$k]}" "${COPY_DST[$k]}"
    done
  fi

  if ((${#PLAN_BACKUP_PATHS[@]}==0)); then
    ui_ok "Backups: none"
  else
    ui_info "Backups to create:"
    local p
    for p in "${PLAN_BACKUP_PATHS[@]}"; do printf "  - %s\n" "$p"; done
    printf "  => %s/%s/\n" "$BACKUPS_DIR" "$RUN_TS"
  fi

  if ((${#PLAN_NOTES[@]})); then
    ui_hr
    ui_info "Notes:"
    local n
    for n in "${PLAN_NOTES[@]}"; do printf "  - %s\n" "$n"; done
  fi

  ui_hr
  printf "%sLog:%s %s\n" "$UI_GRAY" "$UI_RST" "$LOG_FILE"
  ui_hr
}

# ========================= main =========================
main() {
  ui_color_init
  ui_detect_backend
  ui_show_banner

  ui_collect_device
  fastfetch_set_sources_by_device "$DEVICE_TYPE"
  copy_resolve_sources

  ui_collect_packages
  ui_collect_backups
  ui_collect_toggles
  ui_collect_font_choice_if_needed

  plan_build
  ui_print_plan

  if ! ui_confirm "Proceed with installation?"; then
    ui_warn "Canceled."
    exit 0
  fi

  mkdir -p "$(dirname -- "$LOG_FILE")"
  {
    printf "\n===== RUN %s =====\n" "$RUN_TS"
    printf "Repo: %s\n" "$REPO_ROOT"
  } >>"$LOG_FILE"
  exec > >(tee -a "$LOG_FILE") 2>&1

  ui_info "Logging to: $LOG_FILE"
  backup_init_session

  if [[ "$DO_UPDATE" == "1" ]]; then pkg_update_upgrade; else ui_ok "System update skipped"; fi
  if ((${#SELECTED_PKGS[@]})); then pkg_install_missing "${SELECTED_PKGS[@]}"; else ui_warn "No packages selected; skipping pkg install."; fi

  if [[ "$DO_INSTALL_FONT" == "1" && "$FONT_PICK_MODE" == "after" ]]; then
    FONT_FAMILY="$(fonts_pick_family)"
    ui_ok "Selected Nerd Font family: $FONT_FAMILY"
  fi

  termux_set_default_shell_zsh
  termux_disable_motd

  ui_hr
  ui_info "Installing configs..."
  copy_apply_all

  if [[ "$DO_INSTALL_FONT" == "1" ]]; then
    ui_hr
    ui_info "Installing Nerd Font..."
    [[ -n "${FONT_FAMILY:-}" ]] || ui_fail "Font family not selected."

    local_family_dir="$(fonts_sparse_fetch_family_dir "$FONT_FAMILY")"
    font_file="$(fonts_pick_font_file "$local_family_dir")"

    [[ "${BACKUP_SELECTED[termux_font]:-0}" == "1" ]] && [[ -e "${TERMUX_DIR}/font.ttf" ]] && backup_file "${TERMUX_DIR}/font.ttf"
    fonts_install_to_termux "$font_file"

    # cleanup temp clone (two levels up from patched-fonts/<family>)
    rm -rf "$(dirname -- "$(dirname -- "$local_family_dir")")" 2>/dev/null || true
  else
    ui_ok "Font install skipped"
  fi

  fastfetch_test_run

  ui_hr
  ui_tag "$UI_OK" "DONE"
  printf "  Fastfetch: %s\n" "${FASTFETCH_DIR}/config.jsonc"
  printf "  Zshrc:     %s\n" "${HOME}/.zshrc"
  printf "  Backups:   %s/%s/\n" "$BACKUPS_DIR" "$RUN_TS"
  printf "  Logs:      %s\n" "$LOG_FILE"
  ui_warn "If shell/font changes don't apply: fully close Termux and open again."
}

main "$@"
