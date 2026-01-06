# gdig - Global DNS Checker

전 세계 DNS 서버에서 도메인 레코드를 조회하는 bash 스크립트입니다. [whatsmydns.net](https://www.whatsmydns.net) API를 활용합니다.

## Features

- **Parallel Processing**: GNU Parallel을 사용한 동시 DNS 쿼리
- **Global Coverage**: 20개국 이상의 DNS 서버 조회
- **Local DNS Check**: Cloudflare, Google, OpenDNS, 국내 ISP DNS 서버 포함
- **Caching**: 24시간 DNS 서버 목록 캐시
- **Dynamic Table Output**: 터미널 너비에 맞게 자동 조정
- **Country Filter**: 국가 코드로 결과 필터링

## Requirements

```bash
# macOS
brew install curl jq bind parallel

# Ubuntu/Debian
sudo apt install curl jq dnsutils parallel
```

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
Global DNS Checker - www.example.com (A)

  Query:   A record for www.example.com
  Filter:  Country = US
  Source:  whatsmydns.net API

+----------------------------------+------------------+--------------------------------------------------+
| DNS Server                       | Provider         | Response                                         |
+----------------------------------+------------------+--------------------------------------------------+
| [US] Ashburn VA, United States   | NeuStar          | 93.184.216.34                                    |
| [US] Boston MA, United States    | Speakeasy        | 93.184.216.34                                    |
+----------------------------------+------------------+--------------------------------------------------+

Summary: 5 servers queried | 5 successful | 1 unique responses

DNS check completed successfully
```

## Changelog

### v1.0.0 (2026-01-05)
- 초기 릴리스
- 전 세계 DNS 서버 조회 기능
- 테이블 형식 출력
- 국가별 필터링 지원
