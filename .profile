# Initialize my "xenv" language runtime managers if installed
if command -v rbenv &>/dev/null; then
  eval "$(rbenv init -)"
fi
if command -v nodenv &>/dev/null; then
  eval "$(nodenv init -)"
fi
if command -v pyenv &>/dev/null; then
  eval "$(pyenv init -)"
fi

# Additional PATH configuration

## My own scripts
PATH="$HOME/bin:$PATH"

## Ruby binstubs (note: this can be exploited at untrusted working directories!)
PATH="$PATH:./bin"

# Shell-specific settings

if [[ "$SHELL" == *zsh ]]; then
  # Nothing to see here
  true
elif [[ "$SHELL" == *bash ]]; then
  ## Bash settings

  ### stickier .bash_history
  shopt -s histappend

  ### Set up tab-completion (requires `brew install bash-completion`)
  if [ -f $(brew --prefix)/etc/bash_completion ]; then
    source $(brew --prefix)/etc/bash_completion
  fi
fi

# Other Customization

## Editor registration for git, etc
export EDITOR="vim"
export LC_CTYPE="en_US.UTF-8"

## Reference the location of iCloud Drive
export ICLOUD_DRIVE="$HOME/icloud-drive"

## Source ENV variables
source "$ICLOUD_DRIVE/dotfiles/.env"

## Set fzf to use rg like so for ctrl-t in shell:
export FZF_DEFAULT_COMMAND='rg --files --no-ignore --hidden --follow --glob "!.git/*"'

## Increase limit of open file descriptors because watch processes
ulimit -n 10000

## Set a few aliases
alias be="bundle exec"
alias gc="git commit"

## load custom PS1 prompt
source $HOME/bin/ps1


export PATH="$HOME/.cargo/bin:$PATH"
