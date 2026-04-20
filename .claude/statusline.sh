#!/bin/bash

# Read JSON from stdin
input=$(cat)

# Extract values using jq
model=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
workspace_dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
current_dir=$(basename "${workspace_dir:-.}")
session_id=$(echo "$input" | jq -r '.session_id // ""')
# コンテキストウィンドウサイズ（モデル依存、未提供や不正値の場合は200kにフォールバック）
context_window_size=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
if ! [[ "$context_window_size" =~ ^[0-9]+$ ]] || [ "$context_window_size" -le 0 ]; then
    context_window_size=200000
fi

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

# Initialize variables
context_length=0
window_time_remaining=""

# Calculate context length for current session
if [ -n "$session_id" ]; then
    projects_dir="$HOME/.claude/projects"

    if [ -d "$projects_dir" ]; then
        # Search for the transcript file
        transcript_file=""
        for project_dir in "$projects_dir"/*/; do
            if [ -f "${project_dir}${session_id}.jsonl" ]; then
                transcript_file="${project_dir}${session_id}.jsonl"
                break
            fi
        done

        # Calculate context length from the most recent main chain message
        if [ -n "$transcript_file" ] && [ -f "$transcript_file" ]; then
            # Get the most recent main chain message (isSidechain != true) with usage data
            # Sort by timestamp to find the most recent, excluding sidechains and API error messages
            most_recent=$(grep '"usage":{' "$transcript_file" | \
                         jq -s '
                            map(select(
                                (.isSidechain != true) and
                                (.timestamp != null) and
                                (.isApiErrorMessage != true)
                            )) |
                            sort_by(.timestamp) |
                            last
                         ')

            if [ -n "$most_recent" ] && [ "$most_recent" != "null" ]; then
                # Calculate context length: input_tokens + cache_read + cache_creation + output_tokens
                input_tokens=$(echo "$most_recent" | jq '.message.usage.input_tokens // 0')
                cache_creation=$(echo "$most_recent" | jq '.message.usage.cache_creation_input_tokens // 0')
                cache_read=$(echo "$most_recent" | jq '.message.usage.cache_read_input_tokens // 0')
                output_tokens=$(echo "$most_recent" | jq '.message.usage.output_tokens // 0')

                context_length=$((input_tokens + cache_creation + cache_read + output_tokens))
            fi
        fi
    fi
fi

# Calculate percentage (with decimal precision) - based on dynamic context window size
if [ $context_length -gt 0 ]; then
    percentage=$(echo "scale=1; $context_length * 100 / $context_window_size" | bc)
    # Cap at 100%
    percentage_check=$(echo "$percentage > 100" | bc)
    if [ "$percentage_check" -eq 1 ]; then
        percentage="100.0"
    fi
else
    percentage="0.0"
fi

# Format token display
format_token_count() {
    local tokens=$1
    if [ $tokens -ge 1000000 ]; then
        echo "$(echo "scale=1; $tokens/1000000" | bc)M"
    elif [ $tokens -ge 1000 ]; then
        echo "$(echo "scale=1; $tokens/1000" | bc)K"
    else
        echo "$tokens"
    fi
}

token_display=$(format_token_count $context_length)



# Get 5-hour window remaining time from ccusage
ccusage_output=$(ccusage blocks --json --active 2>/dev/null || true)

if [ -n "$ccusage_output" ]; then
    # Extract endTime and isActive from JSON
    end_time=$(echo "$ccusage_output" | jq -r '.blocks[0].endTime // ""')
    is_active=$(echo "$ccusage_output" | jq -r '.blocks[0].isActive // false')
    
    if [ "$is_active" = "true" ] && [ -n "$end_time" ]; then
        # Convert UTC ISO8601 to Unix timestamp
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS - parse UTC time (Unix timestamp is timezone-independent)
            end_timestamp=$(date -j -u -f "%Y-%m-%dT%H:%M:%S" "${end_time%%.*}" "+%s" 2>/dev/null || echo "0")
        else
            # Linux - parse UTC time directly
            end_timestamp=$(date -d "$end_time" +%s 2>/dev/null || echo "0")
        fi
        
        current_timestamp=$(date +%s)
        
        if [ "$end_timestamp" -gt "0" ]; then
            if [ "$end_timestamp" -gt "$current_timestamp" ]; then
                remaining_seconds=$((end_timestamp - current_timestamp))
                remaining_hours=$((remaining_seconds / 3600))
                remaining_minutes=$(((remaining_seconds % 3600) / 60))
                window_time_remaining="${remaining_hours}h${remaining_minutes}m"
            else
                window_time_remaining="Expired"
            fi
        fi
    fi
fi

# Build status line
status_line="[${model}] ${current_dir} | ${token_display} | ${percentage}%"

# Add window time if available
if [ -n "$window_time_remaining" ]; then
    status_line="${status_line} | ${window_time_remaining}"
fi

# サンドボックス有効時にマーカーを付加
if [ "$sandbox_enabled" = "true" ]; then
    status_line="${status_line} | SBX"
fi

# Output status line
echo -e "$status_line"
