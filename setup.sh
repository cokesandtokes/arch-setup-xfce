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

change_shell_to_zsh() {
  echo -ne "${CYAN}Change your shell to zsh? (y/n): ${RESET}"
  read -r zsh_answer

  [[ "$zsh_answer" != "y" ]] && { info "Skipping shell change."; echo; return 0; }

  if ! command -v zsh &>/dev/null; then
    info "zsh is not installed. Installing..."
    sudo pacman -S --noconfirm zsh || { err "Failed to install zsh."; return 1; }
  else
    ok "zsh is already installed."
  fi

  local zsh_path
  zsh_path=$(command -v zsh)

  if [[ "$SHELL" == "$zsh_path" ]]; then
    ok "Your shell is already set to zsh."
  else
    info "Changing default shell to: $zsh_path"
    chsh -s "$zsh_path" && ok "Shell changed. Log out and back in for it to take effect."
  fi
  echo
}

setup_zshrc() {
  ensure_repo || return 1

  local src="$REPO_DIR/.zshrc"
  if [[ ! -f "$src" ]]; then
    err ".zshrc not found in repo."
    return 1
  fi

  backup_file "$ZSHRC_DEST"
  info "Copying .zshrc to $ZSHRC_DEST"
  cp -f "$src" "$ZSHRC_DEST"
  ok ".zshrc updated."
  echo
}

########################################
# XFCE4 Installation
########################################

install_xfce4() {
  echo -ne "${CYAN}Install full XFCE4 desktop environment? (y/n): ${RESET}"
  read -r xfce_answer

  [[ "$xfce_answer" != "y" ]] && { info "Skipping XFCE4 installation."; echo; return 0; }

  info "Installing XFCE4 (full) and essential components..."

  sudo pacman -S --noconfirm \
    xfce4 xfce4-goodies \
    lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings \
    networkmanager \
    pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber \
    gvfs gvfs-mtp thunar-archive-plugin file-roller \
    xdg-user-dirs xdg-utils \
    && ok "XFCE4 desktop installed."

  info "Enabling system services..."
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

  info "Enabling system services..."
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
    1)
      info "Starting new shell..."
      exec "${SHELL:-bash}"
      ;;
    2)
      info "Rebooting system..."
      sudo reboot
      ;;
    3)
      info "Exiting script."
      ;;
    *)
      warn "Invalid choice."
      ;;
  esac
}

########################################
# Run All
########################################

run_all() {
  install_base_packages
  setup_kitty_config
  install_microcode
  change_shell_to_zsh
  setup_zshrc
  # install_xfce4   # Uncomment if you want XFCE4 included in run-all
  start_new_shell_session
}

########################################
# Menu
########################################

show_menu() {
  while true; do
    echo -e "${BOLD}${MAGENTA}Arch Post-Install Toolkit${RESET}"
    echo -e "1) Install base packages"
    echo -e "2) Setup kitty.conf from repo"
    echo -e "3) Install CPU microcode"
    echo -e "4) Change shell to zsh"
    echo -e "5) Setup .zshrc from repo"
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
      4) change_shell_to_zsh ;;
      5) setup_zshrc ;;
      6) start_new_shell_session ;;
      7) install_xfce4 ;;
      8) install_xfce4_minimal ;;
      9) run_all ;;
      0) info "Goodbye."; exit 0 ;;
      *) warn "Invalid choice." ;;
    esac
    echo
  done
}

show_menu
