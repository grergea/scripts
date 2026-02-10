# Cache Consistency Checker

S3 오브젝트 스토리지의 원본 객체와 CDN 엣지에 캐시된 객체 간의 정합성을 검증하는 도구입니다.

## Quick Start

### 1. 가상 환경 설정 (최초 1회)

```bash
# 가상 환경 생성 (별도 디렉터리)
python3 -m venv /Users/shlee/leesh/python_venv/cache-consistency

# 가상 환경 활성화 및 의존성 설치
source /Users/shlee/leesh/python_venv/cache-consistency/bin/activate
pip install -r requirements.txt
```

**참고:** 가상 환경은 GitHub 저장소 외부(`~/leesh/python_venv/`)에 별도로 관리됩니다.

### 2. 실행

```bash
# 가상 환경 활성화
source /Users/shlee/leesh/python_venv/cache-consistency/bin/activate

# 스크립트 실행
python cache_consistency.py \
  --bucket oem-nsumjp-act \
  --endpoint https://s3-jp-east-1.wcsapi.com \
  --region jp-east-1 \
  --prefix "update_data/sums_data/ccNC/ME!AE/19022/" \
  --origin "http://oem-nsumjp-act.wcscdn55.v1.wcsapi.com" \
  --origin-host "oem-nsumjp.map-care.com" \
  --cdn "https://oem-nsumjp.map-care.com"
```

**Tip:** 자주 사용한다면 shell alias를 추가하세요:

```bash
# ~/.zshrc 또는 ~/.bashrc에 추가
alias cache-check='source /Users/shlee/leesh/python_venv/cache-consistency/bin/activate && python /Users/shlee/leesh/scripts-repo/cache-consistency/cache_consistency.py'

# 사용 예시
cache-check --bucket mybucket --endpoint https://s3.example.com ...
```

## S3 인증 설정

```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
```

## 주요 옵션

- `--md5`: 콘텐츠 MD5 해시 비교 (정밀 검증)
- `--output result.csv`: CSV 결과 저장
- `--workers 10`: 병렬 처리 워커 수 증가

## 상세 문서

전체 문서는 Obsidian 노트 참조:
`/Users/shlee/leesh/mynotes/03_Resources/Scripts/cache_consistency.py.md`
