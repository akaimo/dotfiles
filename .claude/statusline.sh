#!/bin/bash

# Read JSON from stdin
input=$(cat)

# Extract values using jq
model=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
workspace_dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
current_dir=$(basename "${workspace_dir:-.}")
# worktree名（worktreeセッション時のみ提供される）
worktree_name=$(echo "$input" | jq -r '.worktree.name // empty')
# コンテキストウィンドウ使用割合（小数第1位、未提供時は0、範囲外はクランプ）
raw_percentage=$(echo "$input" | jq -r '
    .context_window.used_percentage
    | if . == null then 0 else . end
    | if . < 0 then 0 elif . > 100 then 100 else . end
')
percentage=$(printf "%.1f" "$raw_percentage")
# 200kトークン超過フラグ
exceeds_200k=$(echo "$input" | jq -r '.exceeds_200k_tokens // false')

# サンドボックス有効/無効を判定（後勝ち: user < project < local）
sandbox_enabled="false"
settings_files=("$HOME/.claude/settings.json")

# workspace_dirから上位ディレクトリを遡って最初に見つかった .claude/ をプロジェクトルートとする
if [ -n "$workspace_dir" ]; then
    project_root=""
    dir="$workspace_dir"
    while [ "$dir" != "/" ] && [ -n "$dir" ]; do
        if [ -d "$dir/.claude" ]; then
            project_root="$dir"
            break
        fi
        dir=$(dirname "$dir")
    done
    if [ -n "$project_root" ]; then
        settings_files+=("$project_root/.claude/settings.json" "$project_root/.claude/settings.local.json")
    fi
fi

for settings_file in "${settings_files[@]}"; do
    if [ -f "$settings_file" ]; then
        value=$(jq -r '.sandbox.enabled // empty' "$settings_file" 2>/dev/null)
        if [ -n "$value" ]; then
            sandbox_enabled="$value"
        fi
    fi
done

# レート制限の消費割合（used_percentageをfloorし0〜100にクランプ）
rate_limits_display=$(echo "$input" | jq -r '
    def used: if . == null then empty else floor | if . < 0 then 0 elif . > 100 then 100 else . end end;
    [
        (.rate_limits.five_hour.used_percentage | used | "5h:\(.)%"),
        (.rate_limits.seven_day.used_percentage | used | "7d:\(.)%")
    ] | join(" ")
')

# Build status line
location="${current_dir}"
if [ -n "$worktree_name" ]; then
    location="${location} [${worktree_name}]"
fi
status_line="[${model}] ${location} | ${percentage}%"

# 200kトークンを超えた場合は警告を付加
if [ "$exceeds_200k" = "true" ]; then
    status_line="${status_line} | WARN:>200k"
fi

# レート制限残量（取得できた場合のみ）
if [ -n "$rate_limits_display" ]; then
    status_line="${status_line} | ${rate_limits_display}"
fi

# サンドボックス有効時にマーカーを付加
if [ "$sandbox_enabled" = "true" ]; then
    status_line="${status_line} | SBX"
fi

# Output status line
echo -e "$status_line"
