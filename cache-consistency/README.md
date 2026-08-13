# Cache Consistency Checker

S3 오브젝트 스토리지의 원본 객체와 CDN 엣지에 캐시된 객체 간의 정합성을 검증하는 도구입니다.

## Quick Start

### 1. 가상 환경 설정 (최초 1회)

```bash
# 가상 환경 생성 (별도 디렉터리)
python3 -m venv ~/python_venv/cache-consistency

# 가상 환경 활성화 및 의존성 설치
source ~/python_venv/cache-consistency/bin/activate
pip install -r requirements.txt
```

**참고:** 가상 환경은 GitHub 저장소 외부(`~/python_venv/`)에 별도로 관리됩니다.

### 2. 실행

#### 기본 실행 (헤더 비교)

```bash
# 가상 환경 활성화
source ~/python_venv/cache-consistency/bin/activate

# 스크립트 실행
python cache_consistency.py \
  --bucket my-bucket \
  --endpoint https://s3-region.wcsapi.com \
  --region us-east-1 \
  --prefix "data/path/to/objects/" \
  --origin "http://my-bucket.wcscdn.example.com" \
  --origin-host "origin.example.com" \
  --cdn "https://cdn.example.com"
```

#### 진행 상황 출력 (권장)

```bash
python cache_consistency.py \
  --bucket my-bucket \
  --endpoint https://s3-region.wcsapi.com \
  --region us-east-1 \
  --prefix "data/path/to/objects/" \
  --origin "http://my-bucket.wcscdn.example.com" \
  --origin-host "origin.example.com" \
  --cdn "https://cdn.example.com" \
  --verbose
```

**출력 예시:**
```
[INFO] 1000개 객체 발견
[INFO] 정합성 검사 진행중... (5 workers)

[   1/1000] (  0.1%) ✓ [O:✓ C:✓] file1.txt
[   2/1000] (  0.2%) ✓ [O:✓ C:✓] file2.txt
[   3/1000] (  0.3%) ✗ [O:✓ C:✗] file3.txt
```

- `O:✓` = 오리진 응답 성공
- `C:✓` = CDN 응답 성공
- `✓/✗/!` = 일치/불일치/오류

**Tip:** 자주 사용한다면 shell alias를 추가하세요:

```bash
# ~/.zshrc 또는 ~/.bashrc에 추가
alias cache-check='source ~/python_venv/cache-consistency/bin/activate && python ~/scripts/cache-consistency/cache_consistency.py'

# 사용 예시
cache-check --bucket my-bucket --endpoint https://s3-region.wcsapi.com ...
```

### 수동 URL 모드 (S3 미사용, NAS/HTTP 오리진)

오리진이 S3 호환이 아니어서 버킷 목록 조회가 불가능한 경우(NAS 등), `--urls` 또는 `--url-file`로 검사할 객체 경로를 직접 지정합니다. 이 모드는 `--bucket`/`--endpoint`/`--region`/`--prefix`와 boto3가 필요 없습니다.

```bash
python cache_consistency.py \
  --origin "http://origin.example.com" \
  --cdn "https://cdn.example.com" \
  --urls "path/to/file1.mp4" "path/to/file2.mp4" \
  --verbose

# 또는 파일 목록으로
python cache_consistency.py \
  --origin "http://origin.example.com" \
  --cdn "https://cdn.example.com" \
  --url-file paths.txt \
  --verbose
```

## S3 인증 설정

```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
```

## 주요 옵션

| 옵션 | 설명 | 비고 |
|------|------|------|
| `--verbose`, `-v` | 진행 상황 실시간 출력 | 권장 |
| `--md5` | 콘텐츠 MD5 해시 비교 | 정밀 검증 (GET 요청만 사용) |
| `--output result.csv` | CSV 결과 저장 | 엑셀로 분석 가능 |
| `--workers 10` | 병렬 처리 워커 수 | 기본값: 5 |
| `--timeout 30` | HTTP 요청 타임아웃 (초) | 기본값: 10 |

### 성능 정보

| 모드 | 요청 방식 | 요청 횟수 (1,000개 파일 기준) |
|------|----------|------------------------------|
| 기본 모드 | HEAD × 2 | 2,000회 |
| MD5 모드 | GET × 2 | 2,000회 (최적화됨) |

**MD5 모드 최적화:** GET 요청으로 헤더와 콘텐츠를 동시 수집하여 이중 요청 없음

## 상세 문서

전체 사용법, 옵션 설명, 트러블슈팅 가이드는 프로젝트 문서를 참조하세요.
