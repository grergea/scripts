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
├── CLAUDE.md        # Claude Code 가이드
├── README.md        # 저장소 설명
├── LICENSE          # MIT 라이선스
└── gdig.sh          # Global DNS Checker 스크립트
```

## 스크립트 목록

| 스크립트 | 설명 | 의존성 |
|----------|------|--------|
| `gdig.sh` | 전 세계 DNS 서버에서 도메인 레코드 조회 | curl, jq, dig, parallel |

## 연관 Obsidian 노트

- 스크립트 문서: `/Users/shlee/leesh/mynotes/03_Resources/Scripts/`
- 스크립트 인덱스: `🏷 Scripts.md`

## 작업 규칙

### 새 스크립트 추가 시
1. 스크립트 파일 작성 (`.sh`)
2. README.md에 스크립트 설명 추가
3. Obsidian 노트에 문서화된 버전 생성 (`스크립트명.md`)
4. 커밋 & 푸시

### 커밋 메시지 형식
```
Add/Update/Fix 스크립트명 - 간단한 설명

- 상세 변경 내용
- ...

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
```
