source "$HOME/.zshenv"

HISTSIZE=10000000
SAVEHIST=10000000

ZSH_THEME="spaceship"
DISABLE_AUTO_TITLE=true

plugins=(
	z
	tmux
	safe-paste
	colored-man-pages
	colorize
	zsh-autosuggestions
	node
)

if [ -f ~/.aliases ]; then
	. ~/.aliases
fi

export EDITOR=v
export VISUAL=v

export NVM_DIR=~/.nvm
 [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

source ~/.oh-my-zsh/oh-my-zsh.sh
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

export PATH="$PATH:$HOME/.rvm/bin"
export TERM=xterm-256color

SPACESHIP_PROMPT_ASYNC=false