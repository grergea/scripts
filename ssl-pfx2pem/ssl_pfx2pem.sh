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

# 비밀번호와 PFX 암호화 방식을 먼저 확인한다. 출력은 버리므로 이 단계에서는 파일이 만들어지지 않는다.
# OpenSSL 3.x는 구형 RC2-40-CBC/3DES로 암호화된 PFX를 기본 provider로 열지 못하므로 legacy provider 병행 시도
use_legacy=0
if ! openssl pkcs12 -in "$pfx" -clcerts -nokeys -passin env:PFXPASS >/dev/null 2>&1; then
    use_legacy=1
    if ! openssl pkcs12 -in "$pfx" -clcerts -nokeys -legacy -passin env:PFXPASS >/dev/null 2>&1; then
        echo "인증서 추출 실패 (비밀번호를 확인하세요)" >&2
        exit 1
    fi
fi

# openssl 출력을 -out 경로 대신 셸이 noclobber(O_EXCL)로 연 파일 디스크립터로 받는다.
# 존재 확인과 쓰기 사이의 경합(TOCTOU)과, 열린 뒤 경로가 심볼릭 링크로 바뀌는 경우를 모두 막는다.
# $1: 출력 파일, $2: umask, 나머지: openssl 추가 옵션
# 종료 코드: 0 성공, 90 이미 존재(또는 열기 실패), 91 openssl 실패
extract_excl() {
    out="$1"
    mask="$2"
    shift 2
    (
        set -C
        umask "$mask"
        exec 2>/dev/null >"$out" || exit 90
        if [ "$use_legacy" = 1 ]; then
            openssl pkcs12 -in "$pfx" "$@" -legacy -passin env:PFXPASS || exit 91
        else
            openssl pkcs12 -in "$pfx" "$@" -passin env:PFXPASS || exit 91
        fi
    ) 2>/dev/null
}

exists_abort() {
    echo "이미 존재하는 파일입니다: $1 (덮어쓰지 않고 중단)" >&2
    exit 1
}

# 셸에 따라 exec 리다이렉션 실패가 서브셸을 종료 코드 1로 끝내므로 1도 "이미 존재"로 취급한다.
extract_excl "$cert_out" 022 -clcerts -nokeys
rc=$?
if [ "$rc" = 91 ]; then
    rm -f "$cert_out"
    echo "인증서 추출 실패 (비밀번호를 확인하세요)" >&2
    exit 1
elif [ "$rc" != 0 ]; then
    exists_abort "$cert_out"
fi

extract_excl "$key_out" 077 -nocerts -nodes
rc=$?
if [ "$rc" = 91 ]; then
    rm -f "$cert_out" "$key_out"
    echo "개인키 추출 실패" >&2
    exit 1
elif [ "$rc" != 0 ]; then
    rm -f "$cert_out"
    exists_abort "$key_out"
fi

extract_excl "$chain_out" 022 -cacerts -nokeys -chain
rc=$?
if [ "$rc" = 91 ]; then
    rm -f "$chain_out"
elif [ "$rc" != 0 ]; then
    rm -f "$cert_out" "$key_out"
    exists_abort "$chain_out"
fi

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
