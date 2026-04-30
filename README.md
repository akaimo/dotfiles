# dotfiles

## 新規構築 (新規マシンでのセットアップ)

- install homebrew
  - https://brew.sh/ja/
- install tools
  - `brew install git`
- clone dotfiles
  - `git clone --recursive https://github.com/akaimo/dotfiles.git ~/dotfiles`
- 以降の手順は `~/dotfiles` ディレクトリで実行する
  - `cd ~/dotfiles`
- install homebrew packages via Brewfile
  - `make brew`
- create dotfile symlinks via GNU Stow
  - 先に `make stow-dry-run` で想定リンクを確認する
  - 実ファイル/ディレクトリが邪魔する場合は手動で退避してから再実行する: `mv ~/.xxx ~/.xxx.backup.$(date +%Y%m%d%H%M%S)`
  - `make stow`
- finicky 設定を配置する (使用していれば)
  - `make finicky-install`
  - 詳細は本 README の「finicky 設定の配置」セクション参照
- set login shell (必要なら)
  - macOS は既定で zsh だが、他シェルのままなら `chsh -s /bin/zsh`
- reload shell
  - `exec $SHELL -l`
- mise
  - `mise i`
- install vim
  - `make vim`
  - vim-plug を `~/.vim/autoload/` と `~/.local/share/nvim/site/autoload/` に配置し、nvim 用の Python provider (pynvim) を `~/.local/share/nvim/venv/` に uv で用意する
  - 事前に `mise i` で uv が入っている必要あり
- install vim plugin
  - vim / nvim を起動して `:PlugInstall`
  - nvim では初回のみ `:UpdateRemotePlugins` を実行して remote plugin manifest を生成してから nvim を再起動 (deoplete.nvim 等の Python remote plugin 用)
- (option) use ssh
  - `git remote set-url origin git@github.com:akaimo/dotfiles.git`

## ansibleからの移行 (既存マシンからの移行手順)

ansible で構築済みの環境から本構成へ乗り換える場合、以下のクリーンアップを先に実施してから、新規構築と同じ `make stow` / `make vim` を実行する。

- dotfiles リポジトリを最新化
  - `cd ~/dotfiles && git pull`
- Brewfile のパッケージを反映 (stow / zsh プラグイン等が新規追加されているため)
  - `make brew`
- 過去の Ansible が作った古いリンク(dotfiles 由来 + prezto 由来)を削除する
  - `make ansible-links-cleanup-dry-run` で確認してから `make ansible-links-cleanup`
- prezto の残骸を削除
  - `rm -rf ~/.zprezto` (以前 ansible が clone していたリポジトリの残骸を消す)
  - `rm -f ~/.cache/zsh/zcompdump*` (新しく入った zsh-completions を反映させるため、補完キャッシュを一度消す)
- 新しい構成でシンボリックリンクを作り直す
  - 先に `make stow-dry-run` で想定リンクを確認する
  - 実ファイル/ディレクトリが邪魔する場合は手動で退避してから再実行する: `mv ~/.xxx ~/.xxx.backup.$(date +%Y%m%d%H%M%S)`
  - `make stow`
- reload shell
  - `exec $SHELL -l`
- vim 周りを再セットアップ
  - `make vim`
  - 続けて vim / nvim を起動して `:PlugInstall`、nvim では初回のみ `:UpdateRemotePlugins` を実行

## finicky 設定の配置

finicky は人間がエディタで設定ファイルを編集するアプリのため、リポジトリ内の `finicky/finicky.js` を **正本** として、`make finicky-install` で `~/.config/finicky/finicky.js` に「コピー」で配置する (repo → アプリ方向のデプロイ)。stow 対象外。

> Karabiner はアプリ GUI 側で設定を行うため `make karabiner-backup` で repo に取り込む (アプリ → repo, バックアップ方向)。両者でコピーの向きが逆である点に注意。

### なぜ stow (symlink) を使わないか

finicky v4.2.2 の watcher (fsnotify) は symlink を解決した実体パスを watch するが、`fsnotify.Remove` イベントを受け取ると watcher の goroutine が `return` で終了し、以降設定が一切読み込まれなくなる (再 watch のリトライ実装がない)。

stow で `~/dotfiles/home/.finicky.js` を symlink 配置していると、`git pull` / `git checkout` / `git restore` 等が実体ファイルを delete→create で置換した際に Remove イベントが発火し、finicky が設定を見失う。watch 対象を git 操作の影響範囲外に置くことでこの再発を根本から防いでいる。

### 使い方

- 配置/反映する
  - `make finicky-install`
  - `finicky/finicky.js` を `~/.config/finicky/finicky.js` にコピーし、Finicky を再起動する
  - 旧運用の symlink (`~/.finicky.js`) が残っていれば自動で削除する
- 設定を変更する
  - `finicky/finicky.js` を編集してコミット
  - repo 側の `finicky/finicky.js` を編集しても、配置先には自動反映されない
  - 反映するときは `make finicky-install` を実行する

### 注意

- `~/.config/finicky/finicky.js` を直接エディタで編集しない (atomic save で同じ Remove イベントが起きる)
- `make stow` では配置されない。新規マシンセットアップ時は `make stow` の後に `make finicky-install` を別途実行する
- `~/.finicky.js` に実ファイル/ディレクトリが残っている場合は安全のためエラーで停止する。手動で退避すること

## VSCode 設定の管理

VSCode のうち、人が編集する `settings.json` は GNU Stow で管理する。

管理元は `home/Library/Application Support/Code/User/settings.json`、配置先は `~/Library/Application Support/Code/User/settings.json`。`make stow` で symlink が作られる。

- 拡張機能リストをバックアップする
  - `make vscode-backup`
  - `make vscode-extensions-backup` でも同じ
  - `code --list-extensions` の出力を `LC_ALL=C sort` で安定化して `vscode/extensions.txt` へ書き出す (git diff のノイズを避けるため)
  - `code` コマンドが PATH に無い場合は extensions.txt の更新をスキップする
  - `git diff vscode/` で差分を確認し、問題なければコミットする
- 復元する (新しいマシン等)
  - 先に `make stow-dry-run` で確認し、既存の `~/Library/Application Support/Code/User/settings.json` が邪魔する場合は手動で退避する
  - `make stow`
  - 拡張機能を一括インストール: `grep -v '^[[:space:]]*$' vscode/extensions.txt | xargs -L1 code --install-extension`
  - `code` コマンドが無い場合は VSCode を起動し、コマンドパレットから「Shell Command: Install 'code' command in PATH」を実行してから上記を再実行する
- 管理対象
  - stow: `settings.json`
  - バックアップ: `vscode/extensions.txt`
  - `keybindings.json` / `snippets/` は必要になったら `home/Library/Application Support/Code/User/` 配下へ追加して stow 対象にする
  - `profiles/` やアプリが自動更新する state/cache は対象外
- 注意
  - VSCode の設定 UI で `settings.json` を変更すると、symlink 経由で repo 側の `home/Library/Application Support/Code/User/settings.json` が更新される。差分を確認してコミットすること
  - `vscode/extensions.txt` は手動で `make vscode-backup` を叩かない限り更新されない
  - `code` コマンドが PATH に無い状態で `make vscode-backup` を実行した場合、`vscode/extensions.txt` は前回値のまま据え置きになる
  - VSCode Insiders は今回の管理対象外 (パスとコマンドが異なるため)

## Zed 設定の管理

Zed のうち、人が編集する `settings.json` は GNU Stow で管理する。

管理元は `home/.config/zed/settings.json`、配置先は `~/.config/zed/settings.json`。`make stow` で symlink が作られる。

- 復元する (新しいマシン等)
  - 先に `make stow-dry-run` で確認し、既存の `~/.config/zed/settings.json` が邪魔する場合は手動で退避する
  - Zed を一度終了してから `make stow` を実行する
- 管理対象
  - `home/.config/zed/settings.json` のみ
  - `keymap.json` / `tasks.json` / `snippets/` など、人が編集するものは必要になったら `home/.config/zed/` 配下へ追加して stow 対象にする
  - `themes/` / `prompts/` は自作で固定管理したい場合のみ追加する
- 注意
  - Zed 側で設定を変更すると、symlink 経由で repo 側の `home/.config/zed/settings.json` が更新される。差分を確認してコミットすること
  - アプリが自動更新する state/cache は stow 対象にしない

## Karabiner 設定のバックアップ

Karabiner-Elements の設定 (`~/.config/karabiner/karabiner.json`) は stow 対象ではなく、リポジトリ直下の `karabiner/` に「バックアップとしてコピー」して git 履歴で過去の設定を追える運用にしている。

- バックアップを取る
  - `make karabiner-backup`
  - `~/.config/karabiner/karabiner.json` を `karabiner/karabiner.json` へ上書きコピーする
  - `git diff karabiner/` で差分を確認し、問題なければコミットする
- 復元する (新しいマシン等)
  - Karabiner-Elements を一度終了してから実行 (起動中は書き戻しで上書きされる可能性があるため)
  - `mkdir -p ~/.config/karabiner && cp karabiner/karabiner.json ~/.config/karabiner/karabiner.json`
  - Karabiner-Elements を再起動し、端末固有のデバイス設定 (vendor/product ID 指定のキーバインド等) が復元先のキーボードで期待通り効くか確認する
- 注意
  - これは stow 対象ではないため、手動で `make karabiner-backup` を叩かない限り更新されない (Karabiner がファイルをアトミック rename で書き戻し symlink が壊れる問題を避けるため、あえて同期しない構成)
  - `~/.config/karabiner/automatic_backups/` は Karabiner が日次で作る自動バックアップで、本リポジトリの管理対象外
