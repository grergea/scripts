# URLSigning - CDN URL Signing Tool

CDN URL 서명을 생성하는 Python 스크립트입니다. 다양한 CDN 벤더의 URL 인증 방식(A~E, UTV 모드)을 지원합니다.

## Features

- **Multi-Mode Support**: A, B, C, D, E, UTV 서명 모드 지원
- **Hash Algorithms**: MD5, SHA256 선택 가능
- **Flexible UID**: MAC, Random, Hostname, Custom UID 지원 (스마트TV, 셋톱박스 호환)
- **Secure Debug**: verbose 모드에서 키 자동 마스킹
- **Zero Dependencies**: Python 표준 라이브러리만 사용

## Requirements

- Python 3.6+

## Installation

```bash
# urlsigning.py만 다운로드
curl -O https://raw.githubusercontent.com/grergea/scripts/master/urlsigning/urlsigning.py

# 실행 권한 부여
chmod +x urlsigning.py

# (선택) PATH에 추가
sudo ln -s $(pwd)/urlsigning.py /usr/local/bin/urlsigning
```

## Usage

```bash
python urlsigning.py -m <mode> -r <host> -p <path> -k <key> [options]
```

### Arguments

| Argument | Description |
|----------|-------------|
| `-m, --mode` | 서명 모드 (A, B, C, D, E, UTV) |
| `-r, --host` | CDN 호스트명 |
| `-p, --path` | 리소스 경로 |
| `-k, --key` | 서명 비밀키 |

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `-s, --scheme` | `http` | URL 스킴 (http/https) |
| `-t, --start_time` | 현재시간 | Unix 타임스탬프 |
| `--hex-time` | - | 시간을 16진수로 변환 |
| `--hash` | `md5` | 해시 알고리즘 (md5/sha256) |
| `--uid` | - | 커스텀 UID (Mode E) |
| `--uid-type` | `mac` | UID 생성 방식 (mac/random/zero/hostname) |
| `--sign-order` | `pkt` | Mode A/B/C/D/UTV의 signing string 순서 (k/p/t 조합, 예: kpt) |
| `-v, --verbose` | - | 디버그 출력 활성화 |

### Time/Param Options (Mode C/D/UTV)

| Option | Default | Description |
|--------|---------|-------------|
| `--time-offset` | `3600` | 만료 시간 오프셋 (초). Mode C/D/UTV에 적용, `0`으로 끌 수 있음 |
| `--time-param` | `px-time` | 시간 파라미터명 (UTV 모드 전용) |
| `--hash-param` | `px-hash` | 해시 파라미터명 (UTV 모드 전용) |

## Examples

```bash
# Mode A - URL 경로에 시간/해시 삽입
python urlsigning.py -m A -r cdn.example.com -p /video.mp4 -k mysecretkey
# Output: http://cdn.example.com/1736300000/abc123.../video.mp4

# Mode C - 쿼리 파라미터 방식
python urlsigning.py -m C -r cdn.example.com -p /video.mp4 -k mysecretkey
# Output: http://cdn.example.com/video.mp4?key=abc123...&time=1736300000

# Mode E - auth_key 방식 (스마트TV용 커스텀 UID)
python urlsigning.py -m E -r cdn.example.com -p /video.mp4 -k mysecretkey --uid "SMARTTV-12345"
# Output: http://cdn.example.com/video.mp4?auth_key=1736300000-123456789-SMARTTV-12345-abc123...

# UTV 모드 - 커스텀 파라미터명
python urlsigning.py -m UTV -r cdn.example.com -p /video.mp4 -k mysecretkey --hex-time
# Output: http://cdn.example.com/video.mp4?px-time=67890abc&px-hash=def456...

# SHA256 해시 사용
python urlsigning.py -m A -r cdn.example.com -p /video.mp4 -k mysecretkey --hash sha256

# 디버그 모드 (키 마스킹됨)
python urlsigning.py -m A -r cdn.example.com -p /video.mp4 -k mysecretkey -v
# [DEBUG] Mode: A, Scheme: http, Host: cdn.example.com, Path: /video.mp4, Key: my**********ey, Time: 1736300000, Hash: md5
```

## Signing Modes

| Mode | URL Format | Signing String |
|------|------------|----------------|
| A | `/{time}/{hash}{path}` | `--sign-order` 지정 (기본 `pkt` = `{path}{key}{time}`), offset 미반영 |
| B | `/{hash}/{time}{path}` | `--sign-order` 지정 (기본 `pkt` = `{path}{key}{time}`), offset 미반영 |
| C | `{path}?key={hash}&time={time}` | `--sign-order` 지정 (기본 `pkt`, 시각은 `--time-offset` 반영된 adjusted time) |
| D | `{path}?time={time}&key={hash}` | `--sign-order` 지정 (기본 `pkt`, 시각은 `--time-offset` 반영된 adjusted time) |
| E | `{path}?auth_key={time}-{rand}-{uid}-{hash}` | `{path}-{time}-{rand}-{uid}-{key}` (고정) |
| UTV | `{path}?{time_param}={time}&{hash_param}={hash}` | `--sign-order` 지정 (기본 `pkt`, 시각은 `--time-offset` 반영된 adjusted time) |

## UID Types (Mode E)

Mode E에서 사용할 수 있는 UID 생성 방식입니다.

| Type | Description | Use Case |
|------|-------------|----------|
| `mac` | MAC 주소 기반 (기본값) | PC, 서버 |
| `random` | 랜덤 UUID (요청마다 다름) | 일회성 요청 |
| `zero` | 고정값 "0" | 테스트, 호환성 |
| `hostname` | 호스트명 해시 | 컨테이너, VM |
| `--uid` | 커스텀 값 직접 지정 | 스마트TV, 셋톱박스, IoT |

```bash
# MAC 주소 사용 불가 환경 - 랜덤 UID
python urlsigning.py -m E -r cdn.example.com -p /video.mp4 -k mykey --uid-type random

# 스마트TV - 디바이스 시리얼 사용
python urlsigning.py -m E -r cdn.example.com -p /video.mp4 -k mykey --uid "TV-SERIAL-ABC123"
```

## CDN Vendor Compatibility

| CDN Vendor | Recommended Mode |
|------------|------------------|
| Alibaba Cloud CDN | A, B, C |
| Tencent Cloud CDN | A, B, C, D |
| Custom CDN | E, UTV |

## Changelog

### v1.1.0 (2026-08-25)

- UTV 모드에 `--sign-order` 적용 (기존엔 `{key}{path}{time}` 고정이었음)
- `--sign-order` 옵션을 A/B/C/D/UTV 전체 모드에 대해 문서화

### v1.0.0 (2026-01-08)

- 초기 릴리스
- A, B, C, D, E, UTV 서명 모드 지원
- MD5, SHA256 해시 알고리즘 지원
- 다양한 UID 소스 지원 (mac, random, zero, hostname, custom)
- verbose 모드에서 키 마스킹 보안 기능
