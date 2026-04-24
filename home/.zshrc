# ~/.zshrc — pure zsh 構成 (prezto 廃止版、steeef 風プロンプト)

# ---- brew の PATH を最優先で通す ----
# .zshrc.akaimo でも同じ eval を実行しているが二重実行に副作用はない
if [[ $(uname -m) == arm64 ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# ---- history ----
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt append_history
setopt inc_append_history
setopt share_history
setopt extended_history
setopt hist_ignore_dups
setopt hist_ignore_space
setopt hist_reduce_blanks

# ---- editor (vi mode) ----
bindkey -v
# 互換確保: 履歴検索などの定番バインド
bindkey '^R' history-incremental-search-backward
bindkey '^A' beginning-of-line
bindkey '^E' end-of-line
# vi insert モードでは backspace などが効かない挙動があるため明示
bindkey -M viins '^?' backward-delete-char
bindkey -M viins '^H' backward-delete-char
bindkey -M viins '^W' backward-kill-word
bindkey -M viins '^U' backward-kill-line

# ---- completion (prezto completion モジュール相当) ----
# brew の zsh-completions / site-functions を fpath の先頭に(compinit より前に実行)
if [[ -n "${HOMEBREW_PREFIX:-}" ]]; then
  fpath=(
    "${HOMEBREW_PREFIX}/share/zsh-completions"
    "${HOMEBREW_PREFIX}/share/zsh/site-functions"
    $fpath
  )
fi

setopt COMPLETE_IN_WORD    # 単語の途中からでも補完
setopt ALWAYS_TO_END       # 補完後はカーソルを語尾へ
setopt PATH_DIRS           # スラッシュ入りコマンドも PATH 探索
setopt AUTO_MENU           # 2回目の Tab からメニュー表示
setopt AUTO_LIST           # あいまい補完で候補一覧を自動表示
setopt AUTO_PARAM_SLASH    # ディレクトリ補完時に / を付与
setopt EXTENDED_GLOB       # compinit のグロブ修飾子に必要
unsetopt MENU_COMPLETE     # 1回目の Tab で無言で1候補を選ばない
unsetopt FLOW_CONTROL      # ZLE での Ctrl+S/Q を解放

# LS_COLORS のデフォルト(brew の coreutils が無くても色が出る)
LS_COLORS=${LS_COLORS:-'di=34:ln=35:so=32:pi=33:ex=31:bd=36;01:cd=33;01:su=31;40;07:sg=36;40;07:tw=32;40;07:ow=33;40;07:'}

# 補完キャッシュ(prezto は ~/.cache/prezto/ 配下だったが zsh 専用ディレクトリに寄せる)
autoload -Uz compinit
_comp_cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
_comp_dump="$_comp_cache_dir/zcompdump"
# 20時間以内にダンプ済みなら -C でスキップ、そうでなければ -i で再生成
if [[ $_comp_dump(#qNmh-20) ]]; then
  compinit -C -d "$_comp_dump"
else
  mkdir -p "$_comp_cache_dir"
  compinit -i -d "$_comp_dump"
  touch "$_comp_dump"
fi
unset _comp_dump

# 候補の見た目 / 動作
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*:default' list-prompt '%S%M matches%s'
zstyle ':completion::complete:*' use-cache on
zstyle ':completion::complete:*' cache-path "$_comp_cache_dir/zcompcache"
unset _comp_cache_dir

# 大小文字を無視 + `.`, `_`, `-` 区切りでの部分一致 / 前方一致 / 後方一致
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
unsetopt CASE_GLOB

# メニュー選択(矢印キーで候補間移動)
zstyle ':completion:*:*:*:*:*' menu select

# 候補のグルーピング・説明
zstyle ':completion:*:matches' group 'yes'
zstyle ':completion:*:options' description 'yes'
zstyle ':completion:*:options' auto-description '%d'
zstyle ':completion:*:corrections' format ' %F{green}-- %d (errors: %e) --%f'
zstyle ':completion:*:descriptions' format ' %F{yellow}-- %d --%f'
zstyle ':completion:*:messages' format ' %F{purple} -- %d --%f'
zstyle ':completion:*:warnings' format ' %F{red}-- no matches found --%f'
zstyle ':completion:*' format ' %F{yellow}-- %d --%f'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' verbose yes

# 近似補完(タイポしても候補を出す)。max-errors は入力長に応じて動的に
zstyle ':completion:*' completer _complete _match _approximate
zstyle ':completion:*:match:*' original only
zstyle ':completion:*:approximate:*' max-errors 1 numeric
zstyle -e ':completion:*:approximate:*' max-errors \
  'reply=($((($#PREFIX+$#SUFFIX)/3>7?7:($#PREFIX+$#SUFFIX)/3))numeric)'

# 関数補完で `_foo` / precmd / preexec を候補から除外
zstyle ':completion:*:functions' ignored-patterns '(_*|pre(cmd|exec))'

# 特定コマンドの補完挙動
zstyle ':completion:*:*:-subscript-:*' tag-order indexes parameters
zstyle ':completion:*:*:cd:*' tag-order local-directories directory-stack path-directories
zstyle ':completion:*:*:cd:*:directory-stack' menu yes select
zstyle ':completion:*:-tilde-:*' group-order 'named-directories' 'path-directories' 'users' 'expand'
zstyle ':completion:*' squeeze-slashes true

# 履歴単語補完
zstyle ':completion:*:history-words' stop yes
zstyle ':completion:*:history-words' remove-all-dups yes
zstyle ':completion:*:history-words' list false
zstyle ':completion:*:history-words' menu yes

# 環境変数補完で配列のキーも候補に
zstyle ':completion::*:(-command-|export):*' fake-parameters \
  ${${${_comps[(I)-value-*]#*,}%%,*}:#-*-}

# ssh / ホスト名補完(known_hosts / /etc/hosts / ~/.ssh/config から)
_etc_host_ignores=()
zstyle -e ':completion:*:hosts' hosts 'reply=(
  ${=${=${=${${(f)"$(cat {/etc/ssh/ssh_,~/.ssh/}known_hosts(|2)(N) 2> /dev/null)"}%%[#| ]*}//\]:[0-9]*/ }//,/ }//\[/ }
  ${=${(f)"$(cat /etc/hosts(|)(N) <<(ypcat hosts 2> /dev/null))"}%%(\#${_etc_host_ignores:+|${(j:|:)~_etc_host_ignores}})*}
  ${=${${${${(@M)${(f)"$(cat ~/.ssh/config 2> /dev/null)"}:#Host *}#Host }:#*\**}:#*\?*}}
)'

# システムアカウントを user 補完から除外
zstyle ':completion:*:*:*:users' ignored-patterns \
  adm amanda apache avahi beaglidx bin cacti canna clamav daemon \
  dbus distcache dovecot fax ftp games gdm gkrellmd gopher \
  hacluster haldaemon halt hsqldb ident junkbust ldap lp mail \
  mailman mailnull mldonkey mysql nagios \
  named netdump news nfsnobody nobody nscd ntp nut nx openvpn \
  operator pcap postfix postgres privoxy pulse pvm quagga radvd \
  rpc rpcuser rpm shutdown squid sshd sync uucp vcsa xfs '_*'
# 本当に補完したい場合のために、ignored でも明示的に出した時は表示する
zstyle '*' single-ignored show

# 重複選択の排除 (rm foo foo が補完で並ばないように)
zstyle ':completion:*:(rm|kill|diff):*' ignore-line other
zstyle ':completion:*:rm:*' file-patterns '*:all-files'

# kill のプロセス補完を見やすく
zstyle ':completion:*:*:*:*:processes' command 'ps -u $LOGNAME -o pid,user,command -w'
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#) ([0-9a-z-]#)*=01;36=0=01'
zstyle ':completion:*:*:kill:*' menu yes select
zstyle ':completion:*:*:kill:*' force-list always
zstyle ':completion:*:*:kill:*' insert-ids single

# man のセクション別表示
zstyle ':completion:*:manuals' separate-sections true
zstyle ':completion:*:manuals.(^1*)' insert-sections true

# メディアプレイヤ系: 対応拡張子に絞る
zstyle ':completion:*:*:mpg123:*' file-patterns '*.(mp3|MP3):mp3\ files *(-/):directories'
zstyle ':completion:*:*:mpg321:*' file-patterns '*.(mp3|MP3):mp3\ files *(-/):directories'
zstyle ':completion:*:*:ogg123:*' file-patterns '*.(ogg|OGG|flac):ogg\ files *(-/):directories'
zstyle ':completion:*:*:mocp:*' file-patterns '*.(wav|WAV|mp3|MP3|ogg|OGG|flac):ogg\ files *(-/):directories'

# Mutt (aliases が存在する場合のみ)
if [[ -s "$HOME/.mutt/aliases" ]]; then
  zstyle ':completion:*:*:mutt:*' menu yes select
  zstyle ':completion:*:mutt:*' users ${${${(f)"$(<"$HOME/.mutt/aliases")"}#alias[[:space:]]}%%[[:space:]]*}
fi

# SSH / SCP / RSYNC: hosts を優先して出す + IP 除外の細かな制御
zstyle ':completion:*:(ssh|scp|rsync):*' tag-order 'hosts:-host:host hosts:-domain:domain hosts:-ipaddr:ip\ address *'
zstyle ':completion:*:(scp|rsync):*' group-order users files all-files hosts-domain hosts-host hosts-ipaddr
zstyle ':completion:*:ssh:*' group-order users hosts-domain hosts-host users hosts-ipaddr
zstyle ':completion:*:(ssh|scp|rsync):*:hosts-host' ignored-patterns '*(.|:)*' loopback ip6-loopback localhost ip6-localhost broadcasthost
zstyle ':completion:*:(ssh|scp|rsync):*:hosts-domain' ignored-patterns '<->.<->.<->.<->' '^[-[:alnum:]]##(.[-[:alnum:]]##)##' '*@*'
zstyle ':completion:*:(ssh|scp|rsync):*:hosts-ipaddr' ignored-patterns '^(<->.<->.<->.<->|(|::)([[:xdigit:].]##:(#c,2))##(|%*))' '127.0.0.<->' '255.255.255.255' '::1' 'fe80::*'

# ---- prompt (steeef 風) ----
# prezto の prompt_steeef_setup をもとに pure zsh で再実装
autoload -Uz add-zsh-hook vcs_info
setopt prompt_subst

if [[ $TERM == *256color* || $TERM == *rxvt* ]]; then
  _prompt_colors=(
    '%F{81}'   # 1: turquoise (branch)
    '%F{166}'  # 2: orange    (host / unstaged)
    '%F{135}'  # 3: purple    (user)
    '%F{161}'  # 4: hotpink   (untracked)
    '%F{118}'  # 5: limegreen (path / staged / action)
  )
else
  _prompt_colors=('%F{cyan}' '%F{yellow}' '%F{magenta}' '%F{red}' '%F{green}')
fi

zstyle ':vcs_info:*' enable git hg svn bzr
zstyle ':vcs_info:*' check-for-changes true
zstyle ':vcs_info:*' stagedstr   "${_prompt_colors[5]}●%f"
zstyle ':vcs_info:*' unstagedstr "${_prompt_colors[2]}●%f"
zstyle ':vcs_info:*' actionformats "(${_prompt_colors[1]}%b%f%u%c${_prompt_colors[5]}|%a%f)"

_prompt_precmd() {
  # vcs_info は追跡済みの変更しか見ないので、untracked ファイルを自分で判定
  # 大量の untracked がある repo でも 1 件見つかった時点で終わるよう grep -q を通す
  if git ls-files --other --exclude-standard 2>/dev/null | grep -q .; then
    zstyle ':vcs_info:*' formats "(${_prompt_colors[1]}%b%f%u%c${_prompt_colors[4]}●%f)"
  else
    zstyle ':vcs_info:*' formats "(${_prompt_colors[1]}%b%f%u%c)"
  fi
  vcs_info
}
add-zsh-hook precmd _prompt_precmd

# 1行目: user at host in path (branch)
# 2行目: $
PROMPT=$'\n'"${_prompt_colors[3]}%n%f at ${_prompt_colors[2]}%m%f in ${_prompt_colors[5]}%~%f "'${vcs_info_msg_0_}'$'\n''$ '
RPROMPT=''

# ---- コマンド名タイポ補正 (prezto utility 相当) ----
# CORRECT: コマンド名の補正のみ。引数も補正する CORRECT_ALL は誤爆が多いため使わない
setopt correct
# 誤爆しやすいコマンドは nocorrect でラップ(引数が存在しないことが多いため)
alias ack='nocorrect ack'
alias cd='nocorrect cd'
alias cp='nocorrect cp'
alias ebuild='nocorrect ebuild'
alias gcc='nocorrect gcc'
alias gist='nocorrect gist'
alias grep='nocorrect grep'
alias heroku='nocorrect heroku'
alias ln='nocorrect ln'
alias man='nocorrect man'
alias mkdir='nocorrect mkdir'
alias mv='nocorrect mv'
alias mysql='nocorrect mysql'
alias rm='nocorrect rm'

# ---- ls family aliases (prezto utility 相当) ----
if [[ $(uname) == Darwin ]]; then
  alias ls='ls -GF'                   # BSD ls: カラー + 種別マーカー
else
  alias ls='ls --color=auto -F'
fi
alias l='ls -1A'   # 1 列表示、隠しファイル含む
alias ll='ls -lh' # 人間が読めるサイズ
alias la='ll -A'  # ll + 隠しファイル
alias lr='ll -R'  # 再帰
alias lk='ll -Sr' # サイズ降順
alias lt='ll -tr' # mtime 昇順

# ---- brew 製プラグインとユーザー設定 ----
# 順序の原則:
#   1. autosuggestions / history-substring-search (ZLE widget 登録)
#   2. ユーザー設定 (.zshrc.akaimo で bindkey / completion / alias 等を触る)
#   3. syntax-highlighting は必ず最後 (既存 widget を hook するため)
_brew_share="${HOMEBREW_PREFIX:-/opt/homebrew}/share"

[ -r "$_brew_share/zsh-autosuggestions/zsh-autosuggestions.zsh" ] && \
  source "$_brew_share/zsh-autosuggestions/zsh-autosuggestions.zsh"

if [ -r "$_brew_share/zsh-history-substring-search/zsh-history-substring-search.zsh" ]; then
  source "$_brew_share/zsh-history-substring-search/zsh-history-substring-search.zsh"
  # vi コマンドモードで j/k を履歴検索にバインド
  bindkey -M vicmd 'k' history-substring-search-up
  bindkey -M vicmd 'j' history-substring-search-down
  bindkey '^[[A' history-substring-search-up
  bindkey '^[[B' history-substring-search-down
fi

# ユーザー固有の設定 (syntax-highlighting より前に source する)
[ -f ~/.zshrc.akaimo ] && source ~/.zshrc.akaimo

# syntax-highlighting は最後
[ -r "$_brew_share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ] && \
  source "$_brew_share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

unset _brew_share
