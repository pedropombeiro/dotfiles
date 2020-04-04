# Skip all this for non-interactive shells
[[ -z "$PS1" ]] && return

[ -f ~/.shell/options.sh ] && source ~/.shell/options.sh;

[ -f ~/.shell/exports.sh ] && source ~/.shell/exports.sh;

# Which plugins would you like to load?
# Standard plugins can be found in ~/.oh-my-zsh/plugins/*
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git git-extras brew docker dirhistory debian web-search zsh-autosuggestions zsh-syntax-highlighting history-substring-search)

[ -f "$ZSH/oh-my-zsh.sh" ] && source $ZSH/oh-my-zsh.sh
[ -f ~/.shell/aliases.sh ] && source ~/.shell/aliases.sh;

[ -f ~/.shell/custom.sh ] && source ~/.shell/custom.sh;
