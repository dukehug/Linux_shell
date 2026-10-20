#!/usr/bin/env bash
# Install ble.sh for the current user on Ubuntu / Debian / Arch / Omarchy.
set -euo pipefail

if [[ ${1-} == --help || ${1-} == -h ]]; then
  printf 'Usage: bash install-blesh.sh\nSupports Ubuntu, Debian, Arch Linux and Omarchy.\nRun as your normal login user, without sudo.\n'
  exit 0
fi
if (( $# )); then
  printf 'Unknown argument: %s\n' "$1" >&2
  exit 1
fi
if (( EUID == 0 )); then
  printf '請用一般登入帳號執行，不要使用 sudo bash；腳本會在安裝依賴時自行使用 sudo。\n' >&2
  exit 1
fi
if [[ -f /etc/arch-release ]] && command -v pacman >/dev/null; then
  package_manager=pacman
elif [[ -f /etc/debian_version ]] && command -v apt-get >/dev/null; then
  package_manager=apt-get
else
  printf '此腳本支援 Ubuntu / Debian（apt-get）及 Arch / Omarchy（pacman）。\n' >&2
  exit 1
fi

missing=()
for dependency in git make gawk; do
  command -v "$dependency" >/dev/null || missing+=("$dependency")
done
if (( ${#missing[@]} )); then
  command -v sudo >/dev/null || {
    printf '請管理員先安裝：%s\n' "${missing[*]}" >&2
    exit 1
  }
  if [[ $package_manager == pacman ]]; then
    # Do not refresh databases alone (-Sy) or upgrade the entire host here.
    # Leave pacman's transaction confirmation enabled.
    if ! sudo pacman -S --needed "${missing[@]}"; then
      printf '依賴安裝失敗。若為套件資料庫過期，請先透過系統更新工具完成更新，再重跑腳本（Omarchy 可使用 omarchy update）。\n' >&2
      exit 1
    fi
  else
    sudo apt-get update
    sudo apt-get install -y "${missing[@]}"
  fi
fi

source_dir="$HOME/.local/src/ble.sh"
install_file="$HOME/.local/share/blesh/ble.sh"
bashrc="$HOME/.bashrc"
marker='# >>> otty-blesh managed >>>'

if [[ ! -r "$install_file" ]]; then
  if [[ -e "$source_dir" ]]; then
    printf '來源目錄已存在但尚未安裝完成：%s\n請先檢查該目錄，再手動完成安裝；腳本不會覆寫它。\n' "$source_dir" >&2
    exit 1
  fi
  mkdir -p "$(dirname "$source_dir")"
  git clone --recursive --depth 1 --shallow-submodules \
    https://github.com/akinomyoga/ble.sh.git "$source_dir"
  make -C "$source_dir" install PREFIX="$HOME/.local"
fi
[[ -r "$install_file" ]] || {
  printf '安裝未產生預期檔案：%s\n' "$install_file" >&2
  exit 1
}

# Also recognize the configuration from our earlier manual instructions.
if [[ -f "$bashrc" ]] && grep -Eq \
  '^[[:space:]]*(source|\.)[[:space:]].*(blesh/ble\.sh|ble\.sh/out/ble\.sh)' "$bashrc"; then
  printf '偵測到既有 ble.sh 載入設定，保留原設定。\n'
elif [[ -f "$bashrc" ]] && grep -Fq "$marker" "$bashrc"; then
  printf '自動載入設定已存在，無須重複加入。\n'
else
  if [[ -e "$bashrc" ]]; then
    backup="${bashrc}.backup-blesh-$(date +%Y%m%d-%H%M%S)-$$"
    cp -p "$bashrc" "$backup"
    printf '原設定備份：%s\n' "$backup"
  fi
  cat >> "$bashrc" <<'EOF'

# >>> otty-blesh managed >>>
if [[ $- == *i* && -z ${BLE_VERSION-} && -r "$HOME/.local/share/blesh/ble.sh" ]]; then
  source -- "$HOME/.local/share/blesh/ble.sh"
fi
# <<< otty-blesh managed <<<
EOF
fi

printf '\n安裝完成。請重新登入，或在目前的 Bash 執行：\n'
printf '  source ~/.local/share/blesh/ble.sh\n'
printf '\n此腳本不會更改預設 shell；若目前使用 zsh，請先執行 bash。\n'
