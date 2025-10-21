#!/bin/bash

# Constants
CONTEXT_WINDOW_SIZE=200000  # 200k tokens total context window

# Read JSON from stdin
input=$(cat)

# Extract values using jq
model=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
current_dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // "."' | xargs basename)
session_id=$(echo "$input" | jq -r '.session_id // ""')

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
                # Calculate context length: input_tokens + cache_read + cache_creation
                # (output_tokens are NOT included as they represent the response, not context)
                input_tokens=$(echo "$most_recent" | jq '.message.usage.input_tokens // 0')
                cache_creation=$(echo "$most_recent" | jq '.message.usage.cache_creation_input_tokens // 0')
                cache_read=$(echo "$most_recent" | jq '.message.usage.cache_read_input_tokens // 0')

                context_length=$((input_tokens + cache_creation + cache_read))
            fi
        fi
    fi
fi

# Calculate percentage (with decimal precision) - based on 200k context window
if [ $context_length -gt 0 ]; then
    percentage=$(echo "scale=1; $context_length * 100 / $CONTEXT_WINDOW_SIZE" | bc)
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

# Output status line
echo -e "$status_line"
