#!/bin/bash
input=$(cat)

YEL='\033[33m'
GRN='\033[92m'
PNK='\033[91m'
PUR='\033[95m'
WHT='\033[97m'
GRY='\033[90m'
RST='\033[0m'

model=$(echo "$input" | jq -r '.model.display_name // empty')
ctx_remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
cost=$(echo "$input"  | jq -r '.cost.total_cost_usd // empty')
five=$(echo "$input"  | jq -r '.rate_limits.five_hour.used_percentage // empty')
seven=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
effort=$(echo "$input" | jq -r '.effort.level // empty')
cwd=$(echo "$input"   | jq -r '.cwd // empty')

sep="${GRY} | ${RST}"
out=""
add() { [ -z "$out" ] && out="$1" || out="${out}${sep}$1"; }

[ -n "$model" ] && add "${YEL}${model}${RST}"

if [ -n "$ctx_remaining" ]; then
    ctx_used=$(awk "BEGIN{printf \"%.0f\", 100 - $ctx_remaining}")
    add "${GRN}ctx:${ctx_used}%${RST}"
fi

# Only show cost when > 0
if [ -n "$cost" ] && awk "BEGIN{exit !($cost > 0)}"; then
    add "${GRN}\$$(printf '%.4f' "$cost")${RST}"
fi

if [ -n "$five" ] || [ -n "$seven" ]; then
    rate=""
    [ -n "$five"  ] && rate+="5h:$(printf '%.0f' "$five")%"
    [ -n "$seven" ] && rate+=" 7d:$(printf '%.0f' "$seven")%"
    add "${PNK}${rate# }${RST}"
fi

[ -n "$effort" ] && add "${PUR}${effort}${RST}"

# CWD from JSON, normalize backslashes, show last 3 components
if [ -n "$cwd" ]; then
    cwd_norm=$(echo "$cwd" | tr '\\' '/')
    cwd_trim=$(echo "$cwd_norm" | awk -F'/' '{
        if (NF > 4) printf "/%s/%s/%s", $(NF-2), $(NF-1), $NF
        else print $0
    }')
    add "${WHT}${cwd_trim}${RST}"
fi

printf "%b\n" "$out"
