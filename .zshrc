# Speed
DISABLE_AUTO_UPDATE="true"
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000

# Options
setopt autocd
setopt correct
setopt interactivecomments
setopt histignorealldups
setopt sharehistory
setopt incappendhistory

# Completion
autoload -Uz compinit
compinit -d ~/.cache/zsh/zshcompdump
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# Keybinds
bindkey -e
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^R' history-incremental-search-backward

# Plugins
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Aliases
alias ll='ls -lh'
alias la='ls -a'
alias grep='grep --color=auto'
alias df='df -h'
alias free='free -h'
alias cat='bat'

# Starship
eval "$(starship init zsh)"