source "$HOME/.zshenv"

HISTSIZE=10000000
SAVEHIST=$HISTSIZE
HISTDUP=erase

setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

bindkey '^p' history-search-backward
bindkey '^n' history-search-forward

DISABLE_AUTO_TITLE=true

plugins=(
	z
	tmux
	safe-paste
	colored-man-pages
	colorize
	zsh-autosuggestions
	node
    zsh-completions
    fzf-tab
    rust
    aliases
    zsh-vi-mode
)

zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'

if [ -f ~/.aliases ]; then
	. ~/.aliases
fi

export EDITOR=v
export VISUAL=v

export NVM_DIR=~/.nvm
 [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

source ~/.oh-my-zsh/oh-my-zsh.sh
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

export TERM=xterm-256color

SPACESHIP_PROMPT_ASYNC=false

if [[ "$USER" == "lorenzomaturano" ]]; then
  alias v='nvim'
else
  alias v='~/nvim.appimage'
fi

export FZF_PREVIEW_ADVANCED=true

eval "$(starship init zsh)"

export PATH=$PATH:/usr/local/go/bin

export EDITOR=~/nvim.appimage

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
