#!/usr/bin/env bash

# Script configuration
SCRIPT_NAME="$(basename "$0")"
CACHE_DIR="${HOME}/.cache/gdig"
CACHE_FILE="${CACHE_DIR}/servers_cache.json"
RESULT_FILE="${CACHE_DIR}/results_$$.tmp"
CACHE_EXPIRY=86400  # 24 hours
CURL_TIMEOUT=10
CURL_RETRY=2
CURL_HEADERS=(
  -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'
  -H 'Accept: application/json'
  -H 'Referer: https://www.whatsmydns.net/'
)

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Check dependencies
function check_pkgs() {
  local missing_pkgs=()
  for pkg in curl jq dig xargs fold; do
    if ! command -v "$pkg" >/dev/null 2>&1; then
      missing_pkgs+=("$pkg")
    fi
  done

  if [ ${#missing_pkgs[@]} -gt 0 ]; then
    echo -e "${RED}Error: Missing required packages: ${missing_pkgs[*]}${NC}" >&2
    exit 1
  fi
}
check_pkgs

# --- Terminal & Layout Calculation ---
function get_term_width() {
  if [ -n "$GDIG_WIDTH" ]; then echo "$GDIG_WIDTH"; return; fi
  if [ -t 0 ]; then
    tput cols 2>/dev/null || echo "${COLUMNS:-160}"
  else
    echo "${COLUMNS:-160}"
  fi
}

TERM_WIDTH=$(get_term_width)
[ "$TERM_WIDTH" -lt 100 ] && TERM_WIDTH=100

# Calculate Column Widths
COL_SERVER=$(( (TERM_WIDTH - 4) * 25 / 100 ))
COL_PROVIDER=$(( (TERM_WIDTH - 4) * 15 / 100 ))
COL_RESPONSE=$(( TERM_WIDTH - COL_SERVER - COL_PROVIDER - 4 ))

# Safety Minimums
[ $COL_SERVER -lt 20 ] && COL_SERVER=20
[ $COL_PROVIDER -lt 12 ] && COL_PROVIDER=12
[ $COL_RESPONSE -lt 40 ] && COL_RESPONSE=40

# --- Helper Functions for Drawing ---

function draw_separator() {
  local s_line p_line r_line
  printf -v s_line '%*s' "$COL_SERVER" ''; s_line=${s_line// /-}
  printf -v p_line '%*s' "$COL_PROVIDER" ''; p_line=${p_line// /-}
  printf -v r_line '%*s' "$COL_RESPONSE" ''; r_line=${r_line// /-}
  
  printf "+%s+%s+%s+\n" "$s_line" "$p_line" "$r_line"
}

function draw_header() {
  draw_separator
  printf "| ${BOLD}%-$(($COL_SERVER - 1))s${NC}| ${BOLD}%-$(($COL_PROVIDER - 1))s${NC}| ${BOLD}%-$(($COL_RESPONSE - 1))s${NC}|\n" \
    "DNS Server" "Provider" "Response"
  draw_separator
}

function wrap_text_to_array() {
    local text="$1"
    local width="$2"
    local -n arr_ref="$3"

    if [ -z "$text" ]; then
        arr_ref+=("")
        return
    fi
    while IFS= read -r line; do
        arr_ref+=("$line")
    done < <(echo "$text" | fold -s -w "$width")
}

function wrap_response_to_array() {
    local text="$1"
    local width="$2"
    local -n arr_ref="$3"

    # Split by comma (internal format), output with Space
    IFS=',' read -ra ADDR <<< "$text"
    local current_line=""
    
    for addr in "${ADDR[@]}"; do
        addr=$(echo "$addr" | xargs) # trim
        [ -z "$addr" ] && continue

        local needed_len=${#addr}
        [ -n "$current_line" ] && ((needed_len++)) # +1 for SPACE

        if [ $(( ${#current_line} + needed_len )) -gt "$width" ]; then
            if [ -n "$current_line" ]; then
                arr_ref+=("$current_line")
            fi
            current_line="$addr"
        else
            if [ -z "$current_line" ]; then
                current_line="$addr"
            else
                current_line="$current_line $addr" # Use SPACE separator
            fi
        fi
    done
    
    if [ -n "$current_line" ]; then
        arr_ref+=("$current_line")
    fi
    if [ ${#arr_ref[@]} -eq 0 ]; then arr_ref+=("No data"); fi
}

function draw_row() {
  local server="$1"
  local provider="$2"
  local response="$3"
  local color="${4:-$NC}"
  
  local s_lines=()
  local p_lines=()
  local r_lines=()

  wrap_text_to_array "$server" $((COL_SERVER - 1)) s_lines
  wrap_text_to_array "$provider" $((COL_PROVIDER - 1)) p_lines
  wrap_response_to_array "$response" $((COL_RESPONSE - 1)) r_lines

  local max_h=${#s_lines[@]}
  [ ${#p_lines[@]} -gt $max_h ] && max_h=${#p_lines[@]}
  [ ${#r_lines[@]} -gt $max_h ] && max_h=${#r_lines[@]}

  for ((i=0; i<max_h; i++)); do
    local s_str="${s_lines[$i]:-}"
    local p_str="${p_lines[$i]:-}"
    local r_str="${r_lines[$i]:-}"
    
	printf "| %-$(($COL_SERVER - 1))s| %-$(($COL_PROVIDER - 1))s| ${color}%-$(($COL_RESPONSE - 1))s${NC}|\n" \
        "$s_str" "$p_str" "$r_str"
  done
  draw_separator
}

# --- Worker Function ---
function dns_worker() {
  local entry="$1"
  local type="$2"
  local domain="$3"
  local headers=(
    -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'
    -H 'Accept: application/json'
    -H 'Referer: https://www.whatsmydns.net/'
  )

  IFS='|' read -r id country location provider <<< "$entry"
  local server_info="[${country}] ${location}"
  local url="https://www.whatsmydns.net/api/details?server=$id&type=$type&query=$domain"

  local result
  result=$(curl --keepalive-time 1 --max-time 10 --retry 2 -s "${headers[@]}" -H 'x-requested-with: XMLHttpRequest' "$url")

  if [[ -n "$result" ]] && echo "$result" | jq -e . >/dev/null 2>&1; then
    local responses
    # Keep internal data comma-separated
    responses=$(echo "$result" | jq -r '.data[].response[]?' 2>/dev/null | tr '\n' ',' | sed 's/,$//')
    responses=$(echo "$responses" | sed 's/, /,/g')

    if [[ -n "$responses" ]]; then
      echo "OK|${server_info}|${provider}|${responses}"
    else
      echo "EMPTY|${server_info}|${provider}|No data"
    fi
  else
    echo "ERROR|${server_info}|${provider}|Request failed"
  fi
}
export -f dns_worker

# --- Local Lookup ---
function local_lookup() {
  local server_ip=$1
  local provider_name=$2
  local type=$3
  local domain=$4

  local dig_out
  dig_out=$(dig +noall +answer +time=2 +tries=1 @"$server_ip" "$type" "$domain" 2>/dev/null | \
    awk -v t="$type" '$4 == t {
      out=""; for(i=5;i<=NF;i++) out=out$i" "; sub(/ $/, "", out); print out
    }' | tr '\n' ',' | sed 's/,$//')

  if [ -n "$dig_out" ]; then
    draw_row "$server_ip" "$provider_name" "$dig_out" "$GREEN"
    ((SUCCESS_COUNT++))
    for ip in ${dig_out//,/ }; do UNIQUE_IPS["$ip"]=1; done
  else
    draw_row "$server_ip" "$provider_name" "No response" "$YELLOW"
  fi
  ((TOTAL_COUNT++))
}

# --- Main Logic ---
case "${1:-}" in
  --list-countries) echo "Codes: KR, US, JP, CN, etc."; exit 0 ;;
  --clear-cache) rm -f "$CACHE_FILE" && echo "Cache cleared."; exit 0 ;;
  --help) echo "Usage: $SCRIPT_NAME <type> <domain> [country]"; exit 0 ;;
esac

[ $# -lt 2 ] && { echo "Usage: $SCRIPT_NAME <type> <domain> [country]"; exit 1; }

TYPE=${1^^}
DOMAIN=${2}
COUNTRY=${3^^}

mkdir -p "$CACHE_DIR"
RAW_DATA=""

if [ -f "$CACHE_FILE" ]; then
    if date --version >/dev/null 2>&1; then mtime=$(date -r "$CACHE_FILE" +%s); else mtime=$(stat -f %m "$CACHE_FILE"); fi
    [ $(( $(date +%s) - mtime )) -lt $CACHE_EXPIRY ] && RAW_DATA=$(cat "$CACHE_FILE")
fi

if [ -z "$RAW_DATA" ] || ! echo "$RAW_DATA" | jq -e . >/dev/null 2>&1; then
    RAW_DATA=$(curl -s --max-time 10 "${CURL_HEADERS[@]}" https://www.whatsmydns.net/api/servers)
    echo "$RAW_DATA" | jq -e . >/dev/null 2>&1 && echo "$RAW_DATA" > "$CACHE_FILE"
fi

if [ -z "$RAW_DATA" ]; then echo -e "${RED}API Error.${NC}"; exit 1; fi

FILTERED_LIST=$(echo "$RAW_DATA" | jq -r --arg cc "$COUNTRY" \
  '.[] | select($cc == "" or (.country | ascii_upcase) == $cc) | "\(.id)|\(.country)|\(.location)|\(.provider)"' 2>/dev/null)

[ -z "$FILTERED_LIST" ] && { echo -e "${RED}No servers found for filter: $COUNTRY${NC}"; exit 1; }

echo ""
echo -e "Global DNS Checker: ${BOLD}$DOMAIN${NC} ($TYPE)"
[ -n "$COUNTRY" ] && echo -e "Region Filter: $COUNTRY"
echo ""

JOBS=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
JOBS=$((JOBS * 2))

: > "$RESULT_FILE"
echo "$FILTERED_LIST" | xargs -P "$JOBS" -I {} bash -c 'dns_worker "$@"' _ "{}" "$TYPE" "$DOMAIN" >> "$RESULT_FILE"

declare -A UNIQUE_IPS
TOTAL_COUNT=0
SUCCESS_COUNT=0

draw_header

if [ -f "$RESULT_FILE" ]; then
  while IFS='|' read -r status server provider response; do
    ((TOTAL_COUNT++))
    case "$status" in
      OK)
        ((SUCCESS_COUNT++))
        draw_row "$server" "$provider" "$response" "$GREEN"
        for ip in ${response//,/ }; do UNIQUE_IPS["$ip"]=1; done
        ;;
      EMPTY) draw_row "$server" "$provider" "$response" "$YELLOW" ;;
      ERROR) draw_row "$server" "$provider" "$response" "$RED" ;;
    esac
  done < <(sort -t'|' -k1,1r -k2 "$RESULT_FILE")
fi

if [[ "${COUNTRY}" == "KR" ]] || [[ -z "$COUNTRY" ]]; then
    MY_IP=$(curl -s --max-time 2 https://api.myip.com | jq -r '"\(.ip) (\(.country))"' 2>/dev/null)
    
    printf "| ${CYAN}%-$((COL_SERVER + COL_PROVIDER + COL_RESPONSE))s${NC}|\n" " Local Lookup (Client: ${MY_IP:-Unknown})"
    draw_separator

    LOCAL_SERVERS=(
        "1.1.1.1:Cloudflare-1" "1.0.0.1:Cloudflare-2"
        "8.8.8.8:Google-1" "8.8.4.4:Google-2"
        "219.250.36.130:SKT-1" "210.220.163.82:SKT-2"
        "168.126.63.1:KT-1" "168.126.63.2:KT-2"
        "164.124.101.2:LG-1" "203.248.252.2:LG-2"
    )

    for entry in "${LOCAL_SERVERS[@]}"; do
        local_lookup "${entry%%:*}" "${entry##*:}" "$TYPE" "$DOMAIN"
    done
fi

echo ""
echo -e "${BOLD}Summary:${NC} $TOTAL_COUNT queried | $SUCCESS_COUNT success | ${#UNIQUE_IPS[@]} unique IPs"
echo -e "${GREEN}Done.${NC}"
