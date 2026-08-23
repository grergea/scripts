# CLAUDE.md

이 파일은 Claude Code가 이 저장소에서 작업할 때 참고하는 가이드입니다.

## 저장소 정보

- **이름**: scripts
- **GitHub**: https://github.com/grergea/scripts (**공개 저장소** — 민감정보 절대 금지)
- **브랜치**: master (`git push origin master`)
- **용도**: 유용한 셸 스크립트 모음
- **소유자**: 이상훈

## 저장소 구조

```
scripts-repo/
├── README.md              # 메인 (스크립트 요약)
├── CLAUDE.md              # Claude Code 가이드
├── LICENSE                # MIT 라이선스
│
├── gdig/                  # DNS 체커
│   ├── README.md
│   └── gdig.sh
│
├── urlsigning/            # CDN URL 서명
│   ├── README.md
│   └── urlsigning.py
│
├── pcontents/             # CDN 노드 콘텐츠 일관성 검증
│   └── pcontents.sh
│
├── cache-consistency/     # S3↔CDN 캐시 정합성 검증
│   ├── README.md
│   ├── cache_consistency.py
│   └── requirements.txt
│
├── sslyze-map/            # sslyze cipher 표기 변환 래퍼
│   ├── README.md
│   └── sslyze-map.sh
│
└── vault-management/      # Obsidian 볼트 관리 유틸리티
```

> **로컬 전용 (미추적)**: `bluer-collector/` — 민감 데이터 포함, `.gitignore` 처리
> **Obsidian 볼트 관리 스크립트**: `scripts-skills` 레포 관리 (https://github.com/grergea/scripts-skills)

## 스크립트 목록

| 스크립트 | 카테고리 | 설명 | 의존성 |
|----------|----------|------|--------|
| `gdig/gdig.sh` | DNS | 전 세계 DNS 서버에서 도메인 레코드 조회 | curl, jq, dig, parallel |
| `urlsigning/urlsigning.py` | CDN | CDN URL 서명 생성 | Python 3.6+ |
| `pcontents/pcontents.sh` | CDN | 병렬 CDN 노드 콘텐츠 일관성 검증 | curl, parallel |
| `cache-consistency/cache_consistency.py` | CDN | S3 오리진↔CDN 엣지 캐시 정합성 검증 | Python, boto3 |
| `sslyze-map/sslyze-map.sh` | CDN | sslyze 결과를 IANA / OpenSSL 표기로 골라서 출력 | sslyze, jq |
| `cert-check/cert-check.sh` | CDN | 지정 IP로 고정 접속해 서버 인증서와 로컬 cert.pem fingerprint 비교 | openssl, bash 4+ |
| `globalping/globalping_ping.py` | Network | Globalping API로 특정 국가 프로브에서 ping 측정 | Python, requests |

## 실행 예시 (Quick Reference)

```bash
# gdig: DNS 조회
bash gdig/gdig.sh example.com A

# urlsigning: CDN URL 서명 생성
python urlsigning/urlsigning.py --key KEY --url URL

# pcontents: CDN 노드 콘텐츠 정합성 검증
bash pcontents/pcontents.sh

# cache-consistency: S3↔CDN 캐시 정합성 검증 (AWS credentials 필요)
pip install -r cache-consistency/requirements.txt
python cache-consistency/cache_consistency.py

# sslyze-map: TLS 버전별 cipher를 OpenSSL 표기로 출력
bash sslyze-map/sslyze-map.sh --mapping openssl --tlsv1_2 --tlsv1_3 example.com
```

## 연관 Obsidian 노트

- 스크립트 문서: `/Users/shlee/mynotes/03_Resources/Scripts/`
- 스크립트 인덱스: `🏷 Scripts.md`

## 작업 규칙

### 새 스크립트 추가 시
1. 스크립트 폴더 생성 (`스크립트명/`)
2. 스크립트 파일 작성 (`스크립트명.sh`)
3. 폴더 내 README.md 작성 (상세 문서)
4. 메인 README.md 테이블에 추가
5. Obsidian 노트 문서화 (`스크립트명.md`)
6. 커밋 & 푸시

### 커밋 메시지 형식

Conventional Commits (`<type>(<scope>): <subject>`). Types: feat, fix, refactor, perf, docs, test, chore, build, ci, style, revert. 명령형, subject ≤50자 권장(최대 72자), 마침표 없음. body는 "왜"가 자명하지 않을 때만 추가. 커밋 메시지는 `caveman-commit` 스킬로 생성한다.

Footer 필수:
```
🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```
