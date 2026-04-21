# CLAUDE.md

이 파일은 Claude Code가 이 저장소에서 작업할 때 참고하는 가이드입니다.

## 저장소 정보

- **이름**: scripts
- **GitHub**: https://github.com/grergea/scripts
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
└── vault-management/      # Obsidian 볼트 주간 리포트
    └── weekly-vault-review.py
```

> **로컬 전용 (미추적)**: `bluer-collector/` — 민감 데이터 포함, `.gitignore` 처리

## 스크립트 목록

| 스크립트 | 카테고리 | 설명 | 의존성 |
|----------|----------|------|--------|
| `gdig/gdig.sh` | DNS | 전 세계 DNS 서버에서 도메인 레코드 조회 | curl, jq, dig, parallel |
| `urlsigning/urlsigning.py` | CDN | CDN URL 서명 생성 | Python 3.6+ |
| `pcontents/pcontents.sh` | CDN | 병렬 CDN 노드 콘텐츠 일관성 검증 | curl, parallel |
| `cache-consistency/cache_consistency.py` | CDN | S3 오리진↔CDN 엣지 캐시 정합성 검증 | Python, boto3 |
| `vault-management/weekly-vault-review.py` | Obsidian | 볼트 주간 리포트 생성 | Python 3.10+ |

## 연관 Obsidian 노트

- 스크립트 문서: `/Users/shlee/leesh/mynotes/03_Resources/Scripts/`
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
```
Add/Update/Fix 스크립트명 - 간단한 설명

- 상세 변경 내용
- ...

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
```
