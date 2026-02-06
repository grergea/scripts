# gdig - Global DNS Checker

전 세계 DNS 서버에서 도메인 레코드를 조회하는 bash 스크립트입니다. [whatsmydns.net](https://www.whatsmydns.net) API를 활용합니다.

## Features

- **Parallel Processing**: xargs를 사용한 동시 DNS 쿼리 (외부 의존성 최소화)
- **Global Coverage**: 20개국 이상의 DNS 서버 조회
- **Local DNS Check**: Cloudflare, Google, 국내 ISP(SKT/KT/LG) DNS 서버 포함
- **Caching**: 24시간 DNS 서버 목록 캐시
- **Dynamic Table Output**: 터미널 너비에 맞게 자동 조정되는 컬럼
- **Country Filter**: 국가 코드로 결과 필터링
- **Color Output**: 결과 상태별 색상 구분 (성공/실패/빈 응답)

## Requirements

```bash
# macOS
brew install curl jq bind

# Ubuntu/Debian
sudo apt install curl jq dnsutils
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
./gdig.sh <type> <domain> [country]
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
```

### Options

```bash
./gdig.sh --list-countries    # 사용 가능한 국가 코드 표시
./gdig.sh --clear-cache       # 서버 캐시 삭제
./gdig.sh --help              # 도움말 표시
```

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
