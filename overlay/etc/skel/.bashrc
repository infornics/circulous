# ~/.bashrc for Circulous Live Shell

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# History configuration
HISTCONTROL=ignoreboth
HISTSIZE=1000
HISTFILESIZE=2000

# Window size adjustment
shopt -s checkwinsize

# Colored prompt for Circulous
if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
    PS1='\[\033[01;32m\]\u@circulous\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='\u@circulous:\w\$ '
fi

# Aliases
alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

# Circulous Welcome Banner
echo -e "\033[1;36mWelcome to Circulous Live Environment!\033[0m"
echo -e "Type \033[1;32msudo calamares\033[0m to start system installation."
echo ""
