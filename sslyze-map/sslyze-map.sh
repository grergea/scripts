#!/usr/bin/env bash
#
# sslyze-map.sh - sslyze 결과를 IANA / OpenSSL 표기로 골라서 출력
#
# sslyze의 사람이 읽는 출력은 IANA 표기로 고정되어 있어 서버 설정 문자열
# (OpenSSL 축약 표기)과 대조하기 불편하다. JSON 결과에 두 표기가 모두
# 들어 있으므로 원하는 쪽만 뽑아 출력한다.

set -eo pipefail

MAPPING="both"

usage() {
  cat <<'EOF'
사용법: sslyze-map.sh [--mapping both|iana|openssl] <sslyze 옵션/대상...>

  --mapping both      OpenSSL 축약 표기와 IANA 표기를 함께 출력 (기본값)
  --mapping openssl   OpenSSL 축약 표기만 출력 (서버 설정과 대조할 때)
  --mapping iana      IANA 표기만 출력 (sslyze 기본 출력과 동일한 표기)

--mapping 외의 인자는 sslyze로 그대로 전달된다.
버전 플래그(--tlsv1_2 등)를 하나 이상 지정해야 cipher가 열거된다.
--mozilla_config disable 과 --json_out - 는 자동으로 붙는다.

예시:
  sslyze-map.sh --mapping openssl --tlsv1_2 --tlsv1_3 www.example.com
  sslyze-map.sh --sslv2 --sslv3 --tlsv1 --tlsv1_1 --tlsv1_2 --tlsv1_3 www.example.com
  sslyze-map.sh --mapping iana --tlsv1_2 "img.example.com:443{61.110.192.38}"
EOF
}

args=()
while [ $# -gt 0 ]; do
  case "$1" in
    --mapping)
      MAPPING="$2"
      shift 2
      ;;
    --mapping=*)
      MAPPING="${1#--mapping=}"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      args+=("$1")
      shift
      ;;
  esac
done

case "$MAPPING" in
  both|iana|openssl) ;;
  *)
    echo "오류: --mapping 은 both, iana, openssl 중 하나여야 합니다 (입력값: $MAPPING)" >&2
    exit 1
    ;;
esac

if [ ${#args[@]} -eq 0 ]; then
  usage >&2
  exit 1
fi

for cmd in sslyze jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "오류: $cmd 가 설치되어 있지 않습니다." >&2
    exit 1
  fi
done

sslyze --mozilla_config disable --json_out - "${args[@]}" | jq -r --arg mapping "$MAPPING" '
  def verlabel:
    sub("_cipher_suites$"; "") | ascii_upcase | gsub("_"; ".")
    | sub("^SSL\\."; "SSL ") | sub("^TLS\\."; "TLS ");

  def pad($n): . + (" " * ($n - length) | if . == null then "" else . end);

  .server_scan_results[]
  | .server_location as $loc
  | "[\($loc.hostname):\($loc.port)\(if $loc.ip_address then " -> " + $loc.ip_address else "" end)]",
    ( .scan_result
      | to_entries[]
      | select(.key | endswith("cipher_suites"))
      | select(.value.status == "COMPLETED")
      | (.key | verlabel) as $ver
      | .value.result
      | (.accepted_cipher_suites | length) as $ok
      | (($ok + (.rejected_cipher_suites | length))) as $tried
      | if $ok == 0 then
          "", "\($ver)  (\($tried)개 시도, 전부 거부)"
        else
          ( "", "\($ver)  (\($tried)개 시도, \($ok)개 수락)",
            ( .accepted_cipher_suites[]
              | .cipher_suite as $c
              | "  " + ("\($c.key_size)" | pad(5))
                + ( if $mapping == "iana" then $c.name
                    elif $mapping == "openssl" then $c.openssl_name
                    else ($c.openssl_name | pad(32)) + $c.name
                    end )
            )
          )
        end
    )
'
