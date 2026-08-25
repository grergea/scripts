# gdig - Global DNS Checker

전 세계 DNS 서버에서 도메인 레코드를 조회하는 bash 스크립트입니다. [whatsmydns.net](https://www.whatsmydns.net) API를 활용합니다.

## Features

- **Parallel Processing**: xargs를 사용한 동시 DNS 쿼리 (외부 의존성 최소화)
- **Global Coverage**: 20개국 이상의 DNS 서버 조회
- **Local DNS Check**: Cloudflare, Google, 국내 ISP(SKT/KT/LG) DNS 서버 포함
- **Caching**: 24시간 DNS 서버 목록 캐시 (샘플을 누적 병합하여 조회 대상 서버를 확장)
- **Dynamic Table Output**: 터미널 너비에 맞게 자동 조정되는 컬럼
- **Country Filter**: 국가 코드로 결과 필터링
- **Color Output**: 결과 상태별 색상 구분 (성공/실패/빈 응답)

## Requirements

이 스크립트는 zsh 전용입니다(`#!/usr/bin/env zsh`).

```bash
# macOS (zsh 기본 탑재)
brew install curl jq bind

# Ubuntu/Debian (zsh 기본 미탑재, 별도 설치 필요)
sudo apt install curl jq dnsutils zsh
```

> **Note**: `xargs`, `fold`는 대부분의 시스템에 기본 포함되어 있습니다.

## Installation

```bash
# 저장소 클론
git clone https://github.com/grergea/scripts.git
cd scripts/gdig

# 실행 권한 부여
chmod +x gdig.sh

# (선택) PATH에 추가
sudo ln -s $(pwd)/gdig.sh /usr/local/bin/gdig
```

## Usage

```bash
./gdig.sh <type> <domain> [country] [--uniq]
```

### Arguments

| Argument | Description |
|----------|-------------|
| `type` | DNS 레코드 타입 (A, AAAA, CNAME, MX, NS, TXT, SOA 등) |
| `domain` | 조회할 도메인명 |
| `country` | (선택) 국가 코드로 서버 필터링 |

### Examples

```bash
# A 레코드 글로벌 조회
./gdig.sh a www.example.com

# 한국 서버에서만 조회
./gdig.sh a www.example.com kr

# 미국 서버에서 MX 레코드 조회
./gdig.sh mx example.com us

# CNAME 레코드 조회
./gdig.sh cname www.example.com

# 조회 결과에서 중복 제거한 응답 목록을 함께 출력
./gdig.sh a www.example.com kr --uniq
```

### Options

```bash
./gdig.sh a example.com --uniq  # 유니크 응답 목록 추가 출력 (위치 무관)
./gdig.sh --list-countries      # 사용 가능한 국가 코드 표시
./gdig.sh --refresh-servers     # 서버 목록 심층 수집 (30 샘플 병합)
./gdig.sh --clear-cache         # 누적된 서버 캐시 삭제
./gdig.sh --help                # 도움말 표시
```

`--uniq`는 표 출력에 더해, 모든 DNS 서버가 반환한 응답을 중복 제거·정렬한 목록을 Summary 뒤에 출력합니다. CNAME/NS는 끝점(`.`) 유무를 같은 값으로 취급합니다.

```
Summary: 11 queried | 11 success | 4 unique IPs

Unique IPs (4):
211.56.106.69
211.56.106.79
211.56.106.109
211.56.106.110
```

### Response Column

성공 시 IP 목록이, 실패 시 원인이 표시됩니다.

- `NXDOMAIN`, `SERVFAIL` 등 — 해당 DNS 서버가 돌려준 rcode
- `DNS query timed out` — whatsmydns가 그 DNS 서버에 질의했다가 응답을 못 받은 경우. 일시적 현상이라 자동으로 1회 재시도합니다 (실측: 서버당 약 18% 발생, 그중 92%가 재시도로 회수)
- `Request failed`(빨간색) — gdig에서 whatsmydns API 호출 자체가 실패

### Server Cache

whatsmydns.net API(`/api/servers`)는 전체 서버 풀에서 무작위로 **22개만 샘플링**해 반환합니다. 따라서 응답 하나만 그대로 쓰면 가용 서버의 1/3만 조회하게 됩니다.

`~/.cache/gdig/servers_cache.json`은 이 샘플들을 서버 `id` 기준으로 **누적 병합**합니다.

- 캐시 만료(24시간) 시 10개 샘플을 병렬 수집해 기존 목록에 병합
- 각 서버에 `last_seen`을 기록하고, 30일간 어떤 샘플에도 나오지 않은 서버는 제거
- `--refresh-servers`는 30개 샘플을 수집해 풀을 즉시 포화시킴 (실측 약 65~69개)
- API 응답에 `cache-control: max-age=3600`이 걸려 있고 Cloudflare 앞단 캐시가 있어, 매 요청에 캐시버스터 파라미터를 붙여 새 샘플을 받습니다

한국 기준으로 단일 샘플은 KT 1개만 잡히지만, 누적하면 LG Dacom이 추가됩니다. 미국은 5개 → 21개로 늘어납니다.

API가 리졸버 IP를 노출하지 않아 서로 다른 서버가 같은 국가·위치·제공자로 표시되는 경우가 있습니다(Google Mountain View 4개, Cloudflare Ashburn 2개 등). 이런 항목은 `Google #1` ~ `Google #4` 처럼 번호를 붙여 구분합니다.

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `GDIG_WIDTH` | 터미널 너비 강제 지정 | 자동 감지 |

```bash
# 200자 너비로 강제 설정
GDIG_WIDTH=200 ./gdig.sh a example.com
```

## Supported Countries

AU, BR, CA, CN, DE, ES, FR, GB, IN, KR, MX, MY, NL, PK, RU, SG, TH, TR, US, ZA

## Sample Output

```
Global DNS Checker: www.example.com (A)
Region Filter: US

+----------------------------------+------------------+--------------------------------------------------+
| DNS Server                       | Provider         | Response                                         |
+----------------------------------+------------------+--------------------------------------------------+
| [US] Ashburn VA                  | NeuStar          | 93.184.216.34                                    |
+----------------------------------+------------------+--------------------------------------------------+
| [US] Boston MA                   | Speakeasy        | 93.184.216.34                                    |
+----------------------------------+------------------+--------------------------------------------------+
| Local Lookup (Client: x.x.x.x (South Korea))                                                     |
+----------------------------------+------------------+--------------------------------------------------+
| 1.1.1.1                          | Cloudflare-1     | 93.184.216.34                                    |
+----------------------------------+------------------+--------------------------------------------------+

Summary: 5 queried | 5 success | 1 unique IPs
Done.
```

## Changelog

### v1.2.0 (2026-02-06)
- Cloudflare 우회 수정: whatsmydns.net API 호출에 브라우저 헤더 추가
- `/api/servers` 및 `/api/details` 엔드포인트에 User-Agent, Accept, Referer 헤더 적용
- Cloudflare 보호로 인한 HTML challenge 페이지 대신 정상 JSON 응답 보장

### v1.1.0 (2026-01-07)
- GNU Parallel 의존성 제거, xargs -P 사용으로 간소화
- 코드 구조 리팩토링 및 최적화
- 결과 상태별 색상 출력 개선 (성공/실패/빈 응답)
- 로컬 DNS 서버 목록 업데이트 (OpenDNS 제거, ISP별 보조 DNS 추가)

### v1.0.0 (2026-01-05)
- 초기 릴리스
- 전 세계 DNS 서버 조회 기능
- 테이블 형식 출력
- 국가별 필터링 지원
