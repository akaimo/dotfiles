#!/bin/bash

# Read JSON from stdin
input=$(cat)

# 単一jqでトップレベルの値をまとめて抽出（改行区切り → bash3.2互換のwhile-read）
vals=()
while IFS= read -r line; do
    vals+=("$line")
done < <(jq -r '
    def used: if . == null then empty else floor | if . < 0 then 0 elif . > 100 then 100 else . end end;
    [
      (.model.display_name // "Unknown"),
      (.workspace.current_dir // .cwd // ""),
      (.worktree.name // ""),
      (.context_window.used_percentage
        | if . == null then 0 else . end
        | if . < 0 then 0 elif . > 100 then 100 else . end),
      (.exceeds_200k_tokens // false),
      ([(.rate_limits.five_hour.used_percentage | used | "5h:\(.)%"),
        (.rate_limits.seven_day.used_percentage | used | "7d:\(.)%")] | join(" "))
    ][]
' <<<"$input")

model="${vals[0]}"
workspace_dir="${vals[1]}"
worktree_name="${vals[2]}"
raw_percentage="${vals[3]}"
exceeds_200k="${vals[4]}"
rate_limits_display="${vals[5]}"

# current_dir: basenameの代わりにパラメータ展開
tmp="${workspace_dir:-.}"
tmp="${tmp%/}"              # 末尾スラッシュ除去
current_dir="${tmp##*/}"    # 最後の/以降
[ -z "$current_dir" ] && current_dir="/"

# 使用割合を小数第1位に整形
percentage=$(printf "%.1f" "$raw_percentage")

# サンドボックス設定ファイルリスト（後勝ち: user < project < local）
settings_files=("$HOME/.claude/settings.json")

# workspace_dirから .claude/ があるディレクトリを遡って探す（dirnameをパラメータ展開に置換）
if [ -n "$workspace_dir" ]; then
    project_root=""
    dir="$workspace_dir"
    while [ "$dir" != "/" ] && [ -n "$dir" ]; do
        if [ -d "$dir/.claude" ]; then
            project_root="$dir"
            break
        fi
        parent="${dir%/*}"
        # 相対パス等でパラメータ展開が変化しない場合は無限ループ回避
        if [ "$parent" = "$dir" ]; then
            break
        fi
        dir="${parent:-/}"
    done
    if [ -n "$project_root" ]; then
        settings_files+=("$project_root/.claude/settings.json" "$project_root/.claude/settings.local.json")
    fi
fi

# 存在するファイルだけを単一jqで読み、後勝ちで sandbox.enabled を決定
existing_files=()
for f in "${settings_files[@]}"; do
    [ -f "$f" ] && existing_files+=("$f")
done
sandbox_enabled="false"
if [ "${#existing_files[@]}" -gt 0 ]; then
    result=$(jq -rs 'map(.sandbox.enabled // empty) | last // empty' "${existing_files[@]}" 2>/dev/null)
    [ -n "$result" ] && sandbox_enabled="$result"
fi

# Build status line
location="${current_dir}"
if [ -n "$worktree_name" ]; then
    location="${location} [${worktree_name}]"
fi
status_line="[${model}] ${location} | ${percentage}%"

# 200kトークンを超えた場合は警告
if [ "$exceeds_200k" = "true" ]; then
    status_line="${status_line} | WARN:>200k"
fi

# レート制限消費割合
if [ -n "$rate_limits_display" ]; then
    status_line="${status_line} | ${rate_limits_display}"
fi

# サンドボックス有効マーカー
if [ "$sandbox_enabled" = "true" ]; then
    status_line="${status_line} | SBX"
fi

printf '%s\n' "$status_line"
