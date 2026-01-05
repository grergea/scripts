#!/usr/bin/env bash

# Script configuration
SCRIPT_NAME="$(basename "$0")"
CACHE_DIR="${HOME}/.cache/gdig"
CACHE_FILE="${CACHE_DIR}/servers_cache.json"
RESULT_FILE="${CACHE_DIR}/results_$$.tmp"
CACHE_EXPIRY=86400  # 24 hours in seconds
CURL_TIMEOUT=10
CURL_RETRY=2

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Table column widths (dynamic based on terminal width)
# Priority: GDIG_WIDTH env > stty > tput > COLUMNS > default 160
function get_term_width() {
  if [ -n "$GDIG_WIDTH" ]; then
    echo "$GDIG_WIDTH"
  elif [ -t 0 ]; then
    # Interactive terminal - try stty first
    stty size 2>/dev/null </dev/tty | awk '{print $2}' | grep -E '^[0-9]+$' || \
    tput cols 2>/dev/null </dev/tty || \
    echo "${COLUMNS:-160}"
  else
    # Non-interactive - use COLUMNS or default
    echo "${COLUMNS:-160}"
  fi
}
TERM_WIDTH=$(get_term_width)
[ "$TERM_WIDTH" -lt 80 ] && TERM_WIDTH=160  # Fallback if too small

# Distribute columns proportionally: Server 35%, Provider 15%, Response 50%
COL_SERVER=$(( (TERM_WIDTH - 4) * 35 / 100 ))
COL_PROVIDER=$(( (TERM_WIDTH - 4) * 15 / 100 ))
COL_RESPONSE=$(( TERM_WIDTH - COL_SERVER - COL_PROVIDER - 4 ))
# Minimum widths
[ $COL_SERVER -lt 25 ] && COL_SERVER=25
[ $COL_PROVIDER -lt 15 ] && COL_PROVIDER=15
[ $COL_RESPONSE -lt 40 ] && COL_RESPONSE=40

function cleanup() {
  rm -f "$RESULT_FILE" 2>/dev/null
}
trap cleanup EXIT

function check_pkgs() {
  local missing_pkgs=()
  for pkg in "$@"; do
    if ! command -v "$pkg" >/dev/null 2>&1; then
      missing_pkgs+=("$pkg")
    fi
  done

  if [ ${#missing_pkgs[@]} -gt 0 ]; then
    echo -e "${RED}Error: Missing required packages: ${missing_pkgs[*]}${NC}" >&2
    echo "Please install the missing packages and try again." >&2
    exit 1
  fi
}
check_pkgs "curl" "jq" "dig" "parallel"

function usage() {
  echo "Usage: $SCRIPT_NAME <type> <domain> [country]"
  echo ""
  echo "Arguments:"
  echo "  type      DNS record type (A, AAAA, CNAME, MX, NS, TXT, SOA, etc.)"
  echo "  domain    Domain name to query"
  echo "  country   (Optional) Two-letter country code to filter servers"
  echo ""
  echo "Examples:"
  echo "  $SCRIPT_NAME a www.example.com"
  echo "  $SCRIPT_NAME aaaa www.example.com kr"
  echo "  $SCRIPT_NAME mx example.com us"
  echo ""
  echo "Options:"
  echo "  --list-countries    Show available country codes"
  echo "  --clear-cache       Clear the server cache"
  echo "  --help             Show this help message"
  exit 1
}

function list_countries() {
  echo "Available country codes (from whatsmydns.net API):"
  echo "  AU - Australia"
  echo "  BR - Brazil"
  echo "  CA - Canada"
  echo "  CN - China"
  echo "  DE - Germany"
  echo "  ES - Spain"
  echo "  FR - France"
  echo "  GB - United Kingdom"
  echo "  IN - India"
  echo "  KR - South Korea"
  echo "  MX - Mexico"
  echo "  MY - Malaysia"
  echo "  NL - Netherlands"
  echo "  PK - Pakistan"
  echo "  RU - Russia"
  echo "  SG - Singapore"
  echo "  TH - Thailand"
  echo "  TR - Turkey"
  echo "  US - United States"
  echo "  ZA - South Africa"
  exit 0
}

function clear_cache() {
  if [ -f "$CACHE_FILE" ]; then
    rm -f "$CACHE_FILE"
    echo "Cache cleared successfully."
  else
    echo "No cache file found."
  fi
  exit 0
}

# Handle options
case "${1:-}" in
  --list-countries)
    list_countries
    ;;
  --clear-cache)
    clear_cache
    ;;
  --help)
    usage
    ;;
esac

[ $# -lt 2 ] && usage

TYPE=${1^^}
DOMAIN=${2}
COUNTRY=${3^^}

function draw_table_header() {
  printf "+%-${COL_SERVER}s+%-${COL_PROVIDER}s+%-${COL_RESPONSE}s+\n" \
    "$(printf '%*s' $COL_SERVER '' | tr ' ' '-')" \
    "$(printf '%*s' $COL_PROVIDER '' | tr ' ' '-')" \
    "$(printf '%*s' $COL_RESPONSE '' | tr ' ' '-')"
  printf "| ${BOLD}%-$((COL_SERVER-1))s${NC}| ${BOLD}%-$((COL_PROVIDER-1))s${NC}| ${BOLD}%-$((COL_RESPONSE-1))s${NC}|\n" \
    "DNS Server" "Provider" "Response"
  printf "+%-${COL_SERVER}s+%-${COL_PROVIDER}s+%-${COL_RESPONSE}s+\n" \
    "$(printf '%*s' $COL_SERVER '' | tr ' ' '-')" \
    "$(printf '%*s' $COL_PROVIDER '' | tr ' ' '-')" \
    "$(printf '%*s' $COL_RESPONSE '' | tr ' ' '-')"
}

function draw_table_footer() {
  printf "+%-${COL_SERVER}s+%-${COL_PROVIDER}s+%-${COL_RESPONSE}s+\n" \
    "$(printf '%*s' $COL_SERVER '' | tr ' ' '-')" \
    "$(printf '%*s' $COL_PROVIDER '' | tr ' ' '-')" \
    "$(printf '%*s' $COL_RESPONSE '' | tr ' ' '-')"
}

function draw_table_row() {
  local server="$1"
  local provider="$2"
  local response="$3"
  local color="${4:-$NC}"
  local max_resp_width=$((COL_RESPONSE - 2))

  # Truncate server/provider if needed
  [ ${#server} -gt $((COL_SERVER-2)) ] && server="${server:0:$((COL_SERVER-5))}..."
  [ ${#provider} -gt $((COL_PROVIDER-2)) ] && provider="${provider:0:$((COL_PROVIDER-5))}..."

  # Handle multi-line response
  if [ ${#response} -le $max_resp_width ]; then
    printf "| %-$((COL_SERVER-1))s| %-$((COL_PROVIDER-1))s| ${color}%-$((COL_RESPONSE-1))s${NC}|\n" \
      "$server" "$provider" "$response"
  else
    # First line with server and provider
    local first_part="${response:0:$max_resp_width}"
    printf "| %-$((COL_SERVER-1))s| %-$((COL_PROVIDER-1))s| ${color}%-$((COL_RESPONSE-1))s${NC}|\n" \
      "$server" "$provider" "$first_part"

    # Remaining lines (continuation)
    local remaining="${response:$max_resp_width}"
    while [ -n "$remaining" ]; do
      local chunk="${remaining:0:$max_resp_width}"
      remaining="${remaining:$max_resp_width}"
      printf "| %-$((COL_SERVER-1))s| %-$((COL_PROVIDER-1))s| ${color}%-$((COL_RESPONSE-1))s${NC}|\n" \
        "" "" "$chunk"
    done
  fi
}

function draw_section_divider() {
  local title="$1"
  local total_width=$((COL_SERVER + COL_PROVIDER + COL_RESPONSE + 2))
  printf "+%-${COL_SERVER}s+%-${COL_PROVIDER}s+%-${COL_RESPONSE}s+\n" \
    "$(printf '%*s' $COL_SERVER '' | tr ' ' '-')" \
    "$(printf '%*s' $COL_PROVIDER '' | tr ' ' '-')" \
    "$(printf '%*s' $COL_RESPONSE '' | tr ' ' '-')"
  printf "| ${CYAN}%-$((total_width - 2))s${NC} |\n" "$title"
  printf "+%-${COL_SERVER}s+%-${COL_PROVIDER}s+%-${COL_RESPONSE}s+\n" \
    "$(printf '%*s' $COL_SERVER '' | tr ' ' '-')" \
    "$(printf '%*s' $COL_PROVIDER '' | tr ' ' '-')" \
    "$(printf '%*s' $COL_RESPONSE '' | tr ' ' '-')"
}

function _myip() {
  local result
  result=$(curl --keepalive-time 1 --max-time "$CURL_TIMEOUT" --retry "$CURL_RETRY" -s https://api.myip.com 2>/dev/null)
  if [ $? -eq 0 ] && [ -n "$result" ]; then
    echo "$result" | jq -r '"\(.ip) (\(.country))"' 2>/dev/null || echo "N/A"
  else
    echo "N/A"
  fi
}

function dns_check() {
  local server=$1
  local result_file=$2
  IFS=':' read -r id country location provider <<< "$server"

  if [[ -z "$id" || -z "$country" || -z "$location" || -z "$provider" ]]; then
    return 1
  fi

  local result
  result=$(curl --keepalive-time 1 --max-time "$CURL_TIMEOUT" --retry "$CURL_RETRY" -s \
    "https://www.whatsmydns.net/api/details?server=$id&type=$TYPE&query=$DOMAIN" \
    -H 'x-requested-with: XMLHttpRequest' 2>/dev/null)

  local display_location="${location//_/ }"
  local display_provider="${provider//_/ }"
  local server_info="[${country^^}] $display_location"

  if [[ -n "$result" ]] && echo "$result" | jq empty 2>/dev/null; then
    local responses
    responses=$(echo "$result" | jq -r '.data[].response[]?' 2>/dev/null | tr '\n' ' ' | sed 's/ $//')

    if [[ -n "$responses" ]]; then
      echo "OK|$server_info|$display_provider|$responses" >> "$result_file"
    else
      echo "EMPTY|$server_info|$display_provider|No data" >> "$result_file"
    fi
  else
    echo "ERROR|$server_info|$display_provider|Request failed" >> "$result_file"
  fi
}

function parallel_dns_checks() {
  local servers="$1"
  export -f dns_check
  export TYPE DOMAIN CURL_TIMEOUT CURL_RETRY

  local nproc_count
  nproc_count=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

  : > "$RESULT_FILE"
  echo "$servers" | parallel -j "$nproc_count" -N 1 dns_check {} "$RESULT_FILE"
}

function local_lookup() {
  local dns_server=$1
  local provider=$2

  local dig_result
  dig_result=$(dig +short +time=5 +tries=2 @"$dns_server" "$TYPE" "$DOMAIN" 2>/dev/null | tr '\n' ' ' | sed 's/ $//')

  if [ -n "$dig_result" ]; then
    draw_table_row "$dns_server" "$provider" "$dig_result" "$GREEN"
  else
    draw_table_row "$dns_server" "$provider" "No response" "$YELLOW"
  fi
}

function get_api_servers() {
  local api_response
  api_response=$(curl --max-time "$CURL_TIMEOUT" --retry "$CURL_RETRY" -s https://www.whatsmydns.net/api/servers 2>/dev/null)

  if [ $? -eq 0 ] && [ -n "$api_response" ] && echo "$api_response" | jq empty 2>/dev/null; then
    echo "$api_response" | jq -r '.[] | "\(.id):\(.country):\(.location):\(.provider)"' | tr ' ' '_'
  else
    echo -e "${YELLOW}Warning: API server list unavailable${NC}" >&2
    return 1
  fi
}

function get_cached_servers() {
  if [ -f "$CACHE_FILE" ]; then
    local cache_age=$(( $(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0) ))
    if [ "$cache_age" -lt "$CACHE_EXPIRY" ]; then
      cat "$CACHE_FILE"
      return 0
    fi
  fi
  return 1
}

function save_cache() {
  mkdir -p "$CACHE_DIR"
  echo "$1" > "$CACHE_FILE"
}

function print_summary() {
  local total=$1
  local success=$2
  local unique_ips=$3

  echo ""
  echo -e "${BOLD}Summary:${NC} $total servers queried | $success successful | $unique_ips unique responses"
}

# ============ Main Execution ============

# Get servers from cache or API
API_SERVERS=""
if ! API_SERVERS=$(get_cached_servers); then
  if API_SERVERS=$(get_api_servers); then
    save_cache "$API_SERVERS"
  fi
fi

ALL_SERVERS="${API_SERVERS}"
UNIQUE_SERVERS=$(echo "$ALL_SERVERS" | grep -v '^$' | sort -t: -k1,1 -u)

# Filter by country if specified
if [ -n "$COUNTRY" ]; then
  FILTERED_SERVERS=$(echo "$UNIQUE_SERVERS" | grep -i ":${COUNTRY}:")
  if [ -z "$FILTERED_SERVERS" ]; then
    echo -e "${RED}No servers found for country code: $COUNTRY${NC}"
    echo "Use --list-countries to see available country codes"
    exit 1
  fi
  DNS_SERVERS="$FILTERED_SERVERS"
else
  DNS_SERVERS="$UNIQUE_SERVERS"
fi

# Print header
echo ""
echo "Global DNS Checker - $DOMAIN ($TYPE)"
echo ""
echo -e "  ${BOLD}Query:${NC}   $TYPE record for $DOMAIN"
[ -n "$COUNTRY" ] && echo -e "  ${BOLD}Filter:${NC}  Country = $COUNTRY"
echo -e "  ${BOLD}Source:${NC}  whatsmydns.net API"
echo ""

# Run parallel DNS checks
parallel_dns_checks "$DNS_SERVERS"

# Display results in table
draw_table_header

# Process and display results
declare -A unique_responses
total_count=0
success_count=0

if [ -f "$RESULT_FILE" ]; then
  while IFS='|' read -r status server provider response; do
    ((total_count++))
    case "$status" in
      OK)
        ((success_count++))
        draw_table_row "$server" "$provider" "$response" "$GREEN"
        # Track unique IPs
        for ip in $(echo "$response" | tr ',' '\n'); do
          unique_responses["$ip"]=1
        done
        ;;
      EMPTY)
        draw_table_row "$server" "$provider" "$response" "$YELLOW"
        ;;
      ERROR)
        draw_table_row "$server" "$provider" "$response" "$RED"
        ;;
    esac
  done < <(sort -t'|' -k2 "$RESULT_FILE")
fi

# Local DNS lookup section
LOCAL_LOOKUP="1.1.1.1:Cloudflare-1 1.0.0.1:Cloudflare-2 208.67.222.222:OpenDNS-1 208.67.220.220:OpenDNS-2 8.8.8.8:Google-1 8.8.4.4:Google-2 219.250.36.130:SKT-1 210.220.163.82:SKT-2 168.126.63.1:KT-1 168.126.63.2:KT-2 164.124.101.2:LG-1 203.248.252.2:LG-2"

if [[ "${COUNTRY,,}" == "kr" ]] || [[ -z "$COUNTRY" ]]; then
  local_ip=$(_myip)
  draw_section_divider "Local DNS (Your IP: $local_ip)"

  for list in $LOCAL_LOOKUP; do
    IFS=':' read -r dns_server prod_name <<< "$list"
    local_lookup "$dns_server" "$prod_name"
    ((total_count++))
  done
fi

draw_table_footer

# Print summary
print_summary "$total_count" "$success_count" "${#unique_responses[@]}"

echo ""
echo -e "${GREEN}DNS check completed successfully${NC}"
