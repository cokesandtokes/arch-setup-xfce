# arch-setup-xfce

A streamlined, menu‑driven post‑install script designed to automate the most common setup tasks after installing Arch Linux. This toolkit handles package installation, shell configuration, microcode setup, dotfile deployment, and more — all with colorized output, safety checks, and automatic backups.

✨ Features
✔ Base Package Installation
Installs a curated set of essential tools for a modern Arch environment:

nano, git, kitty, chromium

zsh, zsh-autosuggestions, zsh-syntax-highlighting

starship, fd, bat, exa, ripgrep

zram-generator

These packages provide a fast, comfortable, and productive terminal experience.

✔ Automatic Microcode Detection & Installation
The script detects your CPU vendor:

Intel → installs intel-ucode

AMD → installs amd-ucode

If microcode is installed already, it skips it safely.
After installation, the script automatically rebuilds GRUB:

Code
grub-mkconfig -o /boot/grub/grub.cfg
✔ Zsh Shell Setup
You can optionally switch your default shell to zsh.
The script:

Installs zsh if missing

Changes your login shell

Notifies you if it’s already set

✔ Dotfile Deployment
The toolkit automatically clones (or updates) your GitHub repo:

Code
https://github.com/Der3l1ct/arch-configs
Then it safely deploys:

.zshrc → ~/.zshrc

kitty.conf → ~/.config/kitty/kitty.conf

Before overwriting anything, the script creates timestamped backups:

Code
.zshrc.bak-YYYYMMDD-HHMMSS
kitty.conf.bak-YYYYMMDD-HHMMSS
✔ Menu‑Driven Interface
Instead of forcing everything at once, the script provides a clean menu:

Install base packages

Install microcode

Configure kitty

Configure zsh

Deploy dotfiles

Run everything

Start a new shell

Reboot

This makes the tool flexible for both fresh installs and incremental updates.

✔ Colorized Output
Readable, friendly, and easy to follow.
Errors, warnings, and confirmations are clearly highlighted.

✔ End‑of‑Script Options
When the script finishes, you can choose to:

Start a new terminal session (zsh or bash)

Reboot the system

Exit normally

📦 Requirements
Arch Linux or an Arch‑based distro

Internet connection (for cloning the repo)

GRUB bootloader (for microcode rebuild step)

🚀 Usage
Clone the repo:

bash
git clone https://github.com/Der3l1ct/arch-configs
cd arch-configs
Make the script executable:

bash
chmod +x arch-toolkit.sh
Run it:

bash
./arch-toolkit.sh
🛡 Safety Features
Automatic backups of existing configs

Checks before overwriting files

Detects installed packages

Detects current shell

Graceful handling of missing files

No destructive operations without confirmation
