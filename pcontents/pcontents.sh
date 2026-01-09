#!/usr/bin/env bash

# 필수 패키지 확인
function check_pkgs() {
  for pkg in "$@"; do
    command -v "$pkg" >/dev/null 2>&1 || { echo >&2 "Error: $pkg is required."; exit 1; }
  done
}

check_pkgs "curl" "parallel" "md5sum" "column" "awk"

# 기본 설정 및 임계값
DEFAULT_NODES="119.206.198.2 119.206.198.3 119.206.198.4 119.206.198.5 119.206.198.6 14.0.111.2 14.0.111.3 14.0.111.4 14.0.111.5 14.0.111.6"
TIME_WARN=3.00    # 노란색 표시 기준 (초)
TIME_CRITICAL=10.00 # 빨간색 표시 기준 (초)

# ANSI 색상 코드
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color (색상 초기화)

JOBS="3"
URL=""
NODE_LIST=""
export GLOBAL_HEADER=""
export TIME_WARN TIME_CRITICAL RED GREEN YELLOW NC # 함수 내부 사용을 위해 export

# 구분선 함수
function _line() {
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
}

# 옵션 파싱
while getopts 'ol:H:P:' OPTION
do
  case $OPTION in
    H ) export GLOBAL_HEADER="$OPTARG" ;;
    P ) JOBS=$OPTARG ;;
    l ) IFS=', ' read -r -a NODE_ARRAY <<< "$OPTARG"
        NODE_LIST="${NODE_ARRAY[*]}"
        ;;
    o ) NODE_LIST="$DEFAULT_NODES" ;;
  esac
done
shift $((OPTIND -1))

URL="$1"

if [[ -z "$URL" ]]; then
    echo "Usage: $0 [-o] [-l nodes] [-H 'Header: Value'] [-P jobs] <URL>"
    exit 1
fi

# URL 파싱
protocol=${URL%%://*}
temp=${URL#*://}
domain_port=${temp%%/*}
domain=${domain_port%%:*}
port=${domain_port##*:}

if [[ "$domain" == "$port" ]]; then
    if [[ "$protocol" == "https" ]]; then port=443; else port=80; fi
fi

echo
echo -e "Target URL    : ${GREEN}$URL${NC}"
echo "Target Domain : $domain ($port)"
[[ -n "$GLOBAL_HEADER" ]] && echo "Custom Header : $GLOBAL_HEADER"
echo "Parallel Jobs : $JOBS"
_line

# 작업 함수 정의
function do_probe() {
    local node=$1
    local url=$2
    local domain=$3
    local port=$4

    local header_tmp=$(mktemp)
    local body_tmp=$(mktemp)

    local curl_opts=(
        --connect-timeout 5
        -s -k "$url"
        --resolve "$domain:$port:$node"
        -D "$header_tmp"
        -o "$body_tmp"
        -w "%{http_code}|%{remote_ip}|%{http_version}|%{content_type}|%{size_download}|%{time_total}"
    )

    [[ -n "$GLOBAL_HEADER" ]] && curl_opts+=("-H" "$GLOBAL_HEADER")

    local stats
    stats=$(curl "${curl_opts[@]}")

    # 헤더 정보 추출
    local l_mod x_px cache_ctrl server_header
    l_mod=$(grep -i "^Last-Modified:" "$header_tmp" | cut -d: -f2- | sed 's/^[ \t]*//' | tr -d '\r')
    x_px=$(grep -i "^X-Px:" "$header_tmp" | cut -d: -f2- | sed 's/^[ \t]*//' | tr -d '\r')
    cache_ctrl=$(grep -i "^Cache-Control:" "$header_tmp" | cut -d: -f2- | sed 's/^[ \t]*//' | tr -d '\r')
    server_header=$(grep -i "^Server:" "$header_tmp" | cut -d: -f2- | sed 's/^[ \t]*//' | tr -d '\r')

    [[ -z "$l_mod" ]] && l_mod="-"
    [[ -z "$x_px" ]] && x_px="-"
    [[ -z "$cache_ctrl" ]] && cache_ctrl="-"
    [[ -z "$server_header" ]] && server_header="-"

    # MD5 계산
    local md5
    if [[ -s "$body_tmp" ]]; then
        md5=$(md5sum "$body_tmp" | awk '{print $1}')
    else
        md5="failed"
    fi

    IFS='|' read -r code ip version type size time <<< "$stats"

    # --- 색상 로직 적용 ---

    # 1. 응답 코드 색상 (200, 206은 초록, 나머지는 빨강)
    local code_color=$NC
    if [[ "$code" == "200" || "$code" == "206" ]]; then
        code_color=$GREEN
    else
        code_color=$RED
    fi
    local display_code="${code_color}${code}${NC}"

    # 2. DL_Time 색상 (awk를 사용하여 소수점 비교)
    local time_color=$NC
    if [ -n "$time" ]; then
        time_color=$(awk -v t="$time" -v w="$TIME_WARN" -v c="$TIME_CRITICAL" 'BEGIN {
            if (t >= c) print "'$RED'";
            else if (t >= w) print "'$YELLOW'";
            else print "'$NC'";
        }')
        time=$(printf "%.2f" "$time")
    fi
    local display_time="${time_color}${time}${NC}"

    # HTTP Version 포맷팅
    local display_ver="-"
    if [[ -n "$version" ]]; then
        [[ "$version" == "2" ]] && version="2.0"
        [[ "$version" == "3" ]] && version="3.0"
        display_ver="H/$version"
    fi

    # 최종 출력 (column 명령어 호환을 위해 탭/공백 유지)
    echo -e "$display_code | $ip | $display_ver | $type | $l_mod | $cache_ctrl | $size | $display_time | $x_px | $server_header | $md5"

    rm -f "$header_tmp" "$body_tmp"
}

export -f do_probe

# 결과 출력
echo "CODE | Remote_IP | Version | Content-Type | Last-Modified | Cache-Control | DL_Size | DL_Time | X-Px | Server | MD5" > output.buffer

# Parallel 실행
echo "$NODE_LIST" | tr ' ' '\n' | parallel -j "$JOBS" do_probe {} "$URL" "$domain" "$port" >> output.buffer

# 결과 정렬 출력
cat output.buffer | column -t -s '|'
rm -f output.buffer

echo
