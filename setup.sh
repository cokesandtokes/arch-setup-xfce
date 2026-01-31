#!/bin/bash

########################################
# Colors
########################################
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
MAGENTA="\e[35m"
CYAN="\e[36m"
BOLD="\e[1m"
RESET="\e[0m"

info()  { echo -e "${BLUE}[INFO]${RESET} $1"; }
ok()    { echo -e "${GREEN}[OK]${RESET} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${RESET} $1"; }
err()   { echo -e "${RED}[ERR]${RESET} $1"; }

########################################
# Config
########################################
REPO_URL="https://github.com/cokesandtokes/arch-setup-xfce"
REPO_DIR="$HOME/arch-setup-xfce"
KITTY_DIR="$HOME/.config/kitty"
ZSHRC_DEST="$HOME/.zshrc"
KITTY_DEST="$KITTY_DIR/kitty.conf"

timestamp() {
  date +"%Y%m%d-%H%M%S"
}

backup_file() {
  local file="$1"
  if [[ -f "$file" ]]; then
    local bak="${file}.bak-$(timestamp)"
    cp -f "$file" "$bak"
    warn "Existing $(basename "$file") backed up to $(basename "$bak")"
  fi
}

ensure_repo() {
  if [[ ! -d "$REPO_DIR" ]]; then
    info "Cloning repository: $REPO_URL"
    git clone "$REPO_URL" "$REPO_DIR" || { err "Failed to clone repo."; return 1; }
  else
    info "Repository exists. Pulling latest changes..."
    git -C "$REPO_DIR" pull || { err "Failed to pull latest changes."; return 1; }
  fi
}

########################################
# GitHub Search + Clone
########################################

search_and_clone_repo() {
  echo -ne "${CYAN}Enter GitHub search term: ${RESET}"
  read -r term

  [[ -z "$term" ]] && { warn "Search term cannot be empty."; return; }

  info "Searching GitHub for '$term'..."

  mapfile -t results < <(
    curl -s "https://api.github.com/search/repositories?q=${term}&per_page=10" \
    | jq -r '.items[] | "\(.full_name) | ⭐ \(.stargazers_count)"'
  )

  if [[ ${#results[@]} -eq 0 ]]; then
    err "No repositories found."
    return
  fi

  echo -e "${MAGENTA}Select a repository to clone:${RESET}"
  local i=1
  for repo in "${results[@]}"; do
    echo -e "$i) $repo"
    ((i++))
  done

  echo -ne "${YELLOW}Choice: ${RESET}"
  read -r choice

  if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#results[@]} )); then
    warn "Invalid selection."
    return
  fi

  local selected_repo
  selected_repo=$(echo "${results[$((choice-1))]}" | cut -d'|' -f1 | xargs)

  echo -ne "${CYAN}Clone into which directory? (default: \$HOME): ${RESET}"
  read -r dest
  [[ -z "$dest" ]] && dest="$HOME"

  info "Cloning https://github.com/$selected_repo into $dest"
  git clone "https://github.com/$selected_repo" "$dest/$(basename "$selected_repo")" \
    && ok "Repository cloned successfully." \
    || err "Clone failed."
}

########################################
# Tasks
########################################

install_base_packages() {
  info "Installing base packages..."
  sudo pacman -S --noconfirm \
    nano git kitty chromium zsh \
    zsh-autosuggestions zsh-syntax-highlighting \
    starship fd bat exa ripgrep zram-generator \
    && ok "Base packages installed."
  echo
}

setup_kitty_config() {
  ensure_repo || return 1

  mkdir -p "$KITTY_DIR"

  local src="$REPO_DIR/kitty.conf"
  if [[ ! -f "$src" ]]; then
    err "kitty.conf not found in repo."
    return 1
  fi

  backup_file "$KITTY_DEST"
  info "Copying kitty.conf to $KITTY_DEST"
  cp -f "$src" "$KITTY_DEST"
  ok "kitty.conf updated."
  echo
}

install_microcode() {
  echo -ne "${CYAN}Install CPU microcode? (y/n): ${RESET}"
  read -r microcode_answer

  [[ "$microcode_answer" != "y" ]] && { info "Skipping microcode installation."; echo; return 0; }

  local cpu_vendor
  cpu_vendor=$(lscpu | awk -F: '/Vendor ID/ {gsub(/^[ \t]+/, "", $2); print $2}')

  local pkg=""
  case "$cpu_vendor" in
    GenuineIntel) pkg="intel-ucode" ;;
    AuthenticAMD) pkg="amd-ucode" ;;
    *) err "Unknown CPU vendor: $cpu_vendor"; return 1 ;;
  esac

  info "Detected CPU vendor: $cpu_vendor"
  info "Microcode package: $pkg"

  if pacman -Qi "$pkg" &>/dev/null; then
    ok "Microcode package '$pkg' is already installed."
  else
    info "Installing $pkg..."
    sudo pacman -S --noconfirm "$pkg" && ok "$pkg installed."
  fi

  echo
  info "Rebuilding GRUB configuration..."
  sudo grub-mkconfig -o /boot/grub/grub.cfg && ok "GRUB successfully rebuilt."
  echo
}

########################################
# Unified Zsh Setup
########################################

setup_zsh_all() {
  ensure_repo || return 1

  info "Installing zsh + plugins + applying .zshrc + switching shell"

  if ! command -v zsh &>/dev/null; then
    sudo pacman -S --noconfirm zsh || { err "Failed to install zsh."; return 1; }
  fi

  local src="$REPO_DIR/.zshrc"
  if [[ ! -f "$src" ]]; then
    err ".zshrc not found in repo."
    return 1
  fi

  backup_file "$ZSHRC_DEST"
  cp -f "$src" "$ZSHRC_DEST"
  ok ".zshrc applied."

  local zsh_path
  zsh_path=$(command -v zsh)

  if [[ "$SHELL" != "$zsh_path" ]]; then
    chsh -s "$zsh_path" && ok "Default shell changed to zsh."
  else
    ok "Shell already set to zsh."
  fi

  echo
}

########################################
# XFCE4 Installation
########################################

install_xfce4() {
  echo -ne "${CYAN}Install full XFCE4 desktop environment? (y/n): ${RESET}"
  read -r xfce_answer

  [[ "$xfce_answer" != "y" ]] && { info "Skipping XFCE4 installation."; echo; return 0; }

  info "Installing XFCE4 (full)..."

  sudo pacman -S --noconfirm \
    xfce4 xfce4-goodies \
    lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings \
    networkmanager \
    pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber \
    gvfs gvfs-mtp thunar-archive-plugin file-roller \
    xdg-user-dirs xdg-utils \
    && ok "XFCE4 desktop installed."

  sudo systemctl enable lightdm
  sudo systemctl enable NetworkManager
  ok "Services enabled."
  echo
}

install_xfce4_minimal() {
  echo -ne "${CYAN}Install minimal XFCE4 environment? (y/n): ${RESET}"
  read -r xfce_min_answer

  [[ "$xfce_min_answer" != "y" ]] && { info "Skipping minimal XFCE4 installation."; echo; return 0; }

  info "Installing minimal XFCE4..."

  sudo pacman -S --noconfirm \
    xfce4 \
    lightdm lightdm-gtk-greeter \
    networkmanager \
    pipewire pipewire-alsa pipewire-pulse wireplumber \
    xdg-user-dirs xdg-utils \
    && ok "Minimal XFCE4 installed."

  sudo systemctl enable lightdm
  sudo systemctl enable NetworkManager
  ok "Services enabled."
  echo
}

########################################
# Shell Session
########################################

start_new_shell_session() {
  echo -e "${CYAN}Choose an option:${RESET}"
  echo -e "1) Start a new terminal session"
  echo -e "2) Reboot the system"
  echo -e "3) Exit"
  echo -ne "${YELLOW}Selection: ${RESET}"
  read -r choice

  case "$choice" in
    1) exec "${SHELL:-bash}" ;;
    2) sudo reboot ;;
    3) info "Exiting." ;;
    *) warn "Invalid choice." ;;
  esac
}

########################################
# Run All
########################################

run_all() {
  install_base_packages
  setup_kitty_config
  install_microcode
  setup_zsh_all
  start_new_shell_session
}

########################################
# Menu
########################################

show_menu() {
  while true; do
    echo -e "${BOLD}${MAGENTA}Arch Post-Install Toolkit${RESET}"
    echo -e "1) Install base packages"
    echo -e "2) Setup kitty.conf"
    echo -e "3) Install CPU microcode"
    echo -e "4) Full Zsh setup (install + config + shell switch)"
    echo -e "5) GitHub search + clone"
    echo -e "6) Start new shell session"
    echo -e "7) Install XFCE4 Desktop (full)"
    echo -e "8) Install XFCE4 Desktop (minimal)"
    echo -e "9) Run ALL tasks"
    echo -e "0) Exit"
    echo -ne "${YELLOW}Choose an option: ${RESET}"
    read -r choice

    case "$choice" in
      1) install_base_packages ;;
      2) setup_kitty_config ;;
      3) install_microcode ;;
      4) setup_zsh_all ;;
      5) search_and_clone_repo ;;
      6) start_new_shell_session ;;
      7) install_xfce4 ;;
      8) install_xfce4_minimal ;;
      9) run_all ;;
      0) exit 0 ;;
      *) warn "Invalid choice." ;;
    esac
    echo
  done
}

show_menu