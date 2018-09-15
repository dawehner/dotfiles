# early, fast invocation of tmux
# - only if tmux is installed
# - not in linux ttys
# - no nested tmux sessions
if [[ -n ${commands[tmux]} && "$TERM" != "linux" && -z "$TMUX" ]]; then
  if [[ -n "$SSH_AUTH_SOCK" ]]  then
    tmux set-environment -g SSH_AUTH_SOCK "$SSH_AUTH_SOCK" 2>/dev/null
  fi

  tmux -u attach-session || tmux -u
fi

if [[ -z "$NIX_PATH" ]]; then
  if [[ -d $HOME/git/nixpkgs ]]; then
    export NIX_PATH="nixpkgs=$HOME/git/nixpkgs"
  fi
  if [[ -d $HOME/git/nixos-configuration ]]; then
    export NIX_PATH="$NIX_PATH:nixos-config=$HOME/git/nixos-configuration/configuration.nix:nixpkgs-overlays=$HOME/git/nixos-configuration/overlays"
  fi
fi
if [ -e /home/joerg/.nix-profile/etc/profile.d/nix.sh ]; then
  . /home/joerg/.nix-profile/etc/profile.d/nix.sh;
fi
if [[ -S /nix/var/nix/daemon-socket/socket ]]; then
  export NIX_REMOTE=daemon
fi

function faketty {
  script -qfc "$(printf "%q " "$@")";
}

function string_hash() {
  local hashstr=$1
  local hashsize=$2
  local hashval=52

  for i in {1..${#hashstr}}; do;
    local thischar=$hashstr[$i]
    hashval=$(( $hashval + $((#thischar)) ))
  done

  # Avoid 0 as that's black
  hashsize=$(( $hashsize - 1 ))
  hashval=$(( $hashval % $hashsize ))
  hashval=$(( $hashval + 1 ))

  echo $hashval
}

if [[ "$__host__" != "$HOST" ]]; then
  tmux set -g status-bg colour$(string_hash $HOST 255)
  export __host__=$HOST
fi

##  Helpers
# xalias - only supposed to be used with simple aliases.
xalias() {
  local key val com
  if (( ${#argv} == 0 )) ; then
    printf 'xalias(): Missing argument.\n'
    return 1
  fi
  if (( ${#argv} > 1 )) ; then
    printf 'xalias(): Too many arguments %s\n' "${#argv}"
    return 1
  fi

  key="${1%%\=*}" ;  val="${1#*\=}"

  words=(${(z)val})
  cmd=${words[1]}

  [[ -n ${commands[$cmd]}  ]] && alias -- "${key}=${val}"
  return 0
}
# xhashd - check for directory, then create hash -d
xhashd() {
  local key val com
  if (( ${#argv} == 0 )) ; then
    printf 'xhashd(): Missing argument.\n'
    return 1
  fi
  if (( ${#argv} > 1 )) ; then
    printf 'xhashd(): Too many arguments %s\n' "${#argv}"
    return 1
  fi

  key="${1%%\=*}";  val="${1#*\=}"
  [[ -d ${val} ]] && hash -d -- "${key}=${val}"
  return 0
}
upfind() {
  local previous=
  local current=$PWD

  if [[ $# -ne 1 ]];then
    echo "$0 FILE_NAME"
    return 1
  fi

  while [[ -d $current && $current != $previous ]]; do
    local target_path=$current/$1
    if [[ -f $target_path ]]; then
      echo $target_path
      return 0
    else
      previous=$current
      current=$current:h
    fi
  done
  return 1
}
clone(){
  [ $# -eq 0 ] && echo "clone <GIT_CLONE_URL>" && return 1

  cd `mktemp -d`
  git clone --depth=1 "$1"
}
rust-doc(){
  xdg-open "$(nix-build '<nixpkgs>' -A rustc.doc --no-out-link)/share/doc/rust/html/index.html"
}
boostrap-home-manager() {
  if [ ! -d $HOME/git/nixpkgs ]; then
    git clone https://github.com/Mic92/nixpkgs/ ~/git/nixpkgs
    (cd ~/git/nixpkgs && git remote add upstream https://github.com/NixOS/nixpkgs.git)
  fi
  nix-shell https://github.com/rycee/home-manager/archive/master.tar.gz -A install
  home-manager switch
}

## Options
setopt auto_name_dirs
setopt transient_rprompt
setopt pushd_ignore_dups
setopt no_beep
setopt auto_cd
setopt correct
setopt multios
setopt cdablevarS
setopt extended_glob
autoload -U url-quote-magic
zle -N self-insert url-quote-magic
autoload -U zmv
bindkey "^[m" copy-prev-shell-word
HISTFILE=$HOME/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
DIRSTACKSIZE=30
export WORDCHARS='*?_-.[]~=&;!#$%^(){}<>' # Like default, but without / -- ^W must be useful in paths, like it is in vim, bash, tcsh
setopt hist_ignore_dups
setopt hist_reduce_blanks
setopt share_history
setopt append_history
setopt hist_verify
setopt inc_append_history
setopt extended_history
setopt hist_expire_dups_first
setopt hist_ignore_space
setopt long_list_jobs
# emacs keys
bindkey -e
# open current line in editor
autoload edit-command-line
zle -N edit-command-line
bindkey '^X^e' edit-command-line

## Completion
autoload colors; colors;
autoload -U compinit
fpath=($* "/usr/local/share/zsh/site-functions" $fpath)
fignore=(.DS_Store $fignore)
compinit -i
compdef mcd=cd
zmodload -i zsh/complist
setopt complete_in_word
unsetopt always_to_end
[[ -f ~/.ssh/known_hosts ]] && hosts=(`awk '{print $1}' ~/.ssh/known_hosts | tr ',' '\n' `)
[[ -f ~/.ssh/config ]] && hosts=($hosts `grep '^Host' ~/.ssh/config | sed s/Host\ // | egrep -v '^\*$'`)
zstyle ':completion:*' insert-tab pending
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
highlights='${PREFIX:+=(#bi)($PREFIX:t)(?)*==31=1;32}':${(s.:.)LS_COLORS}}
highlights2='=(#bi) #([0-9]#) #([^ ]#) #([^ ]#) ##*($PREFIX)*==1;31=1;35=1;33=1;32=}'
zstyle -e ':completion:*' list-colors 'if [[ $words[1] != kill && $words[1] != strace ]]; then reply=( "'$highlights'" ); else reply=( "'$highlights2'" ); fi'
unset highlights
zstyle ':completion:*' squeeze-slashes true
zstyle ':completion:*' expand 'yes'
zstyle ':completion:*:match:*' original only
zstyle ':completion:*:approximate:*' max-errors 1 numeric
zstyle ':completion:*:hosts' hosts $hosts
zstyle ':completion::complete:*' use-cache 1
zstyle ':completion::complete:*' cache-path ./cache/
zstyle ':completion:*:cd:*' ignore-parents parent pwd
zstyle ':completion:*:kill:*:processes' list-colors '=(#b) #([0-9]#) ([0-9a-z-]#)*=01;34=0=01'
zstyle ':completion:*:*:*:processes' command "ps -u `whoami` -o pid,user,comm -w -w"
[ -d "$HOME/.zsh-completions/src" ] && fpath=($HOME/.zsh-completions $fpath)

## Prompt
export PURE_GIT_UNTRACKED_DIRTY=0
source $HOME/.zsh-pure/async.zsh
source $HOME/.zsh-pure/pure.zsh
# non-zero exit code in right prompt
RPS1='%(?.%F{magenta}.%F{red}(%?%) %F{magenta})'

## Aliases
# Basic commands
alias zcat='zcat -f'
alias dd='dd status=progress'
xalias ag='ag --color --smart-case --literal --pager=less'

# System tools
xalias top='htop'
alias free='free -m'
alias vuser="fuser -v "
alias du='du -hc'
alias df='df -hT'
xalias df='dfc'
# File management
if [[ -n ${commands[exa]} ]]; then
  alias ls='exa'
  alias tree='exa -T'
elif [[ $OSTYPE == freebsd* ]]; then
  alias ls='ls -G'
else
  alias ls='ls --color=auto --classify --human-readable'
fi
alias sl=ls
alias tempdir='cd `TMPDIR=/tmp mktemp -d`;'
alias rm='rm -rv'
alias cp='nocorrect cp -rpv'
alias cpv="rsync -pogr --progress"
alias ln="nocorrect ln"
alias mv='nocorrect mv -v'
alias mkdir='nocorrect mkdir -p'
xalias locate='locate --existing --follow --basename --ignore-case'
alias ip='ip -c'
xalias objdump='objdump -M intel'
# noglobs
alias wget='noglob wget'
alias curl='noglob curl'
if [[ -n ${commands[hub]} ]]; then
  alias git='noglob hub'
else
  alias git='noglob git'
fi
alias rake='noglob rake'
# Root
# fallback if sudo is not yet installed
alias su='su - '
alias sync='sudo sync'
alias updatedb='sudo updatedb'
alias sless='sudo less'
alias stail='sudo tail'
xalias ctl='sudo systemctl'
alias json_escape="ruby -e \"require 'json'; puts(File.open(ARGV[0]).read.to_json) if ARGV[0]\""
alias gdb='gdb --quiet --args'
# Editors
[[ -n ${commands[vi]} ]] && alias vi=vim
xalias vim="nvim"
xalias ee="emacs -nw"
# Package management
if [[ -f /etc/debian_version ]] ; then
  alias apt-get='sudo apt-get'
  alias apt-secure='sudo apt-secure'
  alias apt-file='sudo apt-file'
  alias aptitude='sudo aptitude'
  alias dpkg='sudo dpkg'
elif [[ -f /etc/arch-release ]] ; then
  # if colored version is avaible
  xalias pacman='pacman-color'
  xalias y=yaourt
  # run as root
  alias pacman='sudo pacman'
  alias abs='sudo abs'
  # pacman-contrib stuff
  xalias pacdiff='sudo pacdiff -l'
  xalias pacscripts='sudo pacscripts'
  xalias pactree='pactree -c'
  xhashd yaourtbuild=/var/abs/local/yaourtbuild
  function owns() { /usr/bin/pacman -Qo $(which $1)}
  alias pacunlock="sudo rm /var/lib/pacman/db.lck"
elif [[ -f /etc/gentoo-release ]] ; then
  alias emerge='sudo emerge'
  xalias eix-sync='sudo eix-sync -C --quiet'
fi

if [[ -n ${commands[nix]} ]]; then
  n() {
    NIX_RUN_ARGS="$@${NIX_RUN_ARGS+ }${NIX_RUN_ARGS}" nix run "$@" -f '<nixpkgs>' -c zsh
  }
fi

# fancy file selector for vim
vim-fzf() {
  # prefilter non-interactive followed by selection
  local file=$(fzf --exact --multi -f "$@" | fzf --exact --sync)
  [ -z "$file" ] && return
  # put effective command into the history
  print -s vim "$file"
  vim "$file"
}

# fancy file selector for vim + ag
vim-ag() {
  local preview=$HOME/.homesick/repos/dotfiles/zsh/vim-ag/preview.sh
  local file=$( ag "$@" | fzf --ansi --select-1 --exact --preview "$preview '$@' {} " )
  [ -z "$file" ] && return
  setopt shwordsplit
  local args
  IFS=':' args=($file)
  unsetopt shwordsplit
  print -s vim +${args[2]} ${args[1]}
  vim +${args[2]} ${args[1]}
}

psgrep() {
  ps aux | grep "$@"
}

# Dir Hashes
xhashd awesome=~/.config/awesome/
xhashd vicious=~/.config/awesome/vicious
xhashd mic92=~/go/src/github.com/Mic92
xhashd git=~/git
xhashd hase=~/git/angr/hase
# Global aliases
alias -g G='| grep -'
alias -g L='| less'
alias -g C='| xclip'
alias -g H='| head'
alias -g N='&>/dev/null'
alias -g SL='| sort | less'
alias -g S='| sort -u'
alias -g T='| tail'
alias -g W='| wc -l'
# Miscellanious
# a fresh zsh, please.
alias fzsh='PS1="zsh%# " zsh -f'
# generic aliases
# diff format like git
xalias diff='diff -Naur --strip-trailing-cr'
[ -z "${commands[ping6]}" ] && alias ping6="ping -6"
alias gping="ping google.com"
alias gping6="ping6 google.com"
alias ghost="host -v google.com 8.8.8.8"
alias gcurl="curl -v google.com"
ping_gw(){ ip route | awk '/default/ {printf "-I %s %s", $5, $3; exit}' | xargs --no-run-if-empty --max-args 3 ping -W2 }
ping6_gw(){ ip -6 route | awk '/default/ {printf "-I %s %s", $5, $3; exit}' | xargs --no-run-if-empty --max-args 3 ping -6 -W2 }
alias :q=exit
alias todotxt="vim ~/Dropbox/todo/todo.txt"
alias grep="grep --binary-files=without-match --directories=skip --color=auto"
alias R="R --quiet"
if [ -n "${commands[xclip]}" ]; then
  # normalize 
  pbcopy() {
    tee >(xclip -selection primary) | xclip -selection clipboard
  }
  pbpaste() { xclip -o }
  pbpaste2() { xclip -selection clipboard -o }
fi
if [ -n "${commands[bat]}" ]; then 
  alias cat="bat --style plain,changes,header --theme 'Lyte-Solarized-Light'"
fi

## PROFILE
path=(
    $HOME/bin
    $HOME/.cabal/bin
    $HOME/.cargo/bin
    $HOME/go/bin
    $HOME/.go/bin
    $HOME/.gem/ruby/*.*.*/bin(NOn[1])
    # python
    $HOME/.local/bin/
    $path
)
# get rid of duplicate
typeset -U path
# remove non-existing entries from path
path=($^path(N))
export PATH
cdpath=( ~/git )
# Prefered programs
export BROWSER=firefox
export TERMINAL=alacritty
export PICTUREVIEW=eog
export EDITOR=vim
export VISUAL=$EDITOR
export ALTERNATE_EDITOR=vim
export PAGER=less
export ACK_PAGER=$PAGER
export READNULLCMD=$PAGER
export pacman_program=pacman-color
# X11, Sound, Graphic
export XDG_CACHE_HOME=~/.cache
export XDG_CONFIG_HOME=~/.config
export XDG_DATA_HOME=~/.data
export XDG_DESKTOP_DIR="$HOME/Desktop"
export XDG_DOCUMENTS_DIR="$HOME/Documents"
export XDG_DOWNLOAD_DIR="$HOME/Downloads"
export XDG_MUSIC_DIR="$HOME/Music"
export XDG_PICTURES_DIR="$HOME/Pictures"
export XDG_PUBLICSHARE_DIR="$HOME/Public"
export XDG_TEMPLATES_DIR="$HOME/.Templates"
export XDG_VIDEOS_DIR="$HOME/Videos"
export ERRFILE=~/.xsession-errors
# Antialising
export QT_XFT=1
export GDK_USE_XFT=1
export _JAVA_OPTIONS='-Dawt.useSystemAAFontSettings=lcd -Dswing.defaultlaf=com.sun.java.swing.plaf.gtk.GTKLookAndFeel'
# To enable Graphic Hardware acceleration
#export LIBGL_ALWAYS_INDIRECT=1
export INTEL_BATCH=1
# Enable Pulse for SDL
export SDL_AUDIODRIVER=pulse
# fix broken xdg-open
export GDMSESSION=1 GNOME_DESKTOP_SESSION_ID=1
# less
export LESS=-FXisRM
export LESS_TERMCAP_mb=$'\E[01;31m'     # begin blinking
export LESS_TERMCAP_me=$'\E[0m'         # end mode
export LESS_TERMCAP_se=$'\E[0m'         # end standout-mode
export LESS_TERMCAP_so=$'\E[01;44;33m'  # begin standout-mode - info box
export LESS_TERMCAP_ue=$'\E[0m'         # end underline
export LESS_TERMCAP_us=$'\E[03;33;146m' # begin underline is now yellow, italic
#                           |  |  |
#                           |  |----------------- yellow
#                           |-------------------- italic
# Man
export MANWIDTH=80
# If the execution of a command takes longer than
# REPORTTIME (in seconds),  time statistics are printed
export REPORTTIME=4
# Enforce correct locales from the beginning:
# LC_ALL is unset since it overwrites everything
# LANG=de_DE.UTF-8 is used, except for:
# LC_MESSAGES=en_DK.UTF-8 never translates program output
# LC_TIME=en_DK.UTF-8 leads to yyyy-mm-dd hh:mm date/time output
unset LC_ALL
export LANG=en_US.UTF-8
export LC_MESSAGES=en_DK.UTF-8
export LC_TIME=en_DK.UTF-8
export PERL_CPANM_OPT="--local-lib=~/.perl5"
export PERL5LIB=~/.perl5/lib/perl5
export PYTHONDOCS=/usr/share/doc/python/html/
if [ -x "$HOME/.go/bin/go" ]; then
  export GOROOT="$HOME/.go"
  export GOROOT_BOOTSTRAP=/usr/lib/go
fi
export GOPATH="$HOME/go"
[ ! -d "$GOPATH" ] && mkdir -p "$GOPATH/src" 2>/dev/null

if [ -S /run/user/1000/ssh-agent ]; then
  export SSH_AUTH_SOCK=/run/user/1000/ssh-agent
fi

if [[ -n ${commands[lesspipe.sh]} ]]; then
  export LESSOPEN="| lesspipe.sh %s"
fi

unlock_root(){
  echo "cryptsetup luksOpen --tries 99 /dev/sda2 root && killall cryptsetup"
  cat ~/.secret/cryptsetup-passwd | ssh -tt -v root@eve -p 2222
}
network() {
  (
    echo "$fg_bold[green]# Interfaces$reset_color"
    ip a s $1 || ip a s | grep "$1"
    (
      echo "\n$fg_bold[green]# Routes (v4) $reset_color"
      ip route;
      echo "\n$fg_bold[green]# Routes (v6) $reset_color"
      ip -6 route;
      echo "\n$fg_bold[green]# Rule $reset_color"
      ip rule;
      echo "\n$fg_bold[green]# Neighbor $reset_color"
      ip neigh
    ) | grep --color=always "$1"
  ) | less '+/#'
}
# Autoinstall Bundle
bundle() {
  if [ -z "${commands[bundle]}" ] && [ -n "${commands[gem]}" ]; then
   gem install --user-install bundler
  fi
  command bundle "$@"
}
fd() {
  if [ "${commands[fd]}" ]; then
    command fd "$@"
  else
    command find . -iname "*$@*" 2>/dev/null
  fi
}
browse () { $BROWSER file://"`pwd`/$1" }
retry() {
  local n=0
  local trys=${TRYS:-100000}
  local sleep_time=${SLEEP:-1}
  until ($1 "${@:2}") ; do
      n=$(( n + 1 ))
      [ $n -gt $trys ] && return 1
      sleep $sleep_time
  done
}
own() {
  if [ -n "${commands[sudo]}" ]; then
    sudo chown -R "$USER:$(id -gn)" "$@"
  else
    chown -R "$USER:$(id -gn)" "$@"
  fi
}
# usage
# vil file:20 -> opens file on line 20
vil() {
  setopt shwordsplit
  IFS=':' ARGS=($@)
  unsetopt shwordsplit
  vim +${ARGS[2]} ${ARGS[1]}
}
# force output to be on a single line
ss() {
  # -p requires sudo to see all processes
  if echo "$@" | grep -q "p"; then
    sudo ss "$@" | tee
  else
    command ss "$@" | tee
  fi
}
# Autossh - try to connect every 0.5 secs (modulo timeouts)
sssh(){ while true; do command ssh -q "$@"; [ $? -ne 0 ] && break || sleep 0.5; done }
moshlogin(){
  if ssh-add -L | grep -q "no identities"; then
    ssh-add ~/.ssh/id_{rsa,ecdsa,ed25519}
  fi
  ssh login killall mosh-server;
  mosh -A -p 60011:60011 login
}
# List directory after changing directory
if [ "${commands[exa]}" ]; then
  chpwd() { exa }
else
  chpwd() { ls }
fi
mkcd() { mkdir -p "$1" && cd "$1"; }
# make cd accept files
cd() {
  local to="${1:-$HOME}"
  if [ -f "$to" ]; then
    to="$(dirname $to)"
  fi
  builtin cd "$to"
}
pj() { python -mjson.tool } # pretty-print JSON
cj() { curl -sS $@ | pj } # curl JSON
md5() { echo -n $1 | openssl md5 /dev/stdin }
sha1() { echo -n $1 | openssl sha1 /dev/stdin }
sha256() { echo -n $1 | openssl dgst -sha256 /dev/stdin }
sha512() { echo -n $1 | openssl dgst -sha512 /dev/stdin }
rot13() { echo $1 | tr "A-Za-z" "N-ZA-Mn-za-m" }
urlencode() { python2 -c "import sys, urllib as ul; print ul.quote_plus(sys.argv[1])" $1 }
urldecode() { python2 -c "import sys, urllib as ul; print ul.unquote_plus(sys.argv[1])" $1 }
last_modified() { ls -t $* 2> /dev/null | head -n 1 }
cheat() { command cheat "$@" | less }
ninja(){
  local build_path="$(dirname "$(upfind "build.ninja")")"
  command ninja -C "${build_path:-.}" "$@"
}
make(){
  local build_path="$(dirname "$(upfind "Makefile")")"
  command make -C "${build_path:-.}" "$@"
}
cargo(){
  local build_path="$(dirname "$(upfind "Cargo.toml")")"
  (
    builtin cd "${build_path:-.}" >/dev/null
    command cargo "$@"
  )
}
real-which(){
  realpath "$(command which $@)"
}

heroku(){
  docker run -it --rm -u $(id -u):$(id -g) -w "$HOME" \
    -v /etc/passwd:/etc/passwd:ro \
    -v /etc/group:/etc/group:ro \
    -v /etc/localtime:/etc/localtime:ro \
    -v /home:/home \
    -v /tmp:/tmp \
    -v /run/user/$(id -u):/run/user/$(id -u) \
    -v $(pwd):/workdir \
    -w /workdir \
    --name heroku \
    wingrunr21/alpine-heroku-cli "$@"
}

build-cscope-db() {
    find ${PWD} -type f -name "*.c" \
        -o -name "*.cc" \
        -o -name "*.cpp" \
        -o -name "*.h" \
        -o -name "*.hpp" \
        -o -name "*.H" > ${PWD}/cscope.files
    cscope -R -b
    export CSCOPE_DB=${PWD}/cscope.out
}

nixify() {
  if [ ! -e ./.envrc ]; then
    echo "use nix" > .envrc
    direnv allow
  fi
  if [ ! -e default.nix ]; then
    cat > default.nix <<'EOF'
with import <nixpkgs> {};
stdenv.mkDerivation {
  name = "env";
  buildInputs = [
    bashInteractive
  ];
}
EOF
    ${EDITOR:-vim} default.nix
  fi
}

open() {
  if [ -n "${commands[xdg-open]}" ]; then
    xdg-open "$@"
  elif [ -n "${commands[kde-open5]}" ]; then
    kde-open5 "$@"
  elif [ -n "${commands[gnome-open]}" ]; then
    gnome-open "$@"
  else
    echo "no suitable command found" >&2
    return 1
  fi
}

## Autocycle
setopt autopushd
# Cycle directory with Ctrl-Right and Ctrl-Left
eval "insert-cycledleft () { zle push-line; LBUFFER='pushd -q +1'; zle accept-line }"
zle -N insert-cycledleft
bindkey "^[[1;5C" insert-cycledleft
eval "insert-cycledright () { zle push-line; LBUFFER='pushd -q -0'; zle accept-line }"
zle -N insert-cycledright
bindkey "^[[1;5D" insert-cycledright

## Terminal stuff
ulimit -S -c 0 # disable core dumps
stty -ctlecho # turn off control character echoing
if [[ $TERM = linux ]]; then
  setterm -regtabs 2 # set tab width of 4 (only works on TTY)
fi

## Per machine zshrc
if [ -f $HOME/.zshrc.$HOST ]; then
  source $HOME/.zshrc.$HOST
fi

# added by travis gem
if [ -f /home/joerg/.travis/travis.sh ]; then
  source /home/joerg/.travis/travis.sh
fi

## Plugins
if [ -f "$HOME/.zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
  source "$HOME/.zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi
if [ -f "$HOME/.zsh-history-substring-search/zsh-history-substring-search.zsh" ]; then
  source "$HOME/.zsh-history-substring-search/zsh-history-substring-search.zsh"
  # bind P and N for EMACS mode
  bindkey -M emacs '^P' history-substring-search-up
  bindkey -M emacs '^N' history-substring-search-down
fi
if [ -f "$HOME/.zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
  source "$HOME/.zsh-autosuggestions/zsh-autosuggestions.zsh"
fi
if [ -f "$HOME/.homesick/repos/homeshick/homeshick.sh" ]; then
  source "$HOME/.homesick/repos/homeshick/homeshick.sh"
fi
if [ -f "$HOME/.zsh-autopair/autopair.zsh" ]; then
  source "$HOME/.zsh-autopair/autopair.zsh"
fi
source ~/.zsh-termsupport

if [ -d "$HOME/git/x86_64-linux-cheatsheats/pages" ]; then
  export CHEATPATH="$HOME/git/x86_64-linux-cheatsheats/pages"
fi
if [ -n "${commands[r2]}" ]; then
  r2() {
    if [[ "$#" -eq 0 ]]; then
      command r2 -
    else
      command r2 "$@"
    fi
  }
fi
if [ -n "${commands[direnv]}" ]; then
  eval "$(direnv hook zsh)"
fi
if [ -f /usr/share/chruby/chruby.sh ]; then
  source /usr/share/chruby/chruby.sh
  source /usr/share/chruby/auto.sh
elif [ -d "$HOME/.rvm/bin" ]; then
  export PATH="$PATH:$HOME/.rvm/bin" # Add RVM to PATH for scripting
fi
if [ -d "$HOME/.pyenv" ]; then
  export PYENV_ROOT="$HOME/.pyenv"
  export PATH="$PYENV_ROOT/bin:$PATH"
fi
if [ -n "${commands[fzf-share]}" ]; then
  FZF_CTRL_R_OPTS=--reverse
  source "$(fzf-share)/key-bindings.zsh"
fi
