# Scripts Collection

유용한 셸 스크립트 모음입니다.

## Scripts

| Script | Category | Description | Version |
|--------|----------|-------------|---------|
| [gdig](./gdig/) | `DNS` | 전 세계 DNS 서버에서 도메인 레코드 조회 | v1.0.0 |
| [urlsigning](./urlsigning/) | `CDN` | CDN URL 서명 생성 (A~E, UTV 모드) | v1.0.0 |
| [pcontents](./pcontents/) | `CDN` | 병렬 CDN 노드 콘텐츠 일관성 검증 | v1.0.0 |
| [cache-consistency](./cache-consistency/) | `CDN` | S3 오리진과 CDN 엣지 캐시 간 객체 정합성 검증 | - |
| [vault-management](./vault-management/) | `Obsidian` | 볼트 주간 리포트 생성 (클리핑 알림, 링크 상태 등) | - |

## Quick Start

```bash
# 저장소 클론
git clone https://github.com/grergea/scripts.git
cd scripts

# 스크립트 실행
./gdig/gdig.sh a example.com
python ./urlsigning/urlsigning.py -m A -r cdn.example.com -p /video.mp4 -k mykey
./pcontents/pcontents.sh -o https://www.example.com/image.jpg
```

## gdig - Global DNS Checker

전 세계 DNS 서버에서 도메인 레코드를 조회합니다.

```bash
./gdig/gdig.sh <type> <domain> [country]

# 예시
./gdig/gdig.sh a www.example.com       # 글로벌 A 레코드 조회
./gdig/gdig.sh a www.example.com kr    # 한국 서버에서만 조회
./gdig/gdig.sh --list-countries        # 지원 국가 목록
```

**의존성:** `curl`, `jq`, `dig`, `parallel`

→ [상세 문서](./gdig/README.md)

## urlsigning - CDN URL Signing Tool

CDN URL 서명을 생성합니다. 다양한 벤더의 URL 인증 방식을 지원합니다.

```bash
python ./urlsigning/urlsigning.py -m <mode> -r <host> -p <path> -k <key>

# 예시
python ./urlsigning/urlsigning.py -m A -r cdn.example.com -p /video.mp4 -k mykey
python ./urlsigning/urlsigning.py -m E -r cdn.example.com -p /video.mp4 -k mykey --uid "SMARTTV-123"
python ./urlsigning/urlsigning.py -m UTV -r cdn.example.com -p /video.mp4 -k mykey --hex-time
```

**의존성:** Python 3.6+

→ [상세 문서](./urlsigning/README.md)

## pcontents - Parallel Contents Checker

여러 CDN 노드에 병렬로 요청을 보내 콘텐츠 일관성을 검증합니다.

```bash
./pcontents/pcontents.sh [-o] [-l nodes] [-H header] [-P jobs] <URL>

# 예시
./pcontents/pcontents.sh -o https://www.example.com/image.jpg
./pcontents/pcontents.sh -l "1.1.1.1, 8.8.8.8" https://www.example.com/
./pcontents/pcontents.sh -H "Host: assets.example.com" -P 5 -l "1.1.1.1" https://www.example.com/
```

**의존성:** `curl`, `parallel`, `md5sum`, `column`

→ [상세 문서](./pcontents/README.md)

## License

MIT License

## Author

- **Lee Sanghun** ([@grergea](https://github.com/grergea))
