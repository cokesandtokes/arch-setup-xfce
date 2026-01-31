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
DOTFILES_DIR="$HOME/dotfiles"

timestamp() { date +"%Y%m%d-%H%M%S"; }

backup_file() {
  local file="$1"
  if [[ -f "$file" ]]; then
    local bak="${file}.bak-$(timestamp)"
    cp -f "$file" "$bak"
    warn "Backed up $(basename "$file") → $(basename "$bak")"
  fi
}

ensure_repo() {
  if [[ ! -d "$REPO_DIR" ]]; then
    info "Cloning repository: $REPO_URL"
    git clone "$REPO_URL" "$REPO_DIR" || { err "Failed to clone repo."; return 1; }
  else
    info "Updating repository..."
    git -C "$REPO_DIR" pull || { err "Failed to update repo."; return 1; }
  fi
}

########################################
# Install yay (AUR helper)
########################################

install_yay() {
  if command -v yay &>/dev/null; then
    ok "yay already installed."
    return
  fi

  info "Installing yay..."
  sudo pacman -S --noconfirm --needed base-devel git

  git clone https://aur.archlinux.org/yay.git /tmp/yay
  cd /tmp/yay || return
  makepkg -si --noconfirm

  ok "yay installed."
}

########################################
# GitHub Search + Clone
########################################

search_and_clone_repo() {
  if ! command -v jq &>/dev/null; then
    info "Installing jq..."
    sudo pacman -S --noconfirm jq
  fi

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

  echo -e "${MAGENTA}Select a repository:${RESET}"
  local i=1
  for repo in "${results[@]}"; do
    echo "$i) $repo"
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

  echo -ne "${CYAN}Clone into directory (default: \$HOME): ${RESET}"
  read -r dest
  [[ -z "$dest" ]] && dest="$HOME"

  git clone "https://github.com/$selected_repo" "$dest/$(basename "$selected_repo")" \
    && ok "Repository cloned." \
    || err "Clone failed."
}

########################################
# System Setup (base packages + yay + cleanup)
########################################

system_setup() {
  info "Installing base packages..."
  sudo pacman -S --noconfirm \
    nano git kitty chromium zsh \
    zsh-autosuggestions zsh-syntax-highlighting \
    starship fd bat exa ripgrep zram-generator jq

  install_yay

  sudo pacman -Rns --noconfirm $(pacman -Qtdq 2>/dev/null) 2>/dev/null
  sudo pacman -Scc --noconfirm

  ok "System setup complete."
}

########################################
# Shell & Terminal Setup
########################################

shell_terminal_setup() {
  ensure_repo || return 1

  # Zsh
  sudo pacman -S --noconfirm zsh
  backup_file "$ZSHRC_DEST"
  cp -f "$REPO_DIR/.zshrc" "$ZSHRC_DEST"
  chsh -s "$(command -v zsh)"

  # Kitty
  mkdir -p "$KITTY_DIR"
  backup_file "$KITTY_DEST"
  cp -f "$REPO_DIR/kitty.conf" "$KITTY_DEST"

  ok "Shell + terminal setup complete."
}

########################################
# Microcode
########################################

install_microcode() {
  echo -ne "${CYAN}Install CPU microcode? (y/n): ${RESET}"
  read -r ans
  [[ "$ans" != "y" ]] && return

  local vendor pkg
  vendor=$(lscpu | awk -F: '/Vendor ID/ {gsub(/^[ \t]+/, "", $2); print $2}')

  case "$vendor" in
    GenuineIntel) pkg="intel-ucode" ;;
    AuthenticAMD) pkg="amd-ucode" ;;
    *) err "Unknown CPU vendor."; return ;;
  esac

  sudo pacman -S --noconfirm "$pkg"
  sudo grub-mkconfig -o /boot/grub/grub.cfg
  ok "Microcode installed."
}

########################################
# Dotfile Manager
########################################

setup_dotfiles() {
  echo -ne "${CYAN}Dotfiles directory (default: ~/dotfiles): ${RESET}"
  read -r dir
  [[ -z "$dir" ]] && dir="$DOTFILES_DIR"

  [[ ! -d "$dir" ]] && { err "Directory not found."; return; }

  for file in "$dir"/.*; do
    [[ "$(basename "$file")" =~ ^(\.|\.\.|\.git)$ ]] && continue
    backup_file "$HOME/$(basename "$file")"
    ln -sf "$file" "$HOME/"
    ok "Linked $(basename "$file")"
  done
}

########################################
# System Hardening
########################################

system_hardening() {
  info "Applying hardening..."

  sudo sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
  sudo systemctl restart sshd

  echo "kernel.kptr_restrict=2" | sudo tee /etc/sysctl.d/99-kptr.conf >/dev/null
  sudo sysctl --system >/dev/null

  ok "Hardening applied."
}

########################################
# XFCE Installation
########################################

install_xfce4() {
  sudo pacman -S --noconfirm \
    xfce4 xfce4-goodies \
    lightdm lightdm-gtk-greeter \
    networkmanager \
    pipewire pipewire-alsa pipewire-pulse wireplumber \
    gvfs thunar-archive-plugin file-roller \
    xdg-user-dirs xdg-utils

  sudo systemctl enable lightdm
  sudo systemctl enable NetworkManager
  ok "XFCE installed."
}

install_xfce4_minimal() {
  sudo pacman -S --noconfirm \
    xfce4 \
    lightdm lightdm-gtk-greeter \
    networkmanager \
    pipewire pipewire-alsa pipewire-pulse wireplumber \
    xdg-user-dirs xdg-utils

  sudo systemctl enable lightdm
  sudo systemctl enable NetworkManager
  ok "Minimal XFCE installed."
}

########################################
# Run All
########################################

run_all() {
  system_setup
  shell_terminal_setup
  install_microcode
  system_hardening
  ok "All tasks complete."
}

########################################
# Menu
########################################

show_menu() {
  while true; do
    echo -e "${BOLD}${MAGENTA}Arch Post-Install Toolkit${RESET}"
    echo "1) System Setup (base packages + yay + cleanup)"
    echo "2) Shell & Terminal Setup (zsh + kitty)"
    echo "3) Install CPU Microcode"
    echo "4) GitHub Search + Clone"
    echo "5) Dotfile Manager"
    echo "6) System Hardening"
    echo "7) Install XFCE4 (full)"
    echo "8) Install XFCE4 (minimal)"
    echo "9) Run ALL Tasks"
    echo "10) Start New Shell Session / Exit"
    echo -ne "${YELLOW}Choose: ${RESET}"
    read -r choice

    case "$choice" in
      1) system_setup ;;
      2) shell_terminal_setup ;;
      3) install_microcode ;;
      4) search_and_clone_repo ;;
      5) setup_dotfiles ;;
      6) system_hardening ;;
      7) install_xfce4 ;;
      8) install_xfce4_minimal ;;
      9) run_all ;;
      10) start_new_shell_session ;;
      0) exit 0 ;;
      *) warn "Invalid choice." ;;
    esac
    echo
  done
}

start_new_shell_session() {
  echo -e "${CYAN}1) New shell\n2) Reboot\n3) Exit${RESET}"
  read -r c
  case "$c" in
    1) exec "${SHELL:-bash}" ;;
    2) sudo reboot ;;
    3) return ;;
  esac
}

show_menu