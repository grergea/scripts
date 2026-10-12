#!/usr/bin/env bash
# PFX(PKCS#12) 파일을 cert/key/chain PEM 3종으로 분리한다.
# 사용법: ssl_pfx2pem.sh <파일명>.pfx
# 환경변수 PFXPASS가 설정되어 있으면 비밀번호 프롬프트를 건너뛴다.
# bash와 zsh 모두에서 동작하도록 셸 고유 문법(단어 분리, read -s, 파라미터 확장 플래그)을 쓰지 않는다.

set -u

pfx="${1:-}"

if [ -z "$pfx" ]; then
    echo "사용법: ssl_pfx2pem.sh <파일명>.pfx" >&2
    exit 1
fi

if [ ! -f "$pfx" ]; then
    echo "파일을 찾을 수 없습니다: $pfx" >&2
    exit 1
fi

file="$(basename "$pfx")"
base="${file%.*}"
dir="$(dirname "$pfx")"
cert_out="${dir}/${base}_cert.pem"
key_out="${dir}/${base}_key.pem"
chain_out="${dir}/${base}_chain.pem"

# 출력 파일을 noclobber(O_EXCL)로 선점한다. 존재 확인과 쓰기 사이의 경합(TOCTOU)과
# 심볼릭 링크 경유 쓰기를 막는다. openssl -out은 셸 리다이렉션이 아니므로 set -C가
# 직접 적용되지 않아 빈 파일을 먼저 만들어 두는 방식을 쓴다.
claim() {
    (set -C; umask 077; : > "$1") 2>/dev/null
}

exists_abort() {
    echo "이미 존재하는 파일입니다: $1 (덮어쓰지 않고 중단)" >&2
    exit 1
}

claim "$cert_out" || exists_abort "$cert_out"
claim "$key_out" || { rm -f "$cert_out"; exists_abort "$key_out"; }
claim "$chain_out" || { rm -f "$cert_out" "$key_out"; exists_abort "$chain_out"; }

if [ -z "${PFXPASS:-}" ]; then
    printf "PFX Import Password: " >&2
    if [ -t 0 ]; then
        stty -echo
        IFS= read -r PFXPASS
        stty echo
        echo >&2
    else
        IFS= read -r PFXPASS
    fi
fi
export PFXPASS

# OpenSSL 3.x는 구형 RC2-40-CBC/3DES로 암호화된 PFX를 기본 provider로 열지 못하므로 legacy provider 병행 시도
use_legacy=0
if ! openssl pkcs12 -in "$pfx" -clcerts -nokeys -passin env:PFXPASS -out "$cert_out" 2>/dev/null; then
    use_legacy=1
    if ! openssl pkcs12 -in "$pfx" -clcerts -nokeys -legacy -passin env:PFXPASS -out "$cert_out" 2>/dev/null; then
        rm -f "$cert_out" "$key_out" "$chain_out"
        echo "인증서 추출 실패 (비밀번호를 확인하세요)" >&2
        exit 1
    fi
fi

# $1: 출력 파일, 나머지: openssl 추가 옵션. use_legacy=1이면 -legacy를 붙인다.
p12_extract() {
    out="$1"
    shift
    if [ "$use_legacy" = 1 ]; then
        openssl pkcs12 -in "$pfx" "$@" -legacy -passin env:PFXPASS -out "$out" 2>/dev/null
    else
        openssl pkcs12 -in "$pfx" "$@" -passin env:PFXPASS -out "$out" 2>/dev/null
    fi
}

(umask 077; p12_extract "$key_out" -nocerts -nodes)
p12_extract "$chain_out" -cacerts -nokeys -chain
chmod 600 "$key_out" 2>/dev/null
chmod 644 "$cert_out" "$chain_out" 2>/dev/null

echo
echo "=== 변환 완료 ==="
printf "%-10s : %s\n" "인증서" "$cert_out"
printf "%-10s : %s\n" "개인키" "$key_out"

if [ -s "$chain_out" ]; then
    printf "%-10s : %s\n" "체인" "$chain_out"
else
    rm -f "$chain_out"
fi

echo
echo "⚠️  개인키 파일은 암호화되지 않았습니다. 안전하게 보관/삭제하세요."
