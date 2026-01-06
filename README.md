# Scripts Collection

유용한 셸 스크립트 모음입니다.

## Scripts

| Script | Category | Description | Version |
|--------|----------|-------------|---------|
| [gdig](./gdig/) | `DNS` | 전 세계 DNS 서버에서 도메인 레코드 조회 | v1.0.0 |
| [clean-note](./clean-note/) | `Obsidian` | AI 복사 텍스트 정리 (불필요한 숫자, 태그 제거) | v1.1.0 |

## Quick Start

```bash
# 저장소 클론
git clone https://github.com/grergea/scripts.git
cd scripts

# 스크립트 실행
./gdig/gdig.sh a example.com
./clean-note/clean-note.sh "노트.md" --dry-run
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

## clean-note - Obsidian 노트 정리

Gemini/ChatGPT에서 복사한 텍스트의 불필요한 요소를 제거합니다.

```bash
./clean-note/clean-note.sh <파일> [옵션]

# 예시
./clean-note/clean-note.sh "노트.md"              # 정리 실행
./clean-note/clean-note.sh "노트.md" --dry-run    # 미리보기
./clean-note/clean-note.sh "노트.md" --backup     # 백업 후 정리
```

**의존성:** `sed`, `awk` (기본 포함)

→ [상세 문서](./clean-note/README.md)

## License

MIT License

## Author

- **Lee Sanghun** ([@grergea](https://github.com/grergea))
